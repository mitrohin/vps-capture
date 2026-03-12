import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

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
import '../data/capture/test_record_service.dart';
import '../data/ffmpeg/device_scanner.dart';
import '../data/ffmpeg/ffmpeg_installer.dart';
import '../data/ffmpeg/ffmpeg_locator.dart';
import '../data/schedule/schedule_decoder.dart';
import '../data/schedule/schedule_parser.dart';
import '../data/storage/app_paths.dart';
import '../domain/models/app_config.dart';
import '../domain/models/capture_device.dart';
import '../domain/models/schedule_item.dart';
import 'app_state.dart';

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  final paths = AppPaths();
  final backend = CaptureBackend();
  final captureService = CaptureService(BufferRecorder(paths, backend), ClipExporter(paths));
  return AppController(
    FfmpegLocator(paths),
    FfmpegInstaller(paths, Dio()),
    DeviceScanner(),
    ScheduleParser(),
    captureService,
    PreviewService(backend),
    TestRecordService(captureService, ClipExporter(paths)),
  )..initialize();
});

class AppController extends StateNotifier<AppState>  {
  AppController(
    this._locator,
    this._installer,
    this._scanner,
    this._parser,
    this._capture,
    this._preview,
    this._testRecorder,
  ) : super(const AppState());

  final FfmpegLocator _locator;
  final FfmpegInstaller _installer;
  final DeviceScanner _scanner;
  final ScheduleParser _parser;
  final ScheduleDecoder _scheduleDecoder = ScheduleDecoder();
  final CaptureService _capture;
  final PreviewService _preview;
  final TestRecordService _testRecorder;
  

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final hasCompletedFirstLaunch = _prefs!.getBool('hasCompletedFirstLaunch') ?? false;

    if (!hasCompletedFirstLaunch) {
      await _prefs!.setBool('hasCompletedFirstLaunch', true);
    }

    final located = await _locator.locate();
    final codec = Platform.isMacOS ? 'h264_videotoolbox' : 'libx264';
    final cfg = AppConfig(
      ffmpegPath: _stringOrNull(_prefs!.getString('ffmpegPath')) ?? located.ffmpegPath,
      ffplayPath: _stringOrNull(_prefs!.getString('ffplayPath')) ?? located.ffplayPath,
      outputDir: _stringOrNull(_prefs!.getString('outputDir')),
      sourceKind: _readSource(_prefs!.getString('sourceKind')),
      selectedVideoDevice: _readDevice(_prefs!.getString('selectedVideoDevice')),
      selectedAudioDevice: _readDevice(_prefs!.getString('selectedAudioDevice')),
      codec: _stringOrNull(_prefs!.getString('codec')) ?? codec,
      videoBitrate: _prefs!.getString('videoBitrate') ?? '8M',
      audioBitrate: _prefs!.getString('audioBitrate') ?? '128k',
      ffmpegPreset: _prefs!.getString('ffmpegPreset') ?? 'veryfast',
      movFlags: _prefs!.getString('movFlags') ?? '+faststart',
      fps: _prefs!.getInt('fps') ?? 30,
      segmentSeconds: _prefs!.getInt('segmentSeconds') ?? 1,
      bufferMinutes: _prefs!.getInt('bufferMinutes') ?? 8,
      preRollSeconds: _prefs!.getInt('preRollSeconds') ?? 2,
      languageCode: _stringOrNull(_prefs!.getString('languageCode')) ?? 'en',
      selectedGif: _prefs!.getString('selectedGif') ?? 'blue',
      version: _prefs!.getString('version') ?? '1.0.0'
    );
    state = state.copyWith(config: cfg);
    await loadScheduleFromFile();
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
          clearAudioDevice: selectedAudio == null
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
    await prefs.setString('selectedVideoDevice', config.selectedVideoDevice == null ? '' : jsonEncode(config.selectedVideoDevice!.toJson()));
    await prefs.setString('selectedAudioDevice', config.selectedAudioDevice == null ? '' : jsonEncode(config.selectedAudioDevice!.toJson()));
    await prefs.setString('codec', config.codec ?? '');
    await prefs.setString('videoBitrate', config.videoBitrate);
    await prefs.setString('audioBitrate', config.audioBitrate);
    await prefs.setString('ffmpegPreset', config.ffmpegPreset);
    await prefs.setString('movFlags', config.movFlags);
    await prefs.setInt('fps', config.fps);
    await prefs.setInt('segmentSeconds', config.segmentSeconds);
    await prefs.setInt('bufferMinutes', config.bufferMinutes);
    await prefs.setInt('preRollSeconds', config.preRollSeconds);
    await prefs.setString('languageCode', config.languageCode);
    await prefs.setString('selectedGif', config.selectedGif ?? 'blue');
    await prefs.setString('version', config.version);
  }


  Future<void> setLanguage(String languageCode) async {
    await updateConfig(state.config.copyWith(languageCode: languageCode));
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
  }

  void setScheduleInputVisibility(bool isVisible) {
    state = state.copyWith(isScheduleInputVisible: isVisible);
  }

  void createStructOutputDir(String content, String mainOutputDir, List scheduleList) {
    try{
        final lines = content.split(RegExp(r'\r?\n'));
        int currentThreadIndex = 0;
        int currentTypeCount = 1;

        for (var i = 0; i < lines.length; i++){
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          if (line.startsWith('/*')) {
            currentThreadIndex++;
            final threadPath = p.join(mainOutputDir,'0$currentThreadIndex - ${line.substring(line.indexOf(' ')+1).replaceAll(':', '-')}');
            final dirThread = Directory(threadPath);
            if (!dirThread.existsSync()) {
              dirThread.createSync(recursive: true);
            }
            try { 
              final splittedTypeCount = line.split(' ')[0];
              currentTypeCount = int.parse(splittedTypeCount.substring(2));
            }
            catch (e) {
              currentTypeCount = 1;
            }
            if (currentTypeCount > 0) {
              for (int type = 0; type < currentTypeCount; type++) {
                final typePath = p.join(threadPath, '0${type+1}');
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
          return ScheduleItem(
            id: item['id'],
            fio: item['fio'],
            apparatus: item['apparatus'],
            city: item['city'],
            status: _parseStatus(item['status']),
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
  }

  Future<void> backToSetup() async {
    await _capture.stopBuffer();
    await _preview.stop();
    await _testRecorder.stop(state.config, _appendLog);
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
        _updateScheduleItemInFile(reset[activeIndex]);
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
      await _updateScheduleItemInFile(updated[targetIndex]);
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
        final nextIndex = _findNextReady(updated, activeIndex);
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
          selectedIndex: nextIndex,
        );
        await _updateScheduleItemInFile(updated[activeIndex]);
        _appendLog('STOP complete, clip saved: $out');
      } catch (_) {
        final updated = [...state.schedule];
        updated[activeIndex] = item.copyWith(status: ScheduleItemStatus.pending, clearStartedAt: true);
        state = state.copyWith(
          schedule: updated,
          isRecordingMarked: false,
          clearMarkStart: true,
        );
        await _updateScheduleItemInFile(updated[activeIndex]);
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
      );
      updated[targetIndex] = item;
      state = state.copyWith(schedule: updated, selectedIndex: targetIndex);
      await _updateScheduleItemInFile(item);
      _appendLog('Marked as POSTPONED: ${item.label}.');
    });
  }

  Future<void> restoreAllPostponed() async {
    final postponedIndexes = <int>[];
    final updated = [...state.schedule];
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].status == ScheduleItemStatus.postponed) {
        postponedIndexes.add(i);
        updated[i] = updated[i].copyWith(
          status: ScheduleItemStatus.pending,
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
  }

  void restoreItem(int index) {
    if (index < 0 || index >= state.schedule.length) return;
    final item = state.schedule[index];
    if (item.status != ScheduleItemStatus.done && item.status != ScheduleItemStatus.postponed) return;

    final updated = [...state.schedule];
    updated[index] = item.copyWith(status: ScheduleItemStatus.pending, clearStartedAt: true);
    state = state.copyWith(schedule: updated, selectedIndex: index);
    unawaited(_updateScheduleItemInFile(updated[index]));
    _appendLog('Restored item: ${item.label}.');
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
