import '../../domain/models/app_config.dart';
import '../../domain/models/capture_device.dart';

class CaptureBackend {
  List<String> buildInputArgs(AppConfig config) {
    final source = config.sourceKind;
    final device = config.selectedDevice;
    if (source == null || device == null) throw ArgumentError('Missing source or device');

    switch (source) {
      case CaptureSourceKind.avFoundation:
        final audio = device.audioId ?? 'none';
        return ['-f', 'avfoundation', '-framerate', '${config.fps}', '-i', '${device.id}:$audio'];
      case CaptureSourceKind.directShow:
        final input = device.audioName == null
            ? 'video="${device.name}"'
            : 'video="${device.name}":audio="${device.audioName}"';
        return ['-f', 'dshow', '-i', input];
      case CaptureSourceKind.deckLink:
        return ['-f', 'decklink', '-i', device.name];
    }
  }
}
