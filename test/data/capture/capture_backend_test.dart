import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/capture/capture_backend.dart';
import 'package:vps_capture/domain/models/app_config.dart';
import 'package:vps_capture/domain/models/capture_device.dart';

void main() {
  final backend = CaptureBackend();

  CaptureDevice videoDevice({String id = 'video0', String name = 'Video Device'}) =>
      CaptureDevice.videoDevice(id: id, name: name);

  CaptureDevice audioDevice({String id = 'audio0', String name = 'Audio Device', String? audioId}) =>
      CaptureDevice(
        id: id,
        name: name,
        audioId: audioId,
        audioName: name,
        type: DeviceType.audio,
      );

  AppConfig configFor(CaptureSourceKind sourceKind) => AppConfig(
        ffmpegPath: 'ffmpeg',
        outputDir: '/tmp',
        sourceKind: sourceKind,
        selectedVideoDevice: videoDevice(),
        selectedAudioDevice: audioDevice(audioId: 'Mic 1'),
        codec: 'libx264',
        fps: 50,
      );

  group('buildInputArgs', () {
    test('uses requested fps for AVFoundation input', () {
      final args = backend.buildInputArgs(configFor(CaptureSourceKind.avFoundation));

      expect(args, ['-f', 'avfoundation', '-framerate', '50', '-i', 'video0:none']);
    });

    test('uses requested fps for DirectShow input', () {
      final args = backend.buildInputArgs(configFor(CaptureSourceKind.directShow));

      expect(args, ['-f', 'dshow', '-framerate', '50', '-i', 'video=video0:audio=Mic 1']);
    });
  });

  group('buildOutputVideoArgs', () {
    test('forces CFR output at configured fps', () {
      final args = backend.buildOutputVideoArgs(configFor(CaptureSourceKind.directShow));

      expect(args, containsAllInOrder(['-c:v', 'libx264', '-vsync', 'cfr', '-r', '50']));
      expect(args, containsAllInOrder(['-preset', 'veryfast', '-tune', 'zerolatency', '-pix_fmt', 'yuv420p']));
    });
  });
}
