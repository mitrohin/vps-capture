import '../../data/services/config_services.dart';
import 'capture_device.dart';
import 'gif_title_theme.dart';

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
    this.audioBitrate = '128k',
    this.ffmpegPreset = 'veryfast',
    this.movFlags = '+faststart',
    this.fps = 50,
    this.segmentSeconds = 1,
    this.bufferMinutes = 8,
    this.preRollSeconds = 2,
    this.recordingStartTrimMillis = 500,
    this.languageCode = 'en',
    this.selectedGif,
    this.gifTitleThemes,
    this.version = '2.2.5',
    this.webServerPort = 38117,
  });

  final String? ffmpegPath;
  final String? ffplayPath;
  final String? outputDir;
  final CaptureSourceKind? sourceKind;
  final CaptureDevice? selectedVideoDevice;
  final CaptureDevice? selectedAudioDevice;
  final String? codec;
  final String videoBitrate;
  final String audioBitrate;
  final String ffmpegPreset;
  final String movFlags;
  final int fps;
  final int segmentSeconds;
  final int bufferMinutes;
  final int preRollSeconds;
  final int recordingStartTrimMillis;
  final String languageCode;
  final String? selectedGif;
  final Map<String, GifTitleTheme>? gifTitleThemes;
  final String version;
  final int webServerPort;

  Map<String, GifTitleTheme> get resolvedGifTitleThemes =>
      gifTitleThemes ?? ConfigService.copyDefaultTitleThemes();

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
    String? audioBitrate,
    String? ffmpegPreset,
    String? movFlags,
    int? fps,
    int? segmentSeconds,
    int? bufferMinutes,
    int? preRollSeconds,
    int? recordingStartTrimMillis,
    String? languageCode,
    bool clearVideoDevice = false,
    bool clearAudioDevice = false,
    String? selectedGif,
    Map<String, GifTitleTheme>? gifTitleThemes,
    String? version,
    int? webServerPort,
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
      audioBitrate: audioBitrate ?? this.audioBitrate,
      ffmpegPreset: ffmpegPreset ?? this.ffmpegPreset,
      movFlags: movFlags ?? this.movFlags,
      fps: fps ?? this.fps,
      segmentSeconds: segmentSeconds ?? this.segmentSeconds,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      preRollSeconds: preRollSeconds ?? this.preRollSeconds,
      recordingStartTrimMillis: recordingStartTrimMillis ?? this.recordingStartTrimMillis,
      languageCode: languageCode ?? this.languageCode,
      selectedGif: selectedGif ?? this.selectedGif,
      gifTitleThemes: gifTitleThemes ?? this.gifTitleThemes,
      version: version ?? this.version,
      webServerPort: webServerPort ?? this.webServerPort,
    );
  }
}
