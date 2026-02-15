import 'capture_device.dart';

class AppConfig {
  const AppConfig({
    this.ffmpegPath,
    this.ffplayPath,
    this.outputDir,
    this.sourceKind,
    this.selectedVideoDevice,
    this.selectedAudioDevice,
    this.codec,
    this.videoBitrate = '8M',
    this.fps = 30,
    this.segmentSeconds = 1,
    this.bufferMinutes = 8,
    this.preRollSeconds = 2,
    this.languageCode = 'en',
  });

  final String? ffmpegPath;
  final String? ffplayPath;
  final String? outputDir;
  final CaptureSourceKind? sourceKind;
  final CaptureDevice? selectedVideoDevice;
  final CaptureDevice? selectedAudioDevice;
  final String? codec;
  final String videoBitrate;
  final int fps;
  final int segmentSeconds;
  final int bufferMinutes;
  final int preRollSeconds;
  final String languageCode;

  bool get isComplete =>
      (ffmpegPath?.isNotEmpty ?? false) &&
      (outputDir?.isNotEmpty ?? false) &&
      sourceKind != null &&
      selectedVideoDevice != null &&
      selectedAudioDevice != null;

  AppConfig copyWith({
    String? ffmpegPath,
    String? ffplayPath,
    String? outputDir,
    CaptureSourceKind? sourceKind,
    CaptureDevice? selectedVideoDevice,
    CaptureDevice? selectedAudioDevice,
    String? codec,
    String? videoBitrate,
    int? fps,
    int? segmentSeconds,
    int? bufferMinutes,
    int? preRollSeconds,
    String? languageCode,
    bool clearVideoDevice = false,
    bool clearAudioDevice = false,
  }) {
    return AppConfig(
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      ffplayPath: ffplayPath ?? this.ffplayPath,
      outputDir: outputDir ?? this.outputDir,
      sourceKind: sourceKind ?? this.sourceKind,
      selectedVideoDevice: clearVideoDevice ? null : (selectedVideoDevice ?? this.selectedVideoDevice),
      selectedAudioDevice: clearAudioDevice ? null : (selectedAudioDevice ?? this.selectedAudioDevice),
      codec: codec ?? this.codec,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      fps: fps ?? this.fps,
      segmentSeconds: segmentSeconds ?? this.segmentSeconds,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      preRollSeconds: preRollSeconds ?? this.preRollSeconds,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
