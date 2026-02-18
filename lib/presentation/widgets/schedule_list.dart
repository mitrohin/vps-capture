import 'package:flutter/material.dart';

import '../../domain/models/schedule_item.dart';
import '../../localization/app_localizations.dart';

class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onStart,
    required this.onStop,
    required this.onPostpone,
    required this.onRestore,
    required this.isRecordingMarked,
    required this.languageCode,
  });

  final List<ScheduleItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int index) onStart;
  final Future<void> Function(int index) onStop;
  final ValueChanged<int> onPostpone;
  final ValueChanged<int> onRestore;
  final bool isRecordingMarked;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIndex == index;
        final isActive = item.status == ScheduleItemStatus.active;
        final isDone = item.status == ScheduleItemStatus.done;
        final canStartThisItem = !isRecordingMarked || isActive;
        return ListTile(
          selected: isSelected,
          onTap: () => onSelect(index),
          title: Text(
            item.label,
            style: TextStyle(
              decoration: item.status == ScheduleItemStatus.done ? TextDecoration.lineThrough : null,
            ),
          ),
          trailing: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_statusText(item.status)),
              if (isDone)
                IconButton(
                  tooltip: AppLocalizations.tr(languageCode, 'restoreEntry'),
                  onPressed: () => onRestore(index),
                  icon: const Icon(Icons.undo),
                )
              else ...[
                IconButton(
                  tooltip: isActive
                      ? AppLocalizations.tr(languageCode, 'stopHotkey')
                      : AppLocalizations.tr(languageCode, 'startHotkey'),
                  onPressed: canStartThisItem
                      ? () => isActive ? onStop(index) : onStart(index)
                      : null,
                  icon: Icon(isActive ? Icons.stop : Icons.adjust),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(languageCode, 'postponeHotkey'),
                  onPressed: () => onPostpone(index),
                  icon: const Icon(Icons.keyboard_double_arrow_down),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _statusText(ScheduleItemStatus status) {
    switch (status) {
      case ScheduleItemStatus.pending:
        return AppLocalizations.tr(languageCode, 'pending');
      case ScheduleItemStatus.active:
        return AppLocalizations.tr(languageCode, 'active');
      case ScheduleItemStatus.done:
        return AppLocalizations.tr(languageCode, 'done');
      case ScheduleItemStatus.postponed:
        return AppLocalizations.tr(languageCode, 'postponed');
    }
  }
}
