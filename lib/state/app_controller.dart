import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';

import '../data/capture/buffer_recorder.dart';
import '../data/capture/capture_backend.dart';
import '../data/capture/capture_service.dart';
import '../data/capture/clip_exporter.dart';
import '../data/capture/preview_service.dart';
import '../data/capture/test_record_service.dart';
import '../data/ffmpeg/device_scanner.dart';
import '../data/ffmpeg/ffmpeg_installer.dart';
import '../data/ffmpeg/ffmpeg_locator.dart';
import '../data/schedule/schedule_decoder.dart';
import '../data/schedule/schedule_parser.dart';
import '../data/services/config_services.dart';
import '../data/storage/app_paths.dart';
import '../data/storage/file_namer.dart';
import '../data/storage/json_config_store.dart';
import '../data/web/judge_web_server.dart';
import '../data/web/recorded_clip_index.dart';
import '../domain/models/app_config.dart';
import '../domain/models/capture_device.dart';
import '../domain/models/ffmpeg_issue.dart';
import '../domain/models/gif_title_theme.dart';
import '../domain/models/judge_web_server_status.dart';
import '../domain/models/schedule_item.dart';
import 'app_state.dart';

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  final paths = AppPaths();
  final backend = CaptureBackend();
  final clipExporter = ClipExporter(paths);
  final captureService = CaptureService(BufferRecorder(paths, backend), clipExporter);
  final clipIndex = RecordedClipIndex(paths);
  return AppController(
    FfmpegLocator(paths),
    FfmpegInstaller(paths, Dio()),
    DeviceScanner(),
    ScheduleParser(),
    captureService,
    PreviewService(backend),
    TestRecordService(captureService, clipExporter),
    clipIndex,
    JudgeWebServer(clipIndex),
  )..initialize();
});

class AppController extends StateNotifier<AppState> {
  static const String currentAppVersion = '2.2.6';

  AppController(
    this._locator,
    this._installer,
    this._scanner,
    this._parser,
    this._capture,
    this._preview,
    this._testRecorder,
    this._clipIndex,
    this._judgeWebServer,
  ) : super(const AppState());

  final FfmpegLocator _locator;
  final FfmpegInstaller _installer;
  final DeviceScanner _scanner;
  final ScheduleParser _parser;
  final ScheduleDecoder _scheduleDecoder = ScheduleDecoder();
  final CaptureService _capture;
  final PreviewService _preview;
  final TestRecordService _testRecorder;
  final RecordedClipIndex _clipIndex;
  final JudgeWebServer _judgeWebServer;
  Timer? _configWriteDebounceTimer;
  Future<void>? _shutdownFuture;

  final AppPaths _paths = AppPaths();
  JsonConfigStore? _prefs;

  Future<void> initialize() async {
    final prefs = JsonConfigStore(_paths);
    await prefs.load();
    await _migrateLegacyWindowsSharedPreferencesIfNeeded(prefs);
    _prefs = prefs;

    final hasCompletedFirstLaunch = prefs.getBool('hasCompletedFirstLaunch') ?? false;

    if (!hasCompletedFirstLaunch) {
      await prefs.setAll({'hasCompletedFirstLaunch': true});
    }

    final located = await _locator.locate();
    final cfg = _buildConfigFromPrefs(located);
    await _clipIndex.load();
    state = state.copyWith(config: cfg);
    await loadScheduleFromFile();
    await _syncJudgeWebServer(forceRestart: false);
    if (hasCompletedFirstLaunch && cfg.isComplete) {
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

  Future<void> prepareSetupScreen() async {
    if (state.isLoading) return;
    final cfg = state.config;
    if (cfg.ffmpegPath == null || cfg.sourceKind == null) return;
    await detectDevices();
  }

  Future<void> detectDevices() async {
    final cfg = state.config;
    if (cfg.ffmpegPath == null || cfg.sourceKind == null) return;
    await _guard(() async {
      _appendLog('Scanning devices...');
      final scannedDevices = await _scanner.scan(ffmpegPath: cfg.ffmpegPath!, kind: cfg.sourceKind!);
      final devices = _deduplicateDevices(scannedDevices);

      final selectedVideo = cfg.selectedVideoDevice == null
          ? null
          : devices.where((d) => _isSameDevice(d, cfg.selectedVideoDevice!)).firstOrNull;
      
      final selectedAudio = cfg.selectedAudioDevice == null
          ? null
          : devices.where((d) => _isSameDevice(d, cfg.selectedAudioDevice!)).firstOrNull;

      state = state.copyWith(
        devices: devices,
        config: cfg.copyWith(
          selectedVideoDevice: selectedVideo,
          selectedAudioDevice: selectedAudio,
          clearVideoDevice: selectedVideo == null,
          clearAudioDevice: selectedAudio == null,
        ),
      );
      _appendLog('Found ${devices.length} devices.');
    });
  }

  Future<void> updateConfig(AppConfig config) async {
    state = state.copyWith(config: config);
    _configWriteDebounceTimer?.cancel();
    await _persistConfig(config);
    await _syncJudgeWebServer(forceRestart: state.mode == AppMode.work);
  }

  void updateConfigDebounced(AppConfig config, {Duration delay = const Duration(milliseconds: 350)}) {
    state = state.copyWith(config: config);
    _configWriteDebounceTimer?.cancel();
    unawaited(_syncJudgeWebServer(forceRestart: state.mode == AppMode.work));
    _configWriteDebounceTimer = Timer(delay, () {
      unawaited(_persistConfig(config));
    });
  }

  Future<void> _persistConfig(AppConfig config) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setAll({
      'ffmpegPath': config.ffmpegPath ?? '',
      'ffplayPath': config.ffplayPath ?? '',
      'outputDir': config.outputDir ?? '',
      'sourceKind': config.sourceKind?.name ?? '',
      'selectedVideoDevice': config.selectedVideoDevice == null ? '' : jsonEncode(config.selectedVideoDevice!.toJson()),
      'selectedAudioDevice': config.selectedAudioDevice == null ? '' : jsonEncode(config.selectedAudioDevice!.toJson()),
      'codec': config.codec ?? '',
      'videoBitrate': config.videoBitrate,
      'audioBitrate': config.audioBitrate,
      'ffmpegPreset': config.ffmpegPreset,
      'movFlags': config.movFlags,
      'fps': config.fps,
      'segmentSeconds': config.segmentSeconds,
      'bufferMinutes': config.bufferMinutes,
      'preRollSeconds': config.preRollSeconds,
      'recordingStartTrimMillis': config.recordingStartTrimMillis,
      'languageCode': config.languageCode,
      'selectedGif': config.selectedGif ?? 'blue',
      'gifTitleThemes': jsonEncode(ConfigService.encodeTitleThemes(config.resolvedGifTitleThemes)),
      'version': config.version,
      'webServerPort': config.webServerPort,
    });
  }

  Future<void> resetAllSettings() async {
    await _guard(() async {
      await _capture.stopBuffer();
      await _preview.stop();
      await _testRecorder.stop(state.config, _appendLog);
      _configWriteDebounceTimer?.cancel();

      final located = await _locator.locate();
      final defaultConfig = _defaultConfig(located);

      final prefs = _prefs;
      if (prefs != null) {
        await prefs.clear();
        await prefs.setAll({'hasCompletedFirstLaunch': true});
      }

      await _persistConfig(defaultConfig);
      await _deleteScheduleStorageFiles();
      await _clearSegmentsDirectory();
      await _deleteConcatListFile();
      await _clipIndex.clear();
      await _judgeWebServer.stop();

      state = AppState(
        config: defaultConfig,
        logs: ['[${DateTime.now().toIso8601String()}] Settings were fully reset.'],
      );
    });
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }

  Future<void> shutdown() {
    final inFlightShutdown = _shutdownFuture;
    if (inFlightShutdown != null) {
      return inFlightShutdown;
    }

    final shutdownFuture = _shutdownInternal();
    _shutdownFuture = shutdownFuture;
    return shutdownFuture;
  }

  Future<void> _shutdownInternal() async {
    _configWriteDebounceTimer?.cancel();
    _configWriteDebounceTimer = null;

    await _finalizeActiveRecordingOnShutdown();
    await _preview.stop();
    await _testRecorder.stop(state.config, _appendLog);
    await _judgeWebServer.stop();
  }

  Future<void> _finalizeActiveRecordingOnShutdown() async {
    final activeIndex = state.schedule.indexWhere((entry) => entry.status == ScheduleItemStatus.active);
    final markStartedAt = state.currentMarkStartedAt;

    if (!state.isRecordingMarked || markStartedAt == null || activeIndex == -1) {
      await _capture.stopBuffer();
      return;
    }

    final item = state.schedule[activeIndex];
    final stop = DateTime.now();

    await _capture.stopBuffer();

    try {
      final out = await _capture.exportClip(
        config: state.config,
        start: markStartedAt,
        stop: stop,
        id: item.id,
        fio: item.fio,
        city: item.city,
        onLog: _appendLog,
      );

      final updated = [...state.schedule];
      updated[activeIndex] = item.copyWith(
        status: ScheduleItemStatus.done,
        startedAt: markStartedAt,
      );

      await _clipIndex.add(
        participantId: item.id,
        fio: item.fio,
        city: item.city,
        apparatus: item.apparatus,
        path: out,
        threadIndex: item.threadIndex,
        typeIndex: item.typeIndex,
      );

      state = state.copyWith(
        schedule: updated,
        isRecordingMarked: false,
        clearMarkStart: true,
      );
      await _updateScheduleItemInFile(updated[activeIndex]);
      _appendLog('Shutdown complete, active clip saved: $out');
    } catch (error) {
      final updated = [...state.schedule];
      updated[activeIndex] = item.copyWith(
        status: item.isPinnedToPostponed
            ? ScheduleItemStatus.postponed
            : ScheduleItemStatus.pending,
        clearStartedAt: true,
      );

      state = state.copyWith(
        schedule: updated,
        isRecordingMarked: false,
        clearMarkStart: true,
      );
      await _updateScheduleItemInFile(updated[activeIndex]);
      _appendLog('Failed to save active clip during shutdown: $error');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    await updateConfig(state.config.copyWith(languageCode: languageCode));
  }

  Future<void> setSelectedGif(String selectedGif) async {
    await updateConfig(state.config.copyWith(selectedGif: selectedGif));
  }

  Future<void> updateGifTitleTheme(String gifKey, GifTitleTheme Function(GifTitleTheme theme) update) async {
    final currentThemes = state.config.resolvedGifTitleThemes;
    final currentTheme = currentThemes[gifKey] ?? ConfigService.defaultTitleThemes[gifKey] ?? ConfigService.defaultTitleThemes['blue']!;
    final updatedThemes = {
      for (final entry in currentThemes.entries) entry.key: entry.value.copyWith(),
    };
    updatedThemes[gifKey] = update(currentTheme);
    updateConfigDebounced(state.config.copyWith(gifTitleThemes: updatedThemes));
  }

  Future<void> resetGifTitleTheme(String gifKey) async {
    final updatedThemes = {
      for (final entry in state.config.resolvedGifTitleThemes.entries) entry.key: entry.value.copyWith(),
    };
    final fallback = ConfigService.defaultTitleThemes[gifKey];
    if (fallback != null) {
      updatedThemes[gifKey] = fallback.copyWith();
      await updateConfig(state.config.copyWith(gifTitleThemes: updatedThemes));
    }
  }

  Future<void> loadSchedule() async {
    await _guard(() async {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (res == null || res.files.single.path == null) return;
      final file = File(res.files.single.path!);
      final content = _scheduleDecoder.decode(await file.readAsBytes());
      applySchedule(content, source: 'file');
      createScheduleFile();
    });
  }

  void applySchedule(String content, {String source = 'ui'}) {
    final schedule = _parser.parse(content);
    state = state.copyWith(
      schedule: schedule,
      selectedIndex: schedule.isNotEmpty ? 0 : null,
      isScheduleInputVisible: false,
    );
    _appendLog('Loaded schedule from $source: ${schedule.length} items.');
    createStructOutputDir(content, state.config.outputDir!, schedule);
    createScheduleFile();
    unawaited(_syncJudgeWebServer());
  }

  void setScheduleInputVisibility(bool isVisible) {
    state = state.copyWith(isScheduleInputVisible: isVisible);
  }

  void createStructOutputDir(String content, String mainOutputDir, List scheduleList) {
    try {
      final lines = content.split(RegExp(r'\r?\n'));
      int currentThreadIndex = 0;
      int currentTypeCount = 1;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        if (line.startsWith('/*')) {
          currentThreadIndex++;
          final rawThreadName = line.substring(line.indexOf(' ') + 1);
          final safeThreadName = FileNamer.sanitizeSegment(rawThreadName);
          final threadPath = p.join(
            mainOutputDir,
            '0$currentThreadIndex - $safeThreadName',
          );
          final dirThread = Directory(threadPath);
          if (!dirThread.existsSync()) {
            dirThread.createSync(recursive: true);
          }
          try {
            final splittedTypeCount = line.split(' ')[0];
            currentTypeCount = int.parse(splittedTypeCount.substring(2));
          } catch (e) {
            currentTypeCount = 1;
          }
          if (currentTypeCount > 0) {
            for (int type = 0; type < currentTypeCount; type++) {
              final typePath = p.join(threadPath, '0${type + 1}');
              final dirType = Directory(typePath);
              if (!dirType.existsSync()) {
                dirType.createSync(recursive: true);
              }
            }
          }
        }
      }
    } catch (e) {}
  }

  void createScheduleFile() {
    final scheduleFileData = state.schedule;
    final scheduleFileDir = AppPaths.getScheduleStorageDirectory();
    final filePath = p.join(scheduleFileDir, 'schedule.json');
    final jsonData = scheduleFileData.map((item) => {
      'id': item.id,
      'fio': item.fio,
      'city': item.city,
      'apparatus': item.apparatus,
      'status': item.status.toString().replaceAll("ScheduleItemStatus.", ""),
      'isPinnedToPostponed': item.isPinnedToPostponed,
      'threadIndex': item.threadIndex,
      'typeIndex': item.typeIndex,
      'startedAt': item.startedAt?.toIso8601String(),
    }).toList();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(jsonData);
    
    final file = File(filePath);
    file.writeAsStringSync(jsonString, mode: FileMode.write);
  }

  Future<void> loadScheduleFromFile() async {
    try {
      final scheduleFileDir = AppPaths.getScheduleStorageDirectory();
      final filePath = p.join(scheduleFileDir, 'schedule.json');
      final file = File(filePath);
      final legacyFiles = Platform.isMacOS
          ? AppPaths.getMacOSLegacyScheduleDirectories()
              .map((dirPath) => File(p.join(dirPath, 'schedule.json')))
              .toList(growable: false)
          : <File>[];

      File? sourceFile;
      if (await file.exists()) {
        sourceFile = file;
      } else {
        for (final legacyFile in legacyFiles) {
          if (await legacyFile.exists()) {
            await legacyFile.copy(filePath);
            sourceFile = file;
            _appendLog('Migrated schedule file from legacy path ${legacyFile.path} to $filePath');
            break;
          }
        }
      }

      for (final legacyFile in legacyFiles) {
        if (await legacyFile.exists()) {
          try {
            final legacyFilePath = legacyFile.path;
            await legacyFile.delete();
            _appendLog('Removed legacy schedule file at $legacyFilePath');
          } catch (deleteError) {
            _appendLog('Unable to remove legacy schedule file: $deleteError');
          }
        }
      }

      if (sourceFile != null) {
        final jsonString = await sourceFile.readAsString();
        final List<dynamic> jsonData = jsonDecode(jsonString);
        final List<ScheduleItem> loadedSchedule = jsonData.map((item) {
          final status = _parseStatus(item['status']);
          return ScheduleItem(
            id: item['id'],
            fio: item['fio'],
            apparatus: item['apparatus'],
            city: item['city'],
            status: status,
            isPinnedToPostponed:
                item['isPinnedToPostponed'] == true || status == ScheduleItemStatus.postponed,
            startedAt: item['startedAt'] != null
                ? DateTime.parse(item['startedAt'])
                : null,
            threadIndex: item['threadIndex'],
            typeIndex: item['typeIndex'],
          );
        }).toList();
        state = state.copyWith(
          schedule: loadedSchedule,
          selectedIndex: loadedSchedule.isNotEmpty ? 0 : null,
          isScheduleInputVisible: false,
        );
        _appendLog('Loaded schedule from file: ${loadedSchedule.length} items.');
        await _syncJudgeWebServer();
      } else {
        _appendLog('No schedule file found at: $filePath');
      }
    } catch (e) {
      _appendLog('Error loading schedule file: $e');
    }
  }

  ScheduleItemStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return ScheduleItemStatus.pending;
      case 'active':
        return ScheduleItemStatus.active;
      case 'done':
        return ScheduleItemStatus.done;
      case 'postponed':
        return ScheduleItemStatus.postponed;
      default:
        return ScheduleItemStatus.pending;
    }
  }

  Future<void> _updateScheduleItemInFile(ScheduleItem updatedItem) async {
    try {
      final scheduleFileDir = AppPaths.getScheduleStorageDirectory();
      final filePath = p.join(scheduleFileDir, 'schedule.json');
      final file = File(filePath);
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(jsonString);
        final index = jsonData.indexWhere((item) => item['id'] == updatedItem.id);
        if (index != -1) {
          jsonData[index] = {
            'id': updatedItem.id,
            'fio': updatedItem.fio,
            'city': updatedItem.city,
            'apparatus': updatedItem.apparatus,
            'status': updatedItem.status.toString().replaceAll("ScheduleItemStatus.", ""),
            'isPinnedToPostponed': updatedItem.isPinnedToPostponed,
            'threadIndex': updatedItem.threadIndex,
            'typeIndex': updatedItem.typeIndex,
            'startedAt': updatedItem.startedAt?.toIso8601String(),
          };
          const encoder = JsonEncoder.withIndent('  ');
          final updatedJsonString = encoder.convert(jsonData);
          await file.writeAsString(updatedJsonString, mode: FileMode.write);
          
          _appendLog('Schedule item ${updatedItem.id} updated in file');
        }
      }
    } catch (e) {
      _appendLog('Error updating schedule item in file: $e');
    }
  }

  Future<void> enterWorkMode() async {
    if (!state.config.isComplete) {
      _appendLog('Setup incomplete: choose ffmpeg, output folder, source, and device.');
      return;
    }
    state = state.copyWith(mode: AppMode.work);
    _appendLog('Entered work mode. Buffer will start on START and stop on STOP.');
    await _syncJudgeWebServer(forceRestart: true);
  }

  Future<void> backToSetup() async {
    await _capture.stopBuffer();
    await _preview.stop();
    await _testRecorder.stop(state.config, _appendLog);
    await _judgeWebServer.stop();
    state = state.copyWith(
      mode: AppMode.setup,
      isPreviewRunning: false,
      isRecordingMarked: false,
      clearMarkStart: true,
      judgeWebServerStatus: const JudgeWebServerStatus(),
    );
    await prepareSetupScreen();
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
          status: currentItem.isPinnedToPostponed
              ? ScheduleItemStatus.postponed
              : ScheduleItemStatus.pending,
          clearStartedAt: true,
        );
        state = state.copyWith(
          schedule: reset,
          isRecordingMarked: false,
          clearMarkStart: true,
        );
        _updateScheduleItemInFile(reset[activeIndex]);
      });

      final start = DateTime.now();
      final updated = [...state.schedule];
      updated[targetIndex] = item.copyWith(
        status: ScheduleItemStatus.active,
        startedAt: start,
      );
      state = state.copyWith(
        schedule: updated,
        selectedIndex: targetIndex,
        isRecordingMarked: true,
        currentMarkStartedAt: start,
      );
      await _updateScheduleItemInFile(updated[targetIndex]);
      _appendLog('START marked for ${item.label}. Buffer recording started.');
      await _syncJudgeWebServer();
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
          id: item.id,
          fio: item.fio,
          city: item.city,
          onLog: _appendLog,
        );
        final updated = [...state.schedule];
        updated[activeIndex] = item.copyWith(
          status: ScheduleItemStatus.done, 
          startedAt: state.currentMarkStartedAt,
        );
        await _clipIndex.add(
          participantId: item.id,
          fio: item.fio,
          city: item.city,
          apparatus: item.apparatus,
          path: out,
          threadIndex: item.threadIndex,
          typeIndex: item.typeIndex,
        );
        final nextIndex = _findNextReady(updated, activeIndex);
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
          selectedIndex: nextIndex,
        );
        await _updateScheduleItemInFile(updated[activeIndex]);
        _appendLog('STOP complete, clip saved: $out');
        await _syncJudgeWebServer();
      } catch (_) {
        final updated = [...state.schedule];
        updated[activeIndex] = item.copyWith(
          status: item.isPinnedToPostponed
              ? ScheduleItemStatus.postponed
              : ScheduleItemStatus.pending,
          clearStartedAt: true,
        );
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
        );
        await _updateScheduleItemInFile(updated[activeIndex]);
        await _syncJudgeWebServer();
        rethrow;
      }
    });
  }

  Future<void> postpone([int? index]) async {
    final targetIndex = index ?? state.selectedIndex;
    if (targetIndex == null || targetIndex < 0 || targetIndex >= state.schedule.length) return;

    final targetItem = state.schedule[targetIndex];
    if (state.isRecordingMarked && targetItem.status != ScheduleItemStatus.active) {
      _appendLog('Cannot POSTPONE: another participant is currently recording.');
      return;
    }

    await _guard(() async {
      if (state.isRecordingMarked && targetItem.status == ScheduleItemStatus.active) {
        await _capture.stopBuffer();
        state = state.copyWith(isRecordingMarked: false, clearMarkStart: true);
      }

      final updated = [...state.schedule];
      final item = updated[targetIndex].copyWith(
        status: ScheduleItemStatus.postponed,
        isPinnedToPostponed: true,
        clearStartedAt: true,
      );
      updated[targetIndex] = item;
      state = state.copyWith(schedule: updated, selectedIndex: targetIndex);
      await _updateScheduleItemInFile(item);
      _appendLog('Marked as POSTPONED: ${item.label}.');
      await _syncJudgeWebServer();
    });
  }

  Future<void> restoreAllPostponed() async {
    final postponedIndexes = <int>[];
    final updated = [...state.schedule];
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].isPinnedToPostponed) {
        postponedIndexes.add(i);
        updated[i] = updated[i].copyWith(
          status: ScheduleItemStatus.pending,
          isPinnedToPostponed: false,
          clearStartedAt: true,
        );
      }
    }

    if (postponedIndexes.isEmpty) {
      return;
    }

    final selectedIndex = state.selectedIndex;
    final nextSelectedIndex = (selectedIndex != null && postponedIndexes.contains(selectedIndex))
        ? postponedIndexes.first
        : selectedIndex;

    state = state.copyWith(
      schedule: updated,
      selectedIndex: nextSelectedIndex,
    );

    for (final index in postponedIndexes) {
      await _updateScheduleItemInFile(updated[index]);
    }
    _appendLog('Restored all postponed items: ${postponedIndexes.length}.');
    await _syncJudgeWebServer();
  }

  void restoreItem(int index) {
    if (index < 0 || index >= state.schedule.length) return;
    final item = state.schedule[index];
    if (item.status != ScheduleItemStatus.done && !item.isPinnedToPostponed) return;

    final updated = [...state.schedule];
    updated[index] = item.copyWith(
      status: ScheduleItemStatus.pending,
      isPinnedToPostponed: false,
      clearStartedAt: true,
    );
    state = state.copyWith(schedule: updated, selectedIndex: index);
    unawaited(_updateScheduleItemInFile(updated[index]));
    _appendLog('Restored item: ${item.label}.');
    unawaited(_syncJudgeWebServer());
  }

  void deleteItem(int index) {
    if (index < 0 || index >= state.schedule.length) return;

    final item = state.schedule[index];
    if (state.isRecordingMarked && item.status == ScheduleItemStatus.active) {
      _appendLog('Cannot DELETE: active participant is currently recording.');
      return;
    }

    final updated = [...state.schedule];
    final removed = updated.removeAt(index);

    var nextSelectedIndex = state.selectedIndex;
    if (updated.isEmpty) {
      nextSelectedIndex = null;
    } else if (nextSelectedIndex != null) {
      if (index < nextSelectedIndex) {
        nextSelectedIndex -= 1;
      } else if (index == nextSelectedIndex) {
        nextSelectedIndex = index >= updated.length ? updated.length - 1 : index;
      }
    }

    state = state.copyWith(
      schedule: updated,
      selectedIndex: nextSelectedIndex,
      clearSelectedIndex: updated.isEmpty,
    );
    createScheduleFile();
    _appendLog('Deleted item: ${removed.label}.');
    unawaited(_syncJudgeWebServer());
  }

  void addParticipant({
    required String fio,
    required String city,
    String? apparatus,
    int? threadIndex,
    int? typeIndex,
  }) {
    final trimmedFio = fio.trim();
    final trimmedCity = city.trim();
    final trimmedApparatus = apparatus?.trim();
    if (trimmedFio.isEmpty || trimmedCity.isEmpty) {
      _appendLog('Cannot ADD participant: empty name or city.');
      return;
    }

    final generatedId = 'manual-${DateTime.now().millisecondsSinceEpoch}';
    final item = ScheduleItem(
      id: generatedId,
      fio: trimmedFio,
      city: trimmedCity,
      apparatus: trimmedApparatus?.isEmpty == true ? null : trimmedApparatus,
      threadIndex: threadIndex,
      typeIndex: typeIndex,
    );

    final updated = [...state.schedule, item];
    state = state.copyWith(
      schedule: updated,
      selectedIndex: updated.length - 1,
      isScheduleInputVisible: false,
    );
    createScheduleFile();
    _appendLog('Added participant: ${item.label}.');
    unawaited(_syncJudgeWebServer());
  }

  void selectIndex(int index) {
    if (index < 0 || index >= state.schedule.length) return;
    state = state.copyWith(selectedIndex: index);
  }

  void selectNext() {
    if (state.schedule.isEmpty) return;
    final current = state.selectedIndex ?? -1;
    for (var i = current + 1; i < state.schedule.length; i++) {
      if (state.schedule[i].status != ScheduleItemStatus.done) {
        selectIndex(i);
        return;
      }
    }
  }

  void selectPrevious() {
    if (state.schedule.isEmpty) return;
    final current = state.selectedIndex ?? state.schedule.length;
    for (var i = current - 1; i >= 0; i--) {
      if (state.schedule[i].status != ScheduleItemStatus.done) {
        selectIndex(i);
        return;
      }
    }
  }

  Future<void> togglePreview() async {
    await _guard(() async {
      final config = state.config;
      if (state.isPreviewRunning) {
        await _preview.stop();
        state = state.copyWith(isPreviewRunning: false);
        _appendLog('Preview stopped.');
      } else {
        if ((config.ffplayPath?.isEmpty ?? true) || !config.isComplete) {
          _appendLog('Cannot start preview: configure ffplay, output folder, source, and both devices first.');
          return;
        }
        _appendLog(
          'Starting preview with source=${config.sourceKind!.name}, '
          'video=${config.selectedVideoDevice!.displayLabel}, '
          'audio=${config.selectedAudioDevice!.displayLabel}, '
          'fps=${config.fps}, codec=${config.codec ?? 'libx264'}, '
          'videoBitrate=${config.videoBitrate}, audioBitrate=${config.audioBitrate}.',
        );
        await _preview.start(config, _appendLog);
        state = state.copyWith(isPreviewRunning: true);
        _appendLog('Preview started.');
      }
    });
  }

  Future<void> toggleTestRecording() async {
    await _guard(() async {
      if (state.isTestRecording) {
        final savedPath = await _testRecorder.stop(state.config, _appendLog);
        state = state.copyWith(isTestRecording: false);
        if (savedPath != null) {
          _appendLog('Test recording saved to: $savedPath');
        }
      } else {
        await _testRecorder.start(state.config, _appendLog);
        state = state.copyWith(isTestRecording: true);
      }
    });
  }

  void dismissFfmpegIssue() {
    state = state.copyWith(clearFfmpegIssue: true);
  }

  Future<String?> saveFfmpegIssueReport() async {
    final issue = state.ffmpegIssue;
    if (issue == null) return null;

    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ffmpeg error report',
      fileName: 'ffmpeg_error_${issue.occurredAt.toIso8601String().replaceAll(':', '-')}.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (filePath == null || filePath.trim().isEmpty) {
      return null;
    }

    final file = File(filePath);
    await file.writeAsString(issue.report);
    _appendLog('ffmpeg error report saved: $filePath');
    return filePath;
  }

  Future<void> _syncJudgeWebServer({bool forceRestart = false}) async {
    final config = state.config;
    final snapshot = buildJudgeWebSnapshot(
      languageCode: config.languageCode,
      participants: _buildJudgeWebParticipants(),
    );

    if (state.mode != AppMode.work || !config.isComplete) {
      await _judgeWebServer.stop();
      state = state.copyWith(judgeWebServerStatus: const JudgeWebServerStatus());
      return;
    }

    final currentStatus = state.judgeWebServerStatus;
    final shouldRestart = forceRestart ||
        !currentStatus.isRunning ||
        currentStatus.port != config.webServerPort ||
        currentStatus.urls.isEmpty;

    if (shouldRestart) {
      final status = await _judgeWebServer.start(
        port: config.webServerPort,
        snapshot: snapshot,
      );
      state = state.copyWith(judgeWebServerStatus: status);
      if (status.errorMessage != null) {
        _appendLog('Judge web server error: ${status.errorMessage}');
      } else if (status.isRunning) {
        _appendLog('Judge web server started on port ${status.port}.');
      }
      return;
    }

    await _judgeWebServer.update(snapshot);
    state = state.copyWith(
      judgeWebServerStatus: currentStatus.copyWith(
        isRunning: true,
        port: config.webServerPort,
        clearErrorMessage: true,
      ),
    );
  }

  List<JudgeWebParticipant> _buildJudgeWebParticipants() {
    final participants = state.schedule.map((item) {
      final clip = _clipIndex.latestForParticipant(item.id);
      return JudgeWebParticipant(
        id: item.id,
        fio: item.fio,
        city: item.city,
        apparatus: item.apparatus,
        status: item.status.name,
        statusLabel: AppLocalizations.tr(state.config.languageCode, item.status.name),
        clipId: clip != null && File(clip.path).existsSync() ? clip.clipId : null,
        startedAt: item.startedAt,
        startedAtLabel: item.startedAt?.toLocal().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        threadIndex: item.threadIndex,
        typeIndex: item.typeIndex,
        threadLabel: item.threadIndex == null ? null : 'T${item.threadIndex! + 1}',
        typeLabel: item.typeIndex == null ? null : 'E${item.typeIndex! + 1}',
      );
    }).toList(growable: false);

    participants.sort((left, right) {
      final statusCompare = _judgeStatusWeight(left.status).compareTo(_judgeStatusWeight(right.status));
      if (statusCompare != 0) return statusCompare;

      final leftStartedAt = left.startedAt;
      final rightStartedAt = right.startedAt;
      if (leftStartedAt != null && rightStartedAt != null) {
        final startedAtCompare = rightStartedAt.compareTo(leftStartedAt);
        if (startedAtCompare != 0) return startedAtCompare;
      } else if (leftStartedAt != null || rightStartedAt != null) {
        return leftStartedAt != null ? -1 : 1;
      }

      final threadCompare = (left.threadIndex ?? 1 << 20).compareTo(right.threadIndex ?? 1 << 20);
      if (threadCompare != 0) return threadCompare;
      final typeCompare = (left.typeIndex ?? 1 << 20).compareTo(right.typeIndex ?? 1 << 20);
      if (typeCompare != 0) return typeCompare;
      return left.fio.compareTo(right.fio);
    });
    return participants;
  }

  int _judgeStatusWeight(String status) {
    switch (status) {
      case 'active':
        return 0;
      case 'done':
        return 1;
      case 'pending':
        return 2;
      case 'postponed':
        return 3;
      default:
        return 4;
    }
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

  Future<void> _migrateLegacyWindowsSharedPreferencesIfNeeded(JsonConfigStore prefs) async {
    if (!Platform.isWindows || !prefs.isEmpty) {
      return;
    }

    final legacyFile = await _paths.legacyWindowsSharedPreferencesFile();
    if (legacyFile == null || !await legacyFile.exists()) {
      return;
    }

    try {
      final raw = await legacyFile.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }

      final migrated = <String, dynamic>{};
      decoded.forEach((key, value) {
        final rawKey = key.toString();
        final normalizedKey = rawKey.startsWith('flutter.') ? rawKey.substring(8) : rawKey;
        migrated[normalizedKey] = value;
      });

      if (migrated.isEmpty) {
        return;
      }

      await prefs.setAll(migrated);
      await legacyFile.delete();
      _appendLog('Migrated legacy shared_preferences.json to config.json in the application folder.');
    } catch (error) {
      _appendLog('Unable to migrate legacy shared_preferences.json: $error');
    }
  }

  AppConfig _buildConfigFromPrefs(LocatedFfmpeg located) {
    final prefs = _prefs!;
    final defaultConfig = _defaultConfig(located);
    return AppConfig(
      ffmpegPath: _stringOrNull(prefs.getString('ffmpegPath')) ?? defaultConfig.ffmpegPath,
      ffplayPath: _stringOrNull(prefs.getString('ffplayPath')) ?? defaultConfig.ffplayPath,
      outputDir: _stringOrNull(prefs.getString('outputDir')),
      sourceKind: _readSource(prefs.getString('sourceKind')),
      selectedVideoDevice: _readDevice(prefs.getString('selectedVideoDevice')),
      selectedAudioDevice: _readDevice(prefs.getString('selectedAudioDevice')),
      codec: _stringOrNull(prefs.getString('codec')) ?? defaultConfig.codec,
      videoBitrate: prefs.getString('videoBitrate') ?? defaultConfig.videoBitrate,
      audioBitrate: prefs.getString('audioBitrate') ?? defaultConfig.audioBitrate,
      ffmpegPreset: prefs.getString('ffmpegPreset') ?? defaultConfig.ffmpegPreset,
      movFlags: prefs.getString('movFlags') ?? defaultConfig.movFlags,
      fps: prefs.getInt('fps') ?? defaultConfig.fps,
      segmentSeconds: prefs.getInt('segmentSeconds') ?? defaultConfig.segmentSeconds,
      bufferMinutes: prefs.getInt('bufferMinutes') ?? defaultConfig.bufferMinutes,
      preRollSeconds: prefs.getInt('preRollSeconds') ?? defaultConfig.preRollSeconds,
      recordingStartTrimMillis: prefs.getInt('recordingStartTrimMillis') ?? defaultConfig.recordingStartTrimMillis,
      languageCode: _stringOrNull(prefs.getString('languageCode')) ?? defaultConfig.languageCode,
      selectedGif: prefs.getString('selectedGif') ?? defaultConfig.selectedGif,
      gifTitleThemes: ConfigService.decodeTitleThemes(_decodeJsonMap(prefs.getString('gifTitleThemes'))),
      version: currentAppVersion,
      webServerPort: prefs.getInt('webServerPort') ?? defaultConfig.webServerPort,
    );
  }

  AppConfig _defaultConfig(LocatedFfmpeg located) {
    return AppConfig(
      ffmpegPath: located.ffmpegPath,
      ffplayPath: located.ffplayPath,
      codec: Platform.isMacOS ? 'h264_videotoolbox' : 'libx264',
      selectedGif: 'blue',
      gifTitleThemes: ConfigService.copyDefaultTitleThemes(),
      version: currentAppVersion,
      webServerPort: 38117,
    );
  }

  Future<void> _deleteScheduleStorageFiles() async {
    final storageDir = Directory(AppPaths.getScheduleStorageDirectory());
    final targets = <File>[
      File(p.join(storageDir.path, 'schedule.json')),
      File(p.join(storageDir.path, 'config.json')),
      File(p.join(storageDir.path, 'recorded_clips.json')),
      if (Platform.isWindows) ...(await Future.wait([_paths.legacyWindowsSharedPreferencesFile()])).whereType<File>(),
      if (Platform.isMacOS)
        ...AppPaths.getMacOSLegacyScheduleDirectories()
            .map((dirPath) => File(p.join(dirPath, 'schedule.json'))),
    ];

    for (final file in targets) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _clearSegmentsDirectory() async {
    final segmentsDir = await _paths.segmentsDir();
    if (!await segmentsDir.exists()) {
      return;
    }

    await for (final entity in segmentsDir.list()) {
      await entity.delete(recursive: true);
    }
  }

  Future<void> _deleteConcatListFile() async {
    final concatListFile = await _paths.concatListFile();
    if (await concatListFile.exists()) {
      await concatListFile.delete();
    }
  }


  String? _stringOrNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Map<String, dynamic>? _decodeJsonMap(String? value) {
    final raw = _stringOrNull(value);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
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
    } on FfmpegStartupException catch (error) {
      _appendLog('FFMPEG START ERROR: ${error.message}');
      final output = error.output.trim();
      if (output.isNotEmpty) {
        _appendLog(output);
      }
      state = state.copyWith(ffmpegIssue: _buildFfmpegIssue(error));
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

  FfmpegIssue _buildFfmpegIssue(FfmpegStartupException error) {
    final now = DateTime.now();
    final config = state.config;
    final video = config.selectedVideoDevice;
    final audio = config.selectedAudioDevice;
    final recentLogs = state.logs.takeLast(80).join('\n');
    final summaryBuffer = StringBuffer(error.message);
    if (error.exitCode != null) {
      summaryBuffer.write(' Exit code: ${error.exitCode}.');
    }

    final report = StringBuffer()
      ..writeln('VPS Capture ffmpeg startup error report')
      ..writeln('Generated at: ${now.toIso8601String()}')
      ..writeln('App version: ${config.version}')
      ..writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('Language: ${config.languageCode}')
      ..writeln()
      ..writeln('Capture configuration')
      ..writeln('- ffmpeg: ${config.ffmpegPath ?? 'not set'}')
      ..writeln('- outputDir: ${config.outputDir ?? 'not set'}')
      ..writeln('- sourceKind: ${config.sourceKind?.name ?? 'not set'}')
      ..writeln('- codec: ${config.codec ?? 'not set'}')
      ..writeln('- videoBitrate: ${config.videoBitrate}')
      ..writeln('- audioBitrate: ${config.audioBitrate}')
      ..writeln('- ffmpegPreset: ${config.ffmpegPreset}')
      ..writeln('- fps: ${config.fps}')
      ..writeln('- segmentSeconds: ${config.segmentSeconds}')
      ..writeln('- bufferMinutes: ${config.bufferMinutes}')
      ..writeln('- preRollSeconds: ${config.preRollSeconds}')
      ..writeln('- recordingStartTrimMillis: ${config.recordingStartTrimMillis}')
      ..writeln('- videoDevice: ${video == null ? 'not set' : '${video.name} [${video.id}]'}')
      ..writeln(
        '- audioDevice: ${audio == null ? 'not set' : '${audio.audioName ?? audio.name} [${audio.audioId ?? audio.id}]'}',
      )
      ..writeln()
      ..writeln('ffmpeg startup failure')
      ..writeln('- message: ${error.message}')
      ..writeln('- exitCode: ${error.exitCode ?? 'unknown'}')
      ..writeln('- command: ${error.command}')
      ..writeln('- arguments: ${error.arguments.join(' ')}')
      ..writeln()
      ..writeln('ffmpeg output')
      ..writeln(error.output.trim().isEmpty ? 'No ffmpeg output captured.' : error.output.trim())
      ..writeln()
      ..writeln('Recent application log')
      ..writeln(recentLogs.isEmpty ? 'No application log entries available.' : recentLogs);

    return FfmpegIssue(
      id: now.microsecondsSinceEpoch.toString(),
      summary: summaryBuffer.toString(),
      report: report.toString(),
      occurredAt: now,
    );
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
