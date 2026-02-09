import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/capture/buffer_recorder.dart';
import '../data/capture/capture_backend.dart';
import '../data/capture/capture_service.dart';
import '../data/capture/clip_exporter.dart';
import '../data/capture/preview_service.dart';
import '../data/ffmpeg/device_scanner.dart';
import '../data/ffmpeg/ffmpeg_installer.dart';
import '../data/ffmpeg/ffmpeg_locator.dart';
import '../data/schedule/schedule_parser.dart';
import '../data/storage/app_paths.dart';
import '../domain/models/app_config.dart';
import '../domain/models/capture_device.dart';
import '../domain/models/schedule_item.dart';
import 'app_state.dart';

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  final paths = AppPaths();
  final backend = CaptureBackend();
  return AppController(
    FfmpegLocator(paths),
    FfmpegInstaller(paths, Dio()),
    DeviceScanner(),
    ScheduleParser(),
    CaptureService(BufferRecorder(paths, backend), ClipExporter(paths)),
    PreviewService(backend),
  )..initialize();
});

class AppController extends StateNotifier<AppState> {
  AppController(
    this._locator,
    this._installer,
    this._scanner,
    this._parser,
    this._capture,
    this._preview,
  ) : super(const AppState());

  final FfmpegLocator _locator;
  final FfmpegInstaller _installer;
  final DeviceScanner _scanner;
  final ScheduleParser _parser;
  final CaptureService _capture;
  final PreviewService _preview;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final located = await _locator.locate();
    final codec = Platform.isMacOS ? 'h264_videotoolbox' : 'libx264';
    final cfg = AppConfig(
      ffmpegPath: _stringOrNull(_prefs!.getString('ffmpegPath')) ?? located.ffmpegPath,
      ffplayPath: _stringOrNull(_prefs!.getString('ffplayPath')) ?? located.ffplayPath,
      outputDir: _stringOrNull(_prefs!.getString('outputDir')),
      sourceKind: _readSource(_prefs!.getString('sourceKind')),
      selectedDevice: _readDevice(_prefs!.getString('selectedDevice')),
      codec: _stringOrNull(_prefs!.getString('codec')) ?? codec,
      videoBitrate: _prefs!.getString('videoBitrate') ?? '8M',
      fps: _prefs!.getInt('fps') ?? 30,
      segmentSeconds: _prefs!.getInt('segmentSeconds') ?? 1,
      bufferMinutes: _prefs!.getInt('bufferMinutes') ?? 8,
      preRollSeconds: _prefs!.getInt('preRollSeconds') ?? 2,
      languageCode: _stringOrNull(_prefs!.getString('languageCode')) ?? 'en',
    );

    state = state.copyWith(config: cfg);
    if (cfg.isComplete) {
      await enterWorkMode();
    }
  }

  Future<void> installFfmpeg() async {
    await _guard(() async {
      _appendLog('Installing ffmpeg/ffplay...');
      final result = await _installer.installAutomatically();
      await updateConfig(state.config.copyWith(
        ffmpegPath: result.ffmpegPath,
        ffplayPath: result.ffplayPath,
      ));
      _appendLog('Install complete.');
    });
  }

  Future<void> detectDevices() async {
    final cfg = state.config;
    if (cfg.ffmpegPath == null || cfg.sourceKind == null) return;
    await _guard(() async {
      _appendLog('Scanning devices...');
      final scannedDevices = await _scanner.scan(ffmpegPath: cfg.ffmpegPath!, kind: cfg.sourceKind!);
      final devices = _deduplicateDevices(scannedDevices);

      final selectedDevice = cfg.selectedDevice == null
          ? null
          : devices.where((d) => _isSameDevice(d, cfg.selectedDevice!)).firstOrNull;

      state = state.copyWith(
        devices: devices,
        config: cfg.copyWith(
          selectedDevice: selectedDevice,
          clearDevice: selectedDevice == null,
        ),
      );
      _appendLog('Found ${devices.length} devices.');
    });
  }

  Future<void> updateConfig(AppConfig config) async {
    state = state.copyWith(config: config);
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString('ffmpegPath', config.ffmpegPath ?? '');
    await prefs.setString('ffplayPath', config.ffplayPath ?? '');
    await prefs.setString('outputDir', config.outputDir ?? '');
    await prefs.setString('sourceKind', config.sourceKind?.name ?? '');
    await prefs.setString('selectedDevice', config.selectedDevice == null ? '' : jsonEncode(config.selectedDevice!.toJson()));
    await prefs.setString('codec', config.codec ?? '');
    await prefs.setString('videoBitrate', config.videoBitrate);
    await prefs.setInt('fps', config.fps);
    await prefs.setInt('segmentSeconds', config.segmentSeconds);
    await prefs.setInt('bufferMinutes', config.bufferMinutes);
    await prefs.setInt('preRollSeconds', config.preRollSeconds);
    await prefs.setString('languageCode', config.languageCode);
  }


  Future<void> setLanguage(String languageCode) async {
    await updateConfig(state.config.copyWith(languageCode: languageCode));
  }
  Future<void> loadSchedule() async {
    await _guard(() async {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (res == null || res.files.single.path == null) return;
      final file = File(res.files.single.path!);
      final content = await file.readAsString();
      applySchedule(content, source: 'file');
    });
  }

  void applySchedule(String content, {String source = 'ui'}) {
    final schedule = _parser.parse(content);
    state = state.copyWith(schedule: schedule, selectedIndex: schedule.isNotEmpty ? 0 : null);
    _appendLog('Loaded schedule from $source: ${schedule.length} items.');
  }

  Future<void> enterWorkMode() async {
    if (!state.config.isComplete) {
      _appendLog('Setup incomplete: choose ffmpeg, output folder, source, and device.');
      return;
    }
    state = state.copyWith(mode: AppMode.work);
    _appendLog('Entered work mode. Buffer will start on START and stop on STOP.');
  }

  Future<void> backToSetup() async {
    await _capture.stopBuffer();
    await _preview.stop();
    state = state.copyWith(mode: AppMode.setup, isPreviewRunning: false, isRecordingMarked: false, clearMarkStart: true);
  }

  Future<void> startMark([int? index]) async {
    final targetIndex = index ?? state.selectedIndex;
    if (targetIndex == null || targetIndex < 0 || targetIndex >= state.schedule.length) return;
    final item = state.schedule[targetIndex];
    if (state.isRecordingMarked) {
      _appendLog('Cannot START: recording already marked.');
      return;
    }

    await _guard(() async {
      await _capture.startBuffer(state.config, _appendLog, () {
        _appendLog('Buffer process exited unexpectedly. Recording mark cancelled.');
        final activeIndex = state.schedule.indexWhere((entry) => entry.status == ScheduleItemStatus.active);
        if (activeIndex == -1) return;
        final currentItem = state.schedule[activeIndex];
        final reset = [...state.schedule];
        reset[activeIndex] = currentItem.copyWith(
          status: ScheduleItemStatus.pending,
          clearStartedAt: true,
        );
        state = state.copyWith(
          schedule: reset,
          isRecordingMarked: false,
          clearMarkStart: true,
        );
      });

      final start = DateTime.now();
      final updated = [...state.schedule];
      updated[targetIndex] = item.copyWith(status: ScheduleItemStatus.active, startedAt: start);
      state = state.copyWith(
        schedule: updated,
        selectedIndex: targetIndex,
        isRecordingMarked: true,
        currentMarkStartedAt: start,
      );
      _appendLog('START marked for ${item.label}. Buffer recording started.');
    });
  }

  Future<void> stopMark([int? index]) async {
    final activeIndex = state.schedule.indexWhere((entry) => entry.status == ScheduleItemStatus.active);
    if (activeIndex == -1) return;
    if (index != null && index != activeIndex) return;
    final item = state.schedule[activeIndex];
    if (!state.isRecordingMarked || state.currentMarkStartedAt == null) {
      _appendLog('Cannot STOP: no active START mark.');
      return;
    }

    await _guard(() async {
      final stop = DateTime.now();
      await _capture.stopBuffer();

      try {
        final out = await _capture.exportClip(
          config: state.config,
          start: state.currentMarkStartedAt!,
          stop: stop,
          fio: item.fio,
          apparatus: item.apparatus,
          onLog: _appendLog,
        );
        final updated = [...state.schedule];
        updated[activeIndex] = item.copyWith(status: ScheduleItemStatus.done, clearStartedAt: true);
        final nextIndex = _findNextReady(updated, activeIndex);
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
          selectedIndex: nextIndex,
        );
        _appendLog('STOP complete, clip saved: $out');
      } catch (_) {
        final updated = [...state.schedule];
        updated[activeIndex] = item.copyWith(status: ScheduleItemStatus.pending, clearStartedAt: true);
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
        );
        rethrow;
      }
    });
  }

  void postpone([int? index]) {
    final targetIndex = index ?? state.selectedIndex;
    if (targetIndex == null || targetIndex < 0 || targetIndex >= state.schedule.length) return;

    final updated = [...state.schedule];
    final item = updated.removeAt(targetIndex).copyWith(
      status: ScheduleItemStatus.postponed,
      clearStartedAt: true,
    );
    updated.add(item);
    final fallbackIndex = updated.isEmpty ? null : (targetIndex >= updated.length ? updated.length - 1 : targetIndex);
    state = state.copyWith(schedule: updated, selectedIndex: fallbackIndex);
    _appendLog('Marked as POSTPONED: ${item.label}.');
  }

  void restoreItem(int index) {
    if (index < 0 || index >= state.schedule.length) return;
    final item = state.schedule[index];
    if (item.status != ScheduleItemStatus.done) return;

    final updated = [...state.schedule];
    updated[index] = item.copyWith(status: ScheduleItemStatus.pending, clearStartedAt: true);
    state = state.copyWith(schedule: updated, selectedIndex: index);
    _appendLog('Restored item: ${item.label}.');
  }

  void selectIndex(int index) {
    if (index < 0 || index >= state.schedule.length) return;
    state = state.copyWith(selectedIndex: index);
  }

  void selectNext() {
    if (state.schedule.isEmpty) return;
    final current = state.selectedIndex ?? 0;
    selectIndex((current + 1).clamp(0, state.schedule.length - 1));
  }

  void selectPrevious() {
    if (state.schedule.isEmpty) return;
    final current = state.selectedIndex ?? 0;
    selectIndex((current - 1).clamp(0, state.schedule.length - 1));
  }

  Future<void> togglePreview() async {
    await _guard(() async {
      if (state.isPreviewRunning) {
        await _preview.stop();
        state = state.copyWith(isPreviewRunning: false);
        _appendLog('Preview stopped.');
      } else {
        await _preview.start(state.config, _appendLog);
        state = state.copyWith(isPreviewRunning: true);
        _appendLog('Preview started.');
      }
    });
  }

  int _findNextReady(List<ScheduleItem> items, int from) {
    for (var i = from + 1; i < items.length; i++) {
      final status = items[i].status;
      if (status == ScheduleItemStatus.pending || status == ScheduleItemStatus.postponed) return i;
    }
    for (var i = 0; i < from; i++) {
      final status = items[i].status;
      if (status == ScheduleItemStatus.pending || status == ScheduleItemStatus.postponed) return i;
    }
    return from;
  }


  String? _stringOrNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
  CaptureSourceKind? _readSource(String? value) {
    if (value == null || value.isEmpty) return null;
    return CaptureSourceKind.values.where((e) => e.name == value).firstOrNull;
  }

  CaptureDevice? _readDevice(String? value) {
    if (value == null || value.isEmpty) return null;
    final map = jsonDecode(value) as Map<String, dynamic>;
    return CaptureDevice.fromJson(map);
  }

  Future<void> _guard(Future<void> Function() work) async {
    try {
      state = state.copyWith(isLoading: true);
      await work();
    } catch (e, st) {
      _appendLog('ERROR: $e');
      if (kDebugMode) {
        _appendLog('$st');
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _appendLog(String line) {
    final next = [...state.logs, '[${DateTime.now().toIso8601String()}] $line'];
    state = state.copyWith(logs: next.takeLast(400).toList());
  }

  List<CaptureDevice> _deduplicateDevices(List<CaptureDevice> devices) {
    final uniqueByKey = <String, CaptureDevice>{};
    for (final device in devices) {
      final key = '${device.id}|${device.name}|${device.audioId ?? ''}|${device.audioName ?? ''}';
      uniqueByKey.putIfAbsent(key, () => device);
    }
    return uniqueByKey.values.toList();
  }

  bool _isSameDevice(CaptureDevice left, CaptureDevice right) {
    return left.id == right.id &&
        left.name == right.name &&
        left.audioId == right.audioId &&
        left.audioName == right.audioName;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  Iterable<T> takeLast(int count) {
    if (length <= count) return this;
    return skip(length - count);
  }
}
