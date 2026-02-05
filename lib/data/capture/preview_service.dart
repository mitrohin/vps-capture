import 'dart:io';

import '../../domain/models/app_config.dart';
import 'capture_backend.dart';

class PreviewService {
  PreviewService(this._backend);

  final CaptureBackend _backend;
  Process? _ffplayProcess;

  bool get isRunning => _ffplayProcess != null;

  Future<void> start(AppConfig config, void Function(String line) onLog) async {
    await stop();
    if (config.ffplayPath == null) throw Exception('ffplay is not configured');

    final ffplayArgs = [
      '-hide_banner',
      '-loglevel',
      'warning',
      '-nostats',
      '-fflags',
      'nobuffer',
      '-flags',
      'low_delay',
      '-framedrop',
      ..._backend.buildInputArgs(config),
      '-window_title',
      'Gym Capture Preview',
    ];

    _ffplayProcess = await Process.start(config.ffplayPath!, ffplayArgs);
    _ffplayProcess!.stderr.transform(SystemEncoding().decoder).listen(onLog);
    _ffplayProcess!.stdout.transform(SystemEncoding().decoder).listen(onLog);

    _ffplayProcess!.exitCode.then((_) => _ffplayProcess = null);
  }

  Future<void> stop() async {
    _ffplayProcess?.kill();
    _ffplayProcess = null;
  }
}
