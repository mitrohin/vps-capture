import '../../domain/models/app_config.dart';
import '../../domain/models/capture_device.dart';

class CaptureBackend {
  List<String> buildInputArgs(AppConfig config) {
    final source = config.sourceKind;
    final device = config.selectedDevice;
    if (source == null || device == null) throw ArgumentError('Missing source or device');

    switch (source) {
      case CaptureSourceKind.avFoundation:
        // Some macOS setups fail to initialize AVFoundation input when a microphone
        // is auto-attached to a video source. Use video-only capture by default for
        // stable segment buffering.
        return ['-f', 'avfoundation', '-framerate', '${config.fps}', '-i', '${device.id}:none'];
      case CaptureSourceKind.directShow:
        // `id`/`audioId` can store alternative DirectShow names (`@device_*`),
        // which are safer for non-ASCII device labels.
        final input = device.audioId == null
            ? 'video=${device.id}'
            : 'video=${device.id}:audio=${device.audioId}';
        return ['-f', 'dshow', '-i', input];
      case CaptureSourceKind.deckLink:
        return ['-f', 'decklink', '-i', device.name];
    }
  }
}
