import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../localization/app_localizations.dart';
import '../../domain/models/schedule_item.dart';
import '../../state/app_controller.dart';
import '../widgets/gif_titres.dart';
import '../widgets/schedule_list.dart';

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

  void _updateSelectedIndexAfterFilterChange() {
    final state = ref.read(appControllerProvider);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredItems.isNotEmpty) {
      final globalIndex = state.schedule.indexWhere((item) => item.id == filteredItems.first.id);
      if (globalIndex != -1) {
        ref.read(appControllerProvider.notifier).selectIndex(globalIndex);
      }
    }
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

  List<ScheduleItem> _getFilteredItems(List<ScheduleItem> items) {
    final filteredItems = <ScheduleItem>[];
    
    for (var item in items) {
      final typeMatch = _selectedTypeFilter == null ||
          item.typeIndex == _selectedTypeFilter;
      if (!typeMatch) continue;
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

  List<int?> _getVisibleThreadOrder(List<ScheduleItem> items) {
    final threads = items
        .where((item) => item.threadIndex != null)
        .map((item) => item.threadIndex)
        .toSet()
        .toList();
    threads.sort((a, b) => (a ?? 0).compareTo(b ?? 0));
    return threads;
  }

  bool _isThreadCompleted(List<ScheduleItem> items, int threadIndex) {
    final threadItems = items.where((item) => item.threadIndex == threadIndex).toList();
    if (threadItems.isEmpty) return false;
    return threadItems.every(
      (item) =>
          item.status == ScheduleItemStatus.done ||
          item.status == ScheduleItemStatus.postponed,
    );
  }

  int? _nextThreadByNumber(List<int> threadOrder, int currentThread) {
    final nextThread = currentThread + 1;
    return threadOrder.contains(nextThread) ? nextThread : null;
  }

  int? _resolveCurrentThread(List<ScheduleItem> filteredItems) {
    final threadOrder = _getVisibleThreadOrder(filteredItems).whereType<int>().toList();
    if (threadOrder.isEmpty) return null;

    final selectedThread = _selectedThreadFilter;
    if (selectedThread != null && threadOrder.contains(selectedThread)) {
      return selectedThread;
    }

    for (final thread in threadOrder) {
      if (!_isThreadCompleted(filteredItems, thread)) {
        return thread;
      }
    }

    return threadOrder.first;
  }

  List<ScheduleListEntry> _buildThreadEntries(
    List<ScheduleItem> items,
    int? threadIndex,
  ) {
    if (threadIndex == null && items.isEmpty) {
      return const [];
    }

    final entries = <ScheduleListEntry>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item.threadIndex == threadIndex) {
        entries.add(ScheduleListEntry(item: item, filteredIndex: index));
      }
    }
    return entries;
  }



  List<ScheduleListEntry> _buildEntriesFromItems(List<ScheduleItem> items) {
    final entries = <ScheduleListEntry>[];
    for (var index = 0; index < items.length; index++) {
      entries.add(ScheduleListEntry(item: items[index], filteredIndex: index));
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final lang = state.config.languageCode;

    final filteredItems = _getFilteredItems(state.schedule);
    final availableThreads = _getAvailableThreads(state.schedule);
    final currentThread = _resolveCurrentThread(filteredItems);
    final availableTypes = _getAvailableTypes(state.schedule, currentThread);
    final selectedFilteredIndex = (state.selectedIndex != null &&
            state.selectedIndex! >= 0 &&
            state.selectedIndex! < state.schedule.length)
        ? filteredItems.indexWhere((item) => item.id == state.schedule[state.selectedIndex!].id)
        : null;
    final selectedGlobalIndex = (selectedFilteredIndex != null && selectedFilteredIndex >= 0)
        ? getGlobalIndex(selectedFilteredIndex)
        : null;
    final selectedItem = (selectedGlobalIndex != null &&
            selectedGlobalIndex >= 0 &&
            selectedGlobalIndex < state.schedule.length)
        ? state.schedule[selectedGlobalIndex]
        : null;
    final threadOrder = _getVisibleThreadOrder(filteredItems).whereType<int>().toList(growable: false);
    final nextThread = currentThread == null ? null : _nextThreadByNumber(threadOrder, currentThread);
    final currentThreadItems = _buildThreadEntries(filteredItems, currentThread);
    final nextThreadItems = _buildThreadEntries(filteredItems, nextThread);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || currentThread == null) return;
      if (_selectedThreadFilter != null && threadOrder.contains(_selectedThreadFilter)) return;
      setState(() {
        _selectedThreadFilter = currentThread;
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
                  Text(AppLocalizations.tr(lang, 'workTitle')),
                  const SizedBox(width: 5),
                  Text(AppLocalizations.tr(lang, 'setupVersion'), 
                    style:
                    TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13)
                    ),
                  Text(state.config.version,
                    style:
                    TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13))
                ]
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
                  onPressed: controller.loadSchedule,
                  icon: const Icon(Icons.upload_file),
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
                        Row(
                          children: [
                            SizedBox(
                              width: 140,
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
                            const SizedBox(width: 8),
                            Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: state.config.selectedGif,
                                  dropdownColor: const Color(0xFF1C1C1E),
                                  style: const TextStyle(color: Colors.white),
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
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<int>(
                                value: _selectedThreadFilter,
                                dropdownColor: const Color(0xFF1C1C1E),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Поток',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: availableThreads
                                    .map((thread) => DropdownMenuItem(
                                          value: thread,
                                          child: Text('ПОТОК ${thread + 1}'),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedThreadFilter = value;
                                  });
                                  _updateSelectedIndexAfterFilterChange();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<int?>(
                                value: _selectedTypeFilter,
                                dropdownColor: const Color(0xFF1C1C1E),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Вид',
                                  border: OutlineInputBorder(),
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
                        const SizedBox(height: 10),
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
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ScheduleList(
                                  currentThreadItems: currentThreadItems,
                                  nextThreadItems: nextThreadItems,
                                  postponedItems: _buildEntriesFromItems(
                                    filteredItems.where((item) => item.status == ScheduleItemStatus.postponed).toList(),
                                  ),
                                  selectedIndex: selectedFilteredIndex,
                                  onSelect: (filteredIndex) {
                                    final globalIndex = getGlobalIndex(filteredIndex);
                                    if (globalIndex != -1) {
                                      controller.selectIndex(globalIndex);
                                    }
                                  },
                                  onDelete: (filteredIndex) {
                                    final globalIndex = getGlobalIndex(filteredIndex);
                                    if (globalIndex != -1) {
                                      controller.deleteItem(globalIndex);
                                    }
                                  },
                                  isRecordingMarked: state.isRecordingMarked,
                                  languageCode: lang,
                                  currentThreadTitle: 'ТЕКУЩИЙ ПОТОК',
                                  nextThreadTitle: 'СЛЕДУЮЩИЙ ПОТОК',
                                  postponedTitle: 'ОТЛОЖЕННЫЕ',
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
                                                  selectedItem.status == ScheduleItemStatus.postponed)
                                              ? () => controller.restoreItem(selectedGlobalIndex)
                                              : null,
                                        ),
                                        const SizedBox(height: 8),
                                        _controlButton(
                                          label: 'ОЧИСТИТЬ',
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
