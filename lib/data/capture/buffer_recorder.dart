import 'dart:async';
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
  Timer? _cleanupTimer;
  bool _isStopping = false;
  static const Duration _startupTimeout = Duration(seconds: 3);

  bool get isRunning => _process != null;

  Future<Directory> start(
    AppConfig config,
    void Function(String line) onLog,
    void Function() onUnexpectedExit,
  ) async {
    await stop();
    final segmentsDir = await _paths.segmentsDir();
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
    final process = _process;
    if (process == null) return;

    _isStopping = true;
    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
      process.kill();
      return process.exitCode;
    });
    if (identical(_process, process)) {
      _process = null;
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
