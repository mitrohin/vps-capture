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

  bool get isRunning => _process != null;

  Future<Directory> start(
    AppConfig config,
    void Function(String line) onLog,
    void Function() onUnexpectedExit,
  ) async {
    await stop();
    final segmentsDir = await _paths.segmentsDir();
    await _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);

    final args = <String>[
      ..._backend.buildInputArgs(config),
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

    _process = await Process.start(config.ffmpegPath!, args);
    _process!.stderr.transform(SystemEncoding().decoder).listen(onLog);
    _process!.stdout.transform(SystemEncoding().decoder).listen(onLog);
    _process!.exitCode.then((_) {
      final hadProcess = _process != null;
      _process = null;
      _cleanupTimer?.cancel();
      if (hadProcess) onUnexpectedExit();
    });

    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanSegments(segmentsDir, maxAgeMinutes: config.bufferMinutes);
    });

    return segmentsDir;
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    final process = _process;
    if (process == null) return;

    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
      process.kill();
      return process.exitCode;
    });
    _process = null;
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
