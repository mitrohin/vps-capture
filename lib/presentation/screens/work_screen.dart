import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HardwareKeyboard, KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../domain/models/ffmpeg_issue.dart';
import '../../localization/app_localizations.dart';
import '../../domain/models/schedule_item.dart';
import '../../state/app_controller.dart';
import '../../state/app_state.dart';
import '../widgets/gif_title_settings_dialog.dart';
import '../widgets/gif_titres.dart';
import '../widgets/judge_server_status.dart';
import '../widgets/schedule_list.dart';

@visibleForTesting
int? normalizeDropdownValue(int? selectedValue, Iterable<int> availableValues) {
  if (selectedValue == null) {
    return null;
  }

  return availableValues.contains(selectedValue) ? selectedValue : null;
}

bool _isReadyForCurrentFlow(ScheduleItem item) =>
    item.status == ScheduleItemStatus.pending ||
    item.status == ScheduleItemStatus.postponed ||
    item.status == ScheduleItemStatus.active;

@visibleForTesting
int countReadyItemsForThread(
  List<ScheduleItem> items, {
  required int? threadIndex,
  required int? typeIndex,
}) {
  return items.where((item) {
    final threadMatches = threadIndex == null || item.threadIndex == threadIndex;
    final typeMatches = typeIndex == null || item.typeIndex == typeIndex;
    return threadMatches && typeMatches && _isReadyForCurrentFlow(item);
  }).length;
}

@visibleForTesting
int? findNextThreadWithReadyItems(
  List<ScheduleItem> items,
  List<int> threadOrder, {
  required int currentThread,
  required int? typeIndex,
}) {
  final currentIndex = threadOrder.indexOf(currentThread);
  if (currentIndex == -1) {
    return null;
  }

  for (var index = currentIndex + 1; index < threadOrder.length; index++) {
    final candidate = threadOrder[index];
    if (countReadyItemsForThread(items, threadIndex: candidate, typeIndex: typeIndex) > 0) {
      return candidate;
    }
  }

  return null;
}

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  late final TextEditingController _scheduleInputController;
  int? _selectedThreadFilter;
  int? _selectedTypeFilter;
  int delayTime = 3;
  final GlobalKey<GifTitresState> _gifTitresKey = GlobalKey<GifTitresState>();
  final TextEditingController _timeController = TextEditingController();
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'participants_list_focus');
  bool _ctrlAltPostponeTriggered = false;
  bool _isFfmpegDialogVisible = false;

  void _updateSelectedIndexAfterFilterChange() {
    final state = ref.read(appControllerProvider);
    _selectPrioritizedItem(state.schedule);
  }

  void _selectPrioritizedItem(List<ScheduleItem> schedule) {
    final filteredItems = _getFilteredItems(schedule);
    if (filteredItems.isEmpty) {
      return;
    }

    final prioritizedItem = filteredItems.firstWhere(
      (item) => item.status == ScheduleItemStatus.pending,
      orElse: () => filteredItems.firstWhere(
        (item) => item.status == ScheduleItemStatus.postponed,
        orElse: () => filteredItems.first,
      ),
    );
    final globalIndex = schedule.indexWhere((item) => item.id == prioritizedItem.id);
    if (globalIndex != -1) {
      ref.read(appControllerProvider.notifier).selectIndex(globalIndex);
    }
  }

  void _maybeAdvanceThreadFilter(AppState? previous, AppState next) {
    if (!mounted) {
      return;
    }

    final currentThreadFilter = _effectiveThreadFilter(next.schedule);
    if (currentThreadFilter == null) {
      return;
    }

    final currentTypeFilter = _effectiveTypeFilter(next.schedule, currentThreadFilter);
    final previousSchedule = previous?.schedule ?? const <ScheduleItem>[];
    final previousReadyCount = countReadyItemsForThread(
      previousSchedule,
      threadIndex: currentThreadFilter,
      typeIndex: currentTypeFilter,
    );
    final nextReadyCount = countReadyItemsForThread(
      next.schedule,
      threadIndex: currentThreadFilter,
      typeIndex: currentTypeFilter,
    );

    if (previousReadyCount <= 0 || nextReadyCount > 0) {
      return;
    }

    final nextThreadFilter = findNextThreadWithReadyItems(
      next.schedule,
      _getAvailableThreads(next.schedule),
      currentThread: currentThreadFilter,
      typeIndex: currentTypeFilter,
    );
    if (nextThreadFilter == null || nextThreadFilter == currentThreadFilter) {
      return;
    }

    setState(() {
      _selectedThreadFilter = nextThreadFilter;
      _selectedTypeFilter = _effectiveTypeFilter(next.schedule, nextThreadFilter);
    });
    _selectPrioritizedItem(next.schedule);
  }
  
  void _handleStartWithGif(int globalIndex) {
    final controller = ref.read(appControllerProvider.notifier);
    final state = ref.read(appControllerProvider);
    
    unawaited(controller.startMark(globalIndex));
    
    final item = state.schedule[globalIndex];
    if (_gifTitresKey.currentState != null) {
      _gifTitresKey.currentState!.scheduleGifDisplay(
        fio: item.fio,
        city: item.city,
        gifKey: _gifTitresKey.currentState!.currentSelectedGif,
        customDelay: _gifTitresKey.currentState!.currentDelay,
      );
    }
  }

  List<int> _getAvailableThreads(List<ScheduleItem> items) {
    final threads = items.where((item) => item.threadIndex != null)
        .map((item) => item.threadIndex!)
        .toSet()
        .toList()
      ..sort();
    return threads;
  }
  
  List<int> _getAvailableTypes(List<ScheduleItem> items, int? threadIndex) {
    if (threadIndex == null) {
      final types = items.where((item) => item.typeIndex != null)
          .map((item) => item.typeIndex!)
          .toSet()
          .toList()
        ..sort();
      return types;
    } else {
      final types = items.where((item) => 
          item.threadIndex == threadIndex && item.typeIndex != null)
          .map((item) => item.typeIndex!)
          .toSet()
          .toList()
        ..sort();
      return types;
    }
  }

  int? _effectiveThreadFilter(List<ScheduleItem> items) {
    return normalizeDropdownValue(_selectedThreadFilter, _getAvailableThreads(items));
  }

  int? _effectiveTypeFilter(List<ScheduleItem> items, int? threadIndex) {
    return normalizeDropdownValue(_selectedTypeFilter, _getAvailableTypes(items, threadIndex));
  }

  List<ScheduleItem> _getFilteredItems(List<ScheduleItem> items) {
    final effectiveThreadFilter = _effectiveThreadFilter(items);
    final effectiveTypeFilter = _effectiveTypeFilter(items, effectiveThreadFilter);
    final filteredItems = <ScheduleItem>[];

    for (var item in items) {
      final threadMatch = effectiveThreadFilter == null ||
          item.threadIndex == effectiveThreadFilter;
      final typeMatch = effectiveTypeFilter == null ||
          item.typeIndex == effectiveTypeFilter;
      if (!threadMatch || !typeMatch) continue;
      filteredItems.add(item);
    }
    return filteredItems;
  }

  int getGlobalIndex(int filteredIndex) {
    final state = ref.read(appControllerProvider);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredIndex < 0 || filteredIndex >= filteredItems.length) return -1;
    
    final item = filteredItems[filteredIndex];
    return state.schedule.indexWhere((scheduleItem) => 
        scheduleItem.id == item.id);
  }

  int? _nextVisibleThread(List<int> threadOrder, int currentThread) {
    final currentIndex = threadOrder.indexOf(currentThread);
    if (currentIndex == -1 || currentIndex + 1 >= threadOrder.length) {
      return null;
    }
    return threadOrder[currentIndex + 1];
  }
  List<ScheduleListEntry> _buildThreadEntries(
    List<ScheduleItem> items,
    int? threadIndex,
    int? typeIndex,
  ) {
    if (threadIndex == null && items.isEmpty) {
      return const [];
    }

    final entries = <ScheduleListEntry>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final typeMatches = typeIndex == null || item.typeIndex == typeIndex;
      if (item.threadIndex == threadIndex && typeMatches && !item.isPinnedToPostponed) {
        entries.add(ScheduleListEntry(item: item, globalIndex: index));
      }
    }
    return entries;
  }



  List<ScheduleListEntry> _buildEntriesFromItems(
    List<ScheduleItem> items,
    bool Function(ScheduleItem item) predicate,
  ) {
    final entries = <ScheduleListEntry>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (!predicate(item)) {
        continue;
      }
      entries.add(ScheduleListEntry(item: item, globalIndex: index));
    }
    return entries;
  }

  Widget _controlButton({
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDanger
              ? const Color(0xFF8B0000)
              : isPrimary
                  ? const Color(0xFF006400)
                  : const Color(0xFF2E2F33),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleInputController = TextEditingController();
    _timeController.text = '2';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Platform.isWindows) {
        _listFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scheduleInputController.dispose();
    _timeController.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }



  void _moveSelectionUp() {
    final state = ref.read(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredItems.isEmpty) return;

    final selectedFilteredIndex = state.selectedIndex != null
        ? filteredItems.indexWhere((item) => item.id == state.schedule[state.selectedIndex!].id)
        : -1;

    final targetFilteredIndex = selectedFilteredIndex <= 0
        ? 0
        : selectedFilteredIndex - 1;
    final globalIndex = getGlobalIndex(targetFilteredIndex);
    if (globalIndex != -1) {
      controller.selectIndex(globalIndex);
    }
  }

  void _moveSelectionDown() {
    final state = ref.read(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredItems.isEmpty) return;

    final selectedFilteredIndex = state.selectedIndex != null
        ? filteredItems.indexWhere((item) => item.id == state.schedule[state.selectedIndex!].id)
        : -1;

    final targetFilteredIndex = selectedFilteredIndex < 0
        ? 0
        : (selectedFilteredIndex + 1).clamp(0, filteredItems.length - 1);
    final globalIndex = getGlobalIndex(targetFilteredIndex);
    if (globalIndex != -1) {
      controller.selectIndex(globalIndex);
    }
  }

  Future<void> _showAddParticipantDialog(String lang) async {
    var fio = '';
    var city = '';
    var apparatus = '';

    final result = await showDialog<({String fio, String city, String apparatus})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.tr(lang, 'addParticipant')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => fio = value,
              decoration: InputDecoration(
                labelText: AppLocalizations.tr(lang, 'participantNameLabel'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => city = value,
              decoration: InputDecoration(
                labelText: AppLocalizations.tr(lang, 'participantCityLabel'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => apparatus = value,
              decoration: InputDecoration(
                labelText: AppLocalizations.tr(lang, 'participantApparatusLabel'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.tr(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                (
                  fio: fio,
                  city: city,
                  apparatus: apparatus,
                ),
              );
            },
            child: Text(AppLocalizations.tr(lang, 'add')),
          ),
        ],
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    ref.read(appControllerProvider.notifier).addParticipant(
          fio: result.fio,
          city: result.city,
          apparatus: result.apparatus,
          threadIndex: _selectedThreadFilter,
          typeIndex: _selectedTypeFilter,
        );
  }

  Future<void> _showLoadScheduleDialog(String lang) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.tr(lang, 'loadSchedule'),
          textAlign: TextAlign.center,
          ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.text_fields_rounded,
              color: Color.fromARGB(255, 149, 198, 143),
              size: 24.0,
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop('paste'),
                child: Text(
                  AppLocalizations.tr(lang, 'pasteFromClipboard'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  ),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.file_open_outlined,
              color: Color.fromARGB(255, 149, 198, 143),
              size: 24.0,
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop('file'),
                child: Text(
                  AppLocalizations.tr(lang, 'loadFromFile'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.tr(lang, 'cancel')),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    if (result == 'paste') {
      await _showPasteScheduleDialog(lang);
    } else if (result == 'file') {
      await ref.read(appControllerProvider.notifier).loadSchedule();
    }
  }

  Future<void> _showPasteScheduleDialog(String lang) async {
    final scheduleDataController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.tr(lang, 'pasteScheduleData'),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: scheduleDataController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.tr(lang, 'scheduleData'),
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.tr(lang, 'pasteScheduleHint'),
                ),
                maxLines: 20,
                minLines: 10,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.tr(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.tr(lang, 'load')),
          ),
        ],
      ),
    );

    if (!mounted || result != true) return;

    final scheduleData = scheduleDataController.text.trim();
    if (scheduleData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.tr(lang, 'emptyScheduleData'))),
      );
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    controller.applySchedule(scheduleData, source: 'ui');
  }


  Future<void> _showGifTitleSettingsDialog(String lang, String initialGifKey) async {
    await showDialog<void>(
      context: context,
      builder: (context) => GifTitleSettingsDialog(
        languageCode: lang,
        initialGifKey: initialGifKey,
        onRunTest: (gifKey) async {
          final controller = ref.read(appControllerProvider.notifier);
          if (ref.read(appControllerProvider).config.selectedGif != gifKey) {
            await controller.setSelectedGif(gifKey);
          }
          if (!mounted) {
            return;
          }
          _gifTitresKey.currentState?.runTestTitle();
        },
      ),
    );
  }

  Future<void> _showFfmpegIssueDialog(FfmpegIssue issue, String lang) async {
    _isFfmpegDialogVisible = true;
    final controller = ref.read(appControllerProvider.notifier);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.tr(lang, 'ffmpegErrorTitle')),
        content: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.tr(lang, 'ffmpegErrorMessage')),
              const SizedBox(height: 12),
              Text(
                issue.summary,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 320,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(issue.report),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issue.report));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.tr(lang, 'ffmpegErrorCopied'))),
              );
            },
            child: Text(AppLocalizations.tr(lang, 'copyError')),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final savedPath = await controller.saveFfmpegIssueReport();
              if (!mounted || savedPath == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${AppLocalizations.tr(lang, 'ffmpegErrorSaved')}: $savedPath')),
              );
            },
            child: Text(AppLocalizations.tr(lang, 'saveError')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.tr(lang, 'close')),
          ),
        ],
      ),
    );

    controller.dismissFfmpegIssue();
    _isFfmpegDialogVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final lang = state.config.languageCode;

    ref.listen<AppState>(appControllerProvider, (previous, next) {
      _maybeAdvanceThreadFilter(previous, next);

      final previousId = previous?.ffmpegIssue?.id;
      final nextIssue = next.ffmpegIssue;
      if (!mounted || nextIssue == null || _isFfmpegDialogVisible || previousId == nextIssue.id) {
        return;
      }

      unawaited(_showFfmpegIssueDialog(nextIssue, next.config.languageCode));
    });

    final availableThreads = _getAvailableThreads(state.schedule);
    final effectiveThreadFilter = _effectiveThreadFilter(state.schedule);
    final availableTypes = _getAvailableTypes(state.schedule, effectiveThreadFilter);
    final effectiveTypeFilter = _effectiveTypeFilter(state.schedule, effectiveThreadFilter);
    final filteredItems = _getFilteredItems(state.schedule);
    final selectedGlobalIndex = (state.selectedIndex != null &&
            state.selectedIndex! >= 0 &&
            state.selectedIndex! < state.schedule.length)
        ? state.selectedIndex
        : null;
    final selectedItem = (selectedGlobalIndex != null &&
            selectedGlobalIndex >= 0 &&
            selectedGlobalIndex < state.schedule.length)
        ? state.schedule[selectedGlobalIndex]
        : null;
    final threadOrder = availableThreads;
    final currentThread = effectiveThreadFilter ??
        (threadOrder.isNotEmpty ? threadOrder.first : null);
    final nextThread = currentThread == null ? null : _nextVisibleThread(threadOrder, currentThread);
    final currentThreadItems = _buildThreadEntries(
      state.schedule,
      currentThread,
      effectiveTypeFilter,
    );
    final nextThreadItems = _buildThreadEntries(
      state.schedule,
      nextThread,
      effectiveTypeFilter,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final nextThreadFilter = threadOrder.isNotEmpty && effectiveThreadFilter == null
          ? threadOrder.first
          : effectiveThreadFilter;
      final nextTypeFilter = _effectiveTypeFilter(state.schedule, nextThreadFilter);
      if (_selectedThreadFilter == nextThreadFilter &&
          _selectedTypeFilter == nextTypeFilter) {
        return;
      }

      setState(() {
        _selectedThreadFilter = nextThreadFilter;
        _selectedTypeFilter = nextTypeFilter;
      });
    });

    return Focus(
          autofocus: true,
          focusNode: _listFocusNode,
          onKeyEvent: (_, event) {
            final isModifierRelease = event is KeyUpEvent &&
                (event.logicalKey == LogicalKeyboardKey.altLeft ||
                    event.logicalKey == LogicalKeyboardKey.controlLeft ||
                    event.logicalKey == LogicalKeyboardKey.controlRight);
            if (isModifierRelease) {
              _ctrlAltPostponeTriggered = false;
            }

            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _moveSelectionUp();
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _moveSelectionDown();
              return KeyEventResult.handled;
            }

            final keyboard = HardwareKeyboard.instance;
            final isCtrlAltChord = keyboard.isControlPressed &&
                keyboard.isLogicalKeyPressed(LogicalKeyboardKey.altLeft);
            final modifierPressed = keyboard.isControlPressed ||
                keyboard.isAltPressed ||
                keyboard.isMetaPressed ||
                keyboard.isShiftPressed;

            if (isCtrlAltChord &&
                !_ctrlAltPostponeTriggered &&
                (event.logicalKey == LogicalKeyboardKey.altLeft ||
                    event.logicalKey == LogicalKeyboardKey.controlLeft ||
                    event.logicalKey == LogicalKeyboardKey.controlRight)) {
              _ctrlAltPostponeTriggered = true;
              unawaited(controller.postpone());
              return KeyEventResult.handled;
            }

            if (!isCtrlAltChord) {
              _ctrlAltPostponeTriggered = false;
            }

            if (event.logicalKey == LogicalKeyboardKey.space && !modifierPressed) {
              if (state.isRecordingMarked) {
                controller.stopMark();
              } else {
                final currentSelectedIndex = state.selectedIndex;
                if (currentSelectedIndex != null) {
                  _handleStartWithGif(currentSelectedIndex);
                } else {
                  final filtered = _getFilteredItems(state.schedule);
                  if (filtered.isNotEmpty) {
                    final globalIndex = getGlobalIndex(0);
                    if (globalIndex != -1) {
                      _handleStartWithGif(globalIndex);
                    }
                  }
                }
              }
              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 6,
                      children: [
                        Text(AppLocalizations.tr(lang, 'workTitle')),
                        Text(
                          AppLocalizations.tr(lang, 'setupVersion'),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        Text(
                          state.config.version,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        JudgeServerStatusIndicator(
                          languageCode: lang,
                          status: state.judgeWebServerStatus,
                          isSetupMode: false,
                          showDetails: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: AppLocalizations.tr(lang, 'language'),
                  onSelected: controller.setLanguage,
                  itemBuilder: (context) => AppLocalizations.supportedLanguages
                      .map((code) => PopupMenuItem<String>(value: code, child: Text(code.toUpperCase())))
                      .toList(),
                  icon: const Icon(Icons.language),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'loadSchedule'),
                  onPressed: () => _showLoadScheduleDialog(lang),
                  icon: const Icon(Icons.upload_file),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'addParticipant'),
                  onPressed: () => _showAddParticipantDialog(lang),
                  icon: const Icon(Icons.person_add),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'gifTitleOpenSettings'),
                  onPressed: () => _showGifTitleSettingsDialog(lang, state.config.selectedGif ?? 'blue'),
                  icon: const Icon(Icons.subtitles_outlined),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'backToSetup'),
                  onPressed: controller.backToSetup,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 160,
                                child: Column(
                                  children: [
                                    _controlButton(
                                      label: state.isRecordingMarked
                                          ? AppLocalizations.tr(lang, 'startStopButtonStop')
                                          : AppLocalizations.tr(lang, 'startStopButtonStart'),
                                      onPressed: selectedGlobalIndex == null && !state.isRecordingMarked
                                          ? null
                                          : () {
                                              if (state.isRecordingMarked) {
                                                controller.stopMark();
                                              } else {
                                                _handleStartWithGif(selectedGlobalIndex!);
                                              }
                                            },
                                      isPrimary: true,
                                      isDanger: state.isRecordingMarked,
                                    ),
                                    const SizedBox(height: 8),
                                    _controlButton(
                                      label: AppLocalizations.tr(lang, 'postponeEntry'),
                                      onPressed: (selectedGlobalIndex != null &&
                                              selectedItem != null &&
                                              selectedItem.status != ScheduleItemStatus.postponed)
                                          ? () => controller.postpone(selectedGlobalIndex)
                                          : null,
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: 160,
                                      child: TextFormField(
                                        controller: _timeController,
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.tr(lang, 'labelTimerGifs'),
                                          border: const OutlineInputBorder(),
                                          hintText: AppLocalizations.tr(lang, 'hintTimerGifs'),
                                          suffixText: AppLocalizations.tr(lang, 'suffixTimerGifs'),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            delayTime = int.tryParse(value) ?? 3;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 160,
                                      child: DropdownButtonFormField<String>(
                                        value: state.config.selectedGif,
                                        dropdownColor: const Color(0xFF1C1C1E),
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.tr(lang, 'labelDropDownTitres'),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'blue', child: Text('blue')),
                                          DropdownMenuItem(value: 'red', child: Text('red')),
                                          DropdownMenuItem(value: 'fitness', child: Text('fitness')),
                                          DropdownMenuItem(value: 'lenta', child: Text('lenta')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            controller.setSelectedGif(value);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 160,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => _showGifTitleSettingsDialog(lang, state.config.selectedGif ?? 'blue'),
                                        icon: const Icon(Icons.tune),
                                        label: Text(AppLocalizations.tr(lang, 'gifTitleOpenSettings')),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 160,
                                      child: DropdownButtonFormField<int>(
                                        value: effectiveThreadFilter,
                                        dropdownColor: const Color(0xFF1C1C1E),
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.tr(lang, 'labelDropDownThread'),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: availableThreads
                                            .map((thread) => DropdownMenuItem(
                                                  value: thread,
                                                  child: Row(children: [Text(AppLocalizations.tr(lang, 'labelDropDownThreadList')), const SizedBox(width: 5,),Text('$thread ')],),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedThreadFilter = value;
                                            _selectedTypeFilter = _effectiveTypeFilter(state.schedule, value);
                                          });
                                          _updateSelectedIndexAfterFilterChange();
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 160,
                                      child: DropdownButtonFormField<int?>(
                                        value: effectiveTypeFilter,
                                        dropdownColor: const Color(0xFF1C1C1E),
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.tr(lang, 'labelDropDownRoutines'),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: [
                                          DropdownMenuItem(value: null, child: Text(AppLocalizations.tr(lang, 'allTypes'))),
                                          ...availableTypes.map((type) => DropdownMenuItem(value: type, child: Text('$type'))),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedTypeFilter = value;
                                          });
                                          _updateSelectedIndexAfterFilterChange();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ScheduleList(
                                  currentThreadItems: currentThreadItems,
                                  nextThreadItems: nextThreadItems,
                                  postponedItems: _buildEntriesFromItems(
                                    state.schedule,
                                    (item) => item.isPinnedToPostponed,
                                  ),
                                  selectedIndex: selectedGlobalIndex,
                                  onSelect: (globalIndex) {
                                    if (globalIndex >= 0 && globalIndex < state.schedule.length) {
                                      controller.selectIndex(globalIndex);
                                    }
                                  },
                                  onDelete: (globalIndex) {
                                    if (globalIndex >= 0 && globalIndex < state.schedule.length) {
                                      controller.deleteItem(globalIndex);
                                    }
                                  },
                                  isRecordingMarked: state.isRecordingMarked,
                                  languageCode: lang,
                                  currentThreadTitle: AppLocalizations.tr(lang, 'currentThread'),
                                  nextThreadTitle: AppLocalizations.tr(lang, 'nextThread'),
                                  postponedTitle: AppLocalizations.tr(lang, 'postponedParticipants'),
                                  nextThreadEmptyLabel: nextThread == null ? AppLocalizations.tr(lang, 'endThread') : null,
                                  middleControls: SizedBox(
                                    width: 160,
                                    child: Column(
                                      children: [
                                        _controlButton(
                                          label: state.isRecordingMarked
                                              ? AppLocalizations.tr(lang, 'startStopButtonStop')
                                              : AppLocalizations.tr(lang, 'startStopButtonStart'),
                                          onPressed: selectedGlobalIndex == null && !state.isRecordingMarked
                                              ? null
                                              : () {
                                                  if (state.isRecordingMarked) {
                                                    controller.stopMark();
                                                  } else {
                                                    _handleStartWithGif(selectedGlobalIndex!);
                                                  }
                                                },
                                          isPrimary: true,
                                          isDanger: state.isRecordingMarked,
                                        ),
                                        const SizedBox(height: 8),
                                        _controlButton(
                                          label: AppLocalizations.tr(lang, 'restoreEntry'),
                                          onPressed: (selectedGlobalIndex != null &&
                                                  selectedItem != null &&
                                                  selectedItem.isPinnedToPostponed)
                                              ? () => controller.restoreItem(selectedGlobalIndex)
                                              : null,
                                        ),
                                        const SizedBox(height: 8),
                                        _controlButton(
                                          label: AppLocalizations.tr(lang, 'clearPostponed'),
                                          onPressed: () => controller.restoreAllPostponed(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GifTitres(key: _gifTitresKey, lang: lang, delayTime: delayTime, selectedGif: state.config.selectedGif!,),
              ],
            ),
          ),
        );
  }
}
