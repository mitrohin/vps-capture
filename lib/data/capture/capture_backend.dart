import '../../domain/models/app_config.dart';
import '../../domain/models/capture_device.dart';

class CaptureBackend {
  List<String> buildInputArgs(AppConfig config) {
    final source = config.sourceKind;
    final videoDevice = config.selectedVideoDevice;
    final audioDevice = config.selectedAudioDevice;
    if (source == null || videoDevice == null || audioDevice == null) throw ArgumentError('Missing source or device');

    switch (source) {
      case CaptureSourceKind.avFoundation:
        // Some macOS setups fail to initialize AVFoundation input when a microphone
        // is auto-attached to a video source. Use video-only capture by default for
        // stable segment buffering.
        return ['-f', 'avfoundation', '-framerate', '${config.fps}', '-i', '${videoDevice.id}:none'];
      case CaptureSourceKind.directShow:
        // `id`/`audioId` can store alternative DirectShow names (`@device_*`),
        // which are safer for non-ASCII device labels.
        final input = audioDevice.audioId == null
            ? 'video=${videoDevice.id}'
            : 'video=${videoDevice.id}:audio=${audioDevice.audioId}';
        return ['-f', 'dshow', '-i', input];
      case CaptureSourceKind.deckLink:
        return ['-f', 'decklink', '-i', videoDevice.name];
    }
  }
}
