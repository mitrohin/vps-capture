import 'dart:io';

import '../../domain/models/app_config.dart';
import 'capture_backend.dart';

class PreviewService {
  PreviewService(this._backend);

  final CaptureBackend _backend;
  Process? _ffmpegProcess;
  Process? _ffplayProcess;

  bool get isRunning => _ffplayProcess != null;

  Future<void> start(AppConfig config, void Function(String line) onLog) async {
    await stop();
    if (config.ffmpegPath == null) throw Exception('ffmpeg is not configured');
    if (config.ffplayPath == null) throw Exception('ffplay is not configured');
    final ffmpegArgs = [
      ..._backend.buildInputArgs(config),
      '-an',
      '-c:v',
      'mpeg1video',
      '-f',
      'mpegts',
      '-',
    ];
    final ffplayArgs = [
      '-fflags',
      'nobuffer',
      '-flags',
      'low_delay',
      '-framedrop',
      '-f',
      'mpegts',
      '-i',
      '-',
      '-window_title',
      'Gym Capture Preview',
    ];

    _ffplayProcess = await Process.start(config.ffplayPath!, ffplayArgs);
    _ffmpegProcess = await Process.start(config.ffmpegPath!, ffmpegArgs);

    _ffmpegProcess!.stdout.listen(
      (chunk) => _ffplayProcess?.stdin.add(chunk),
      onDone: () => _ffplayProcess?.stdin.close(),
    );

    _ffmpegProcess!.stderr.transform(SystemEncoding().decoder).listen(onLog);
    _ffplayProcess!.stderr.transform(SystemEncoding().decoder).listen(onLog);
    _ffplayProcess!.stdout.transform(SystemEncoding().decoder).listen(onLog);

    _ffplayProcess!.exitCode.then((_) => _ffplayProcess = null);
    _ffmpegProcess!.exitCode.then((_) => _ffmpegProcess = null);
  }

  Future<void> stop() async {
    _ffmpegProcess?.kill();
    _ffplayProcess?.kill();
    _ffmpegProcess = null;
    _ffplayProcess = null;
  }
}
