import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/app_config.dart';
import '../storage/app_paths.dart';
import 'capture_backend.dart';

class BufferRecorder {
  BufferRecorder(this._paths, this._backend);

  final AppPaths _paths;
  final CaptureBackend _backend;
  Process? _process;
  Timer? _cleanupTimer;
  bool _isStopping = false;

  bool get isRunning => _process != null;

  Future<Directory> start(
    AppConfig config,
    void Function(String line) onLog,
    void Function() onUnexpectedExit,
  ) async {
    await stop();
    final segmentsDir = await _paths.segmentsDir();
    await _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
    final inputArgsWithProbeFlags = _prependInputTuningFlags(_backend.buildInputArgs(config));

    final args = <String>[
      ...inputArgsWithProbeFlags,
      '-map',
      '0:v:0',
      '-map',
      '0:a:0?',
      '-c:v',
      config.codec ?? 'libx264',
      if ((config.codec ?? 'libx264') == 'libx264') ...[
        '-preset',
        config.ffmpegPreset,
        '-tune',
        'zerolatency',
        '-pix_fmt',
        'yuv420p',
      ],
      '-b:v',
      config.videoBitrate,
      '-c:a',
      'aac',
      '-b:a',
      config.audioBitrate,
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
    onLog('Starting FFmpeg buffer recorder: ${config.ffmpegPath} ${args.join(' ')}');
    _process = await Process.start(config.ffmpegPath!, args);
    final process = _process!;
    process.stderr.transform(SystemEncoding().decoder).listen(onLog);
    process.stdout.transform(SystemEncoding().decoder).listen(onLog);
    process.exitCode.then((_) {
      final isCurrentProcess = identical(_process, process);
      final isUnexpectedExit = isCurrentProcess && !_isStopping;
      if (isCurrentProcess) {
        _process = null;
      }
      _cleanupTimer?.cancel();
      _isStopping = false;
      if (isUnexpectedExit) onUnexpectedExit();
    });

    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
    });

    return segmentsDir;
  }

  List<String> _prependInputTuningFlags(List<String> inputArgs) {
    // `-analyzeduration 0` is too aggressive for many live cameras/capture cards:
    // FFmpeg can fail stream detection during startup and exit before the first
    // segment is written. Keep a larger probe window instead of forcing zero.
    const inputTuningFlags = <String>['-probesize', '32M'];
    final inputIndex = inputArgs.indexOf('-i');
    if (inputIndex <= 0) {
      return [...inputTuningFlags, ...inputArgs];
    }

    return [
      ...inputArgs.take(inputIndex),
      ...inputTuningFlags,
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
}
