import 'dart:io';

import '../../domain/models/app_config.dart';
import 'capture_backend.dart';

class PreviewService {
  PreviewService(this._backend);

  final CaptureBackend _backend;
  Process? _process;

  bool get isRunning => _process != null;

  Future<void> start(AppConfig config, void Function(String line) onLog) async {
    await stop();
    if (config.ffplayPath == null) throw Exception('ffplay is not configured');
    final args = [
      ..._backend.buildInputArgs(config),
      '-window_title',
      'Gym Capture Preview',
    ];
    _process = await Process.start(config.ffplayPath!, args);
    _process!.stderr.transform(SystemEncoding().decoder).listen(onLog);
    _process!.stdout.transform(SystemEncoding().decoder).listen(onLog);
    _process!.exitCode.then((_) => _process = null);
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
  }
}
