import '../domain/models/app_config.dart';
import '../domain/models/capture_device.dart';
import '../domain/models/schedule_item.dart';

enum AppMode { setup, work }

class AppState {
  const AppState({
    this.mode = AppMode.setup,
    this.config = const AppConfig(),
    this.devices = const [],
    this.schedule = const [],
    this.selectedIndex,
    this.isLoading = false,
    this.isRecordingMarked = false,
    this.currentMarkStartedAt,
    this.logs = const [],
    this.isPreviewRunning = false,
  });

  final AppMode mode;
  final AppConfig config;
  final List<CaptureDevice> devices;
  final List<ScheduleItem> schedule;
  final int? selectedIndex;
  final bool isLoading;
  final bool isRecordingMarked;
  final DateTime? currentMarkStartedAt;
  final List<String> logs;
  final bool isPreviewRunning;

  ScheduleItem? get selectedItem {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= schedule.length) return null;
    return schedule[index];
  }

  AppState copyWith({
    AppMode? mode,
    AppConfig? config,
    List<CaptureDevice>? devices,
    List<ScheduleItem>? schedule,
    int? selectedIndex,
    bool clearSelectedIndex = false,
    bool? isLoading,
    bool? isRecordingMarked,
    DateTime? currentMarkStartedAt,
    bool clearMarkStart = false,
    List<String>? logs,
    bool? isPreviewRunning,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      config: config ?? this.config,
      devices: devices ?? this.devices,
      schedule: schedule ?? this.schedule,
      selectedIndex: clearSelectedIndex ? null : (selectedIndex ?? this.selectedIndex),
      isLoading: isLoading ?? this.isLoading,
      isRecordingMarked: isRecordingMarked ?? this.isRecordingMarked,
      currentMarkStartedAt: clearMarkStart ? null : (currentMarkStartedAt ?? this.currentMarkStartedAt),
      logs: logs ?? this.logs,
      isPreviewRunning: isPreviewRunning ?? this.isPreviewRunning,
    );
  }
}
