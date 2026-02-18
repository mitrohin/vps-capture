import '../../domain/models/app_config.dart';
import 'buffer_recorder.dart';
import 'clip_exporter.dart';

class CaptureService {
  CaptureService(this._bufferRecorder, this._clipExporter);

  final BufferRecorder _bufferRecorder;
  final ClipExporter _clipExporter;

  Future<void> startBuffer(
    AppConfig config,
    void Function(String line) onLog,
    void Function() onUnexpectedExit,
  ) {
    return _bufferRecorder.start(config, onLog, onUnexpectedExit);
  }

  Future<void> stopBuffer() => _bufferRecorder.stop();

  Future<String> exportClip({
    required AppConfig config,
    required DateTime start,
    required DateTime stop,
    required String id,
    required String fio,
    required String city,
    required void Function(String line) onLog,
  }) {
    return _clipExporter.exportClip(
      config: config,
      start: start,
      stop: stop,
      id: id,
      fio: fio,
      city: city,
      onLog: onLog,
    );
  }

  bool get isBufferRunning => _bufferRecorder.isRunning;
}
