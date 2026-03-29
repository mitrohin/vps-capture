import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/app_config.dart';
import '../storage/app_paths.dart';
import 'capture_backend.dart';

class FfmpegStartupException implements Exception {
  const FfmpegStartupException({
    required this.message,
    required this.command,
    required this.arguments,
    required this.output,
    this.exitCode,
  });

  final String message;
  final String command;
  final List<String> arguments;
  final String output;
  final int? exitCode;

  @override
  String toString() => message;
}

class BufferRecorder {
  BufferRecorder(this._paths, this._backend);

  final AppPaths _paths;
  final CaptureBackend _backend;
  Process? _process;
  int? _externalPid;
  Timer? _cleanupTimer;
  bool _isStopping = false;
  static const Duration _startupTimeout = Duration(seconds: 3);

  bool get isRunning => _process != null || _externalPid != null;

  Future<Directory> start(
    AppConfig config,
    void Function(String line) onLog,
    void Function() onUnexpectedExit, {
    bool allowRecovery = false,
  }) async {
    await stop();
    final segmentsDir = await _paths.segmentsDir();

    final orphanRecovered = await _handleOrphanedProcess(
      ffmpegPath: config.ffmpegPath!,
      segmentsDir: segmentsDir,
      allowRecovery: allowRecovery,
      onLog: onLog,
    );

    if (orphanRecovered) {
      _isStopping = false;
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
      });
      return segmentsDir;
    }

    await _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
    final inputArgsWithProbeFlags = _prependProbeFlagsToInput(_backend.buildInputArgs(config));

    final args = <String>[
      ...inputArgsWithProbeFlags,
      ..._backend.buildOutputVideoArgs(config),
      '-f',
      'segment',
      '-segment_time',
      '${config.segmentSeconds}',
      '-reset_timestamps',
      '1',
      '-strftime',
      '1',
      '-segment_format',
      'mpegts',
      p.join(segmentsDir.path, 'seg_%Y%m%d_%H%M%S.ts'),
    ];

    _isStopping = false;
    final startupLogLines = <String>[];
    void relayLog(String line) {
      final normalized = line.trimRight();
      if (normalized.isNotEmpty) {
        startupLogLines.add(normalized);
      }
      onLog(line);
    }

    try {
      _process = await Process.start(config.ffmpegPath!, args);
    } on ProcessException catch (error) {
      throw FfmpegStartupException(
        message: 'Unable to start ffmpeg process.',
        command: config.ffmpegPath!,
        arguments: args,
        output: error.toString(),
      );
    }

    final process = _process!;
    await _writeProcessState(
      pid: process.pid,
      ffmpegPath: config.ffmpegPath!,
      segmentsDir: segmentsDir.path,
      startedAt: DateTime.now().toUtc(),
    );

    var startupCompleted = false;
    int? processExitCode;

    process.stderr.transform(SystemEncoding().decoder).listen(relayLog);
    process.stdout.transform(SystemEncoding().decoder).listen(relayLog);
    process.exitCode.then((code) {
      processExitCode = code;
      final isCurrentProcess = identical(_process, process);
      final isUnexpectedExit = isCurrentProcess && !_isStopping && startupCompleted;
      if (isCurrentProcess) {
        _process = null;
      }
      _cleanupTimer?.cancel();
      _isStopping = false;
      unawaited(_clearProcessState());
      if (isUnexpectedExit) onUnexpectedExit();
    });

    try {
      await _waitForStartup(
        segmentsDir: segmentsDir,
        command: config.ffmpegPath!,
        arguments: args,
        startupLogLines: startupLogLines,
        processExitCode: () => processExitCode,
      );
      startupCompleted = true;
    } catch (_) {
      if (identical(_process, process)) {
        _process = null;
      }
      await _clearProcessState();
      rethrow;
    }

    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
    });

    return segmentsDir;
  }

  Future<void> _waitForStartup({
    required Directory segmentsDir,
    required String command,
    required List<String> arguments,
    required List<String> startupLogLines,
    required int? Function() processExitCode,
  }) async {
    final deadline = DateTime.now().add(_startupTimeout);

    while (DateTime.now().isBefore(deadline)) {
      if (await _hasSegmentFiles(segmentsDir)) {
        return;
      }

      final exitCode = processExitCode();
      if (exitCode != null) {
        throw FfmpegStartupException(
          message: 'ffmpeg exited before recording could start.',
          command: command,
          arguments: arguments,
          output: startupLogLines.takeLast(120).join('\n'),
          exitCode: exitCode,
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    final exitCode = processExitCode();
    if (exitCode != null) {
      throw FfmpegStartupException(
        message: 'ffmpeg exited before recording could start.',
        command: command,
        arguments: arguments,
        output: startupLogLines.takeLast(120).join('\n'),
        exitCode: exitCode,
      );
    }
  }

  List<String> _prependProbeFlagsToInput(List<String> inputArgs) {
    const probeFlags = <String>['-analyzeduration', '0', '-probesize', '32M'];
    final inputIndex = inputArgs.indexOf('-i');
    if (inputIndex <= 0) {
      return [...probeFlags, ...inputArgs];
    }

    return [
      ...inputArgs.take(inputIndex),
      ...probeFlags,
      ...inputArgs.skip(inputIndex),
    ];
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _isStopping = true;

    final process = _process;
    if (process != null) {
      process.kill(ProcessSignal.sigint);
      await process.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
        process.kill();
        return process.exitCode;
      });
      if (identical(_process, process)) {
        _process = null;
      }
      _isStopping = false;
      await _clearProcessState();
      return;
    }

    final externalPid = _externalPid;
    if (externalPid != null) {
      await _terminatePid(externalPid);
      _externalPid = null;
    }

    _isStopping = false;
    await _clearProcessState();
  }

  Future<bool> _handleOrphanedProcess({
    required String ffmpegPath,
    required Directory segmentsDir,
    required bool allowRecovery,
    required void Function(String line) onLog,
  }) async {
    final state = await _readProcessState();
    if (state == null) {
      return false;
    }

    final rawPid = state['pid'];
    final pid = rawPid is int ? rawPid : (rawPid is num ? rawPid.toInt() : null);
    if (pid == null) {
      await _clearProcessState();
      return false;
    }

    final isAlive = await _isTargetFfmpegProcessAlive(
      pid: pid,
      ffmpegPath: ffmpegPath,
      segmentsDir: segmentsDir.path,
    );

    if (!isAlive) {
      await _clearProcessState();
      return false;
    }

    if (allowRecovery) {
      _externalPid = pid;
      onLog('Recovered running ffmpeg process (pid=$pid) after an unexpected app shutdown.');
      return true;
    }

    onLog('Stopping stale ffmpeg process (pid=$pid) left after an unexpected app shutdown.');
    await _terminatePid(pid);
    await _clearProcessState();
    return false;
  }

  Future<bool> _isTargetFfmpegProcessAlive({
    required int pid,
    required String ffmpegPath,
    required String segmentsDir,
  }) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_Process -Filter "ProcessId = $pid").CommandLine',
        ]);
        if (result.exitCode != 0) return false;
        final commandLine = (result.stdout as String).trim().toLowerCase();
        if (commandLine.isEmpty) return false;
        return commandLine.contains('ffmpeg') && commandLine.contains(segmentsDir.toLowerCase());
      }

      final result = await Process.run('ps', ['-p', '$pid', '-o', 'command=']);
      if (result.exitCode != 0) return false;
      final commandLine = (result.stdout as String).trim().toLowerCase();
      if (commandLine.isEmpty) return false;

      final normalizedFfmpegPath = ffmpegPath.toLowerCase();
      return (commandLine.contains(normalizedFfmpegPath) || commandLine.contains('ffmpeg')) &&
          commandLine.contains(segmentsDir.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<void> _terminatePid(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
        return;
      }

      Process.killPid(pid, ProcessSignal.sigint);
      await Future.delayed(const Duration(seconds: 2));
      final stillAlive = await _isPidAlive(pid);
      if (stillAlive) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Future<bool> _isPidAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
        if (result.exitCode != 0) return false;
        return (result.stdout as String).contains('$pid');
      }

      final result = await Process.run('ps', ['-p', '$pid']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<File> _processStateFile() async {
    final supportDir = await _paths.appSupportDir();
    return File(p.join(supportDir.path, 'buffer_process_state.json'));
  }

  Future<void> _writeProcessState({
    required int pid,
    required String ffmpegPath,
    required String segmentsDir,
    required DateTime startedAt,
  }) async {
    final file = await _processStateFile();
    final json = jsonEncode({
      'pid': pid,
      'ffmpegPath': ffmpegPath,
      'segmentsDir': segmentsDir,
      'startedAtUtc': startedAt.toIso8601String(),
    });
    await file.writeAsString(json, mode: FileMode.write, flush: true);
  }

  Future<Map<String, dynamic>?> _readProcessState() async {
    final file = await _processStateFile();
    if (!await file.exists()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore broken state file.
    }

    return null;
  }

  Future<void> _clearProcessState() async {
    final file = await _processStateFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _cleanSegments(Directory dir, {required int maxAgeMinutes}) async {
    final threshold = DateTime.now().subtract(Duration(minutes: maxAgeMinutes));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.ts')) continue;
      final stat = await entity.stat();
      if (stat.modified.isBefore(threshold)) {
        await entity.delete();
      }
    }
  }

  Future<bool> _hasSegmentFiles(Directory dir) async {
    if (!await dir.exists()) {
      return false;
    }

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.ts')) {
        return true;
      }
    }
    return false;
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) return this;
    return skip(length - count);
  }
}
