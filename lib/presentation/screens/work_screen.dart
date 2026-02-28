import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
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

  void _updateSelectedIndexAfterFilterChange() {
    final state = ref.read(appControllerProvider);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredItems.isNotEmpty) {
      final globalIndex = state.schedule.indexWhere((item) => item.id == filteredItems.first.id);
      if (globalIndex != -1) {
        ref.read(appControllerProvider.notifier).selectIndex(globalIndex);
      }
    } else {
      ref.read(appControllerProvider.notifier).selectIndex(-1);
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
    final activeItems = <ScheduleItem>[];
    final doneItems = <ScheduleItem>[];
    final postponedItems = <ScheduleItem>[];
    final pendingItems = <ScheduleItem>[];
    
    for (var item in items) {
      final threadMatch = _selectedThreadFilter == null ||
          item.threadIndex == _selectedThreadFilter;
      final typeMatch = _selectedTypeFilter == null ||
          item.typeIndex == _selectedTypeFilter;
      
      if (!threadMatch || !typeMatch) continue;
      switch (item.status) {
        case ScheduleItemStatus.active:
          activeItems.add(item);
          break;
        case ScheduleItemStatus.done:
          doneItems.add(item);
          break;
        case ScheduleItemStatus.postponed:
          postponedItems.add(item);
          break;
        case ScheduleItemStatus.pending:
          pendingItems.add(item);
          break;
      }
    }
    doneItems.sort((a, b) {
      final aTime = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    final ScheduleItem? lastDoneItem = doneItems.isNotEmpty ? doneItems.last : null;
    // 1. Последний выполненный
    // 2. Отложенные
    // 3. Активный
    // 4. Ожидающие
    final visibleItems = <ScheduleItem>[];
    // 1. Последний выполненный
    if (lastDoneItem != null) {
      visibleItems.add(lastDoneItem);
    }
    // 2. Отложенные
    visibleItems.addAll(postponedItems);
    // 3. Активный
    visibleItems.addAll(activeItems);
    // 4. Ожидающие
    visibleItems.addAll(pendingItems);
    
    return visibleItems;
  }

  int getGlobalIndex(int filteredIndex) {
    final state = ref.watch(appControllerProvider);
    final filteredItems = _getFilteredItems(state.schedule);
    if (filteredIndex < 0 || filteredIndex >= filteredItems.length) return -1;
    
    final item = filteredItems[filteredIndex];
    return state.schedule.indexWhere((scheduleItem) => 
        scheduleItem.id == item.id);
  }

  @override
  void initState() {
    super.initState();
    _scheduleInputController = TextEditingController();
    _timeController.text = '2';
  }

  @override
  void dispose() {
    _scheduleInputController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final lang = state.config.languageCode;

    final filteredItems = _getFilteredItems(state.schedule);
    final availableThreads = _getAvailableThreads(state.schedule);
    final availableTypes = _getAvailableTypes(state.schedule, _selectedThreadFilter);

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveUpIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _MoveDownIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const _ToggleRecordingIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.altLeft): const _PostponeIntent(),
      },
      child: Actions(
        actions: {
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(onInvoke: (_) => controller.selectPrevious()),
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(onInvoke: (_) => controller.selectNext()),
          _ToggleRecordingIntent: CallbackAction<_ToggleRecordingIntent>(
            onInvoke: (_) {
              if (state.isRecordingMarked) {
                controller.stopMark();
              } else {
                final currentSelectedIndex = state.selectedIndex;
                if (currentSelectedIndex != null) {
                  _handleStartWithGif(currentSelectedIndex);
                } else {
                  final filteredItems = _getFilteredItems(state.schedule);
                  if (filteredItems.isNotEmpty) {
                    final globalIndex = getGlobalIndex(0);
                    if (globalIndex != -1) {
                      _handleStartWithGif(globalIndex);
                    }
                  }
                }
              }
            },
          ),
          _PostponeIntent: CallbackAction<_PostponeIntent>(onInvoke: (_) => unawaited(controller.postpone())),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
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
                  tooltip: state.isPreviewRunning ? AppLocalizations.tr(lang, 'stopPreview') : AppLocalizations.tr(lang, 'startPreview'),
                  onPressed: controller.togglePreview,
                  icon: Icon(state.isPreviewRunning ? Icons.visibility_off : Icons.visibility),
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
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          if (state.isScheduleInputVisible) ...[
                            TextField(
                              controller: _scheduleInputController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: AppLocalizations.tr(lang, 'scheduleEditorLabel'),
                                hintText: AppLocalizations.tr(lang, 'scheduleEditorHint'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              if (state.isScheduleInputVisible)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => controller.applySchedule(_scheduleInputController.text),
                                    icon: const Icon(Icons.playlist_add_check),
                                    label: Text(AppLocalizations.tr(lang, 'applySchedule')),
                                  ),
                                )
                              else
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => controller.setScheduleInputVisibility(true),
                                    icon: const Icon(Icons.edit_note),
                                    label: Text(AppLocalizations.tr(lang, 'loadSchedule')),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IntrinsicWidth(
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
                                width: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    value: _selectedThreadFilter,
                                    hint: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(AppLocalizations.tr(lang, 'allThreads')),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(AppLocalizations.tr(lang, 'allThreads')),
                                        ),
                                      ),
                                      ...availableThreads.map((thread) => DropdownMenuItem(
                                        value: thread,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('$thread'),
                                        ),
                                      )),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedThreadFilter = value;
                                        _selectedTypeFilter = null;
                                      });
                                      _updateSelectedIndexAfterFilterChange();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    value: _selectedTypeFilter,
                                    hint: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(AppLocalizations.tr(lang, 'allTypes')),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(AppLocalizations.tr(lang, 'allTypes')),
                                        ),
                                      ),
                                      ...availableTypes.map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('$type'),
                                        ),
                                      )),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedTypeFilter = value;
                                      });
                                      _updateSelectedIndexAfterFilterChange();
                                    },
                                  ),
                                ),
                              ),
                              if (_selectedThreadFilter != null || _selectedTypeFilter != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _selectedThreadFilter = null;
                                      _selectedTypeFilter = null;
                                    });
                                    _updateSelectedIndexAfterFilterChange();
                                  },
                                  tooltip: AppLocalizations.tr(lang, 'resetFilters'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                  Text(AppLocalizations.tr(lang, 'displayedCounter'),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    )),
                                  Text('${filteredItems.length}/${state.schedule.length}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12))
                              ]
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ScheduleList(
                              items: filteredItems,
                              selectedIndex: state.selectedIndex != null 
                                  ? filteredItems.indexWhere((item) => 
                                      item.id == state.schedule[state.selectedIndex!].id)
                                  : null,
                              onSelect: (filteredIndex) {
                                final globalIndex = getGlobalIndex(filteredIndex);
                                if (globalIndex != -1) {
                                  controller.selectIndex(globalIndex);
                                }
                              },
                              onStart: (filteredIndex) async {
                                final globalIndex = getGlobalIndex(filteredIndex);
                                if (globalIndex != -1) {
                                  _handleStartWithGif(globalIndex);
                                }
                              },
                              onStop: (filteredIndex) async {
                                final globalIndex = getGlobalIndex(filteredIndex);
                                if (globalIndex != -1) {
                                  await controller.stopMark(globalIndex);
                                }
                              },
                              onPostpone: (filteredIndex) async {
                                final globalIndex = getGlobalIndex(filteredIndex);
                                if (globalIndex != -1) {
                                  await controller.postpone(globalIndex);
                                }
                              },
                              onRestore: (filteredIndex) {
                                final globalIndex = getGlobalIndex(filteredIndex);
                                if (globalIndex != -1) {
                                  controller.restoreItem(globalIndex);
                                }
                              },
                              isRecordingMarked: state.isRecordingMarked,
                              languageCode: lang,
                            ),
                          ),
                        ]
                      )
                  ),
                  ),
                  GifTitres(key: _gifTitresKey, lang: lang, delayTime: delayTime, selectedGif: state.config.selectedGif!,),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _ToggleRecordingIntent extends Intent {
  const _ToggleRecordingIntent();
}

class _PostponeIntent extends Intent {
  const _PostponeIntent();
}