import 'package:flutter/material.dart';

import '../../domain/models/schedule_item.dart';
import '../../localization/app_localizations.dart';

class ScheduleList extends StatefulWidget {
  const ScheduleList({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onStart,
    required this.onStop,
    required this.onPostpone,
    required this.onRestore,
    required this.onDelete,
    required this.isRecordingMarked,
    required this.languageCode,
  });

  final List<ScheduleItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int index) onStart;
  final Future<void> Function(int index) onStop;
  final Future<void> Function(int index) onPostpone;
  final ValueChanged<int> onRestore;
  final ValueChanged<int> onDelete;
  final bool isRecordingMarked;
  final String languageCode;

  @override
  State<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = widget.selectedIndex == index;
        final isHovered = _hoveredIndex == index;
        final isActive = item.status == ScheduleItemStatus.active;
        final isDone = item.status == ScheduleItemStatus.done;
        final isPostponed = item.status == ScheduleItemStatus.postponed;
        final canStartThisItem = !widget.isRecordingMarked || isActive;
        final canPostponeThisItem = !widget.isRecordingMarked || isActive;
        final canDeleteThisItem = !(widget.isRecordingMarked && isActive);
        final rowColor = isSelected
            ? colorScheme.primary
            : isHovered
                ? colorScheme.surfaceContainerHighest
                : Colors.transparent;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: rowColor,
            child: ListTile(
              selected: isSelected,
              onTap: () => widget.onSelect(index),
              title: Text(
                item.label,
                style: TextStyle(
                  fontSize: 32,
                  color: isSelected ? colorScheme.onPrimary : null,
                  decoration: item.status == ScheduleItemStatus.done ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _statusText(item.status),
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? colorScheme.onPrimary : null,
                    ),
                  ),
                  if (isDone) ...[
                    IconButton(
                      tooltip: AppLocalizations.tr(widget.languageCode, 'restoreEntry'),
                      onPressed: () => widget.onRestore(index),
                      icon: Icon(Icons.undo, color: isSelected ? colorScheme.onPrimary : null),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: canStartThisItem
                          ? () => isActive ? widget.onStop(index) : widget.onStart(index)
                          : null,
                      child: Text(
                        isActive
                            ? AppLocalizations.tr(widget.languageCode, 'startStopButtonStop')
                            : AppLocalizations.tr(widget.languageCode, 'startStopButtonStart'),
                      ),
                    ),
                    IconButton(
                      tooltip: isPostponed
                          ? AppLocalizations.tr(widget.languageCode, 'restoreEntry')
                          : AppLocalizations.tr(widget.languageCode, 'postponeHotkey'),
                      onPressed: canPostponeThisItem
                          ? () => isPostponed ? widget.onRestore(index) : widget.onPostpone(index)
                          : null,
                      icon: Icon(
                        isPostponed ? Icons.undo : Icons.keyboard_double_arrow_down,
                        color: isSelected ? colorScheme.onPrimary : null,
                      ),
                    ),
                  ],
                  if (isHovered)
                    IconButton(
                      tooltip: AppLocalizations.tr(widget.languageCode, 'deleteEntry'),
                      onPressed: canDeleteThisItem ? () => widget.onDelete(index) : null,
                      icon: Icon(
                        Icons.close,
                        color: canDeleteThisItem
                            ? (isSelected ? colorScheme.onPrimary : Colors.red)
                            : (isSelected ? colorScheme.onPrimary.withOpacity(0.4) : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusText(ScheduleItemStatus status) {
    switch (status) {
      case ScheduleItemStatus.pending:
        return AppLocalizations.tr(widget.languageCode, 'pending');
      case ScheduleItemStatus.active:
        return AppLocalizations.tr(widget.languageCode, 'active');
      case ScheduleItemStatus.done:
        return AppLocalizations.tr(widget.languageCode, 'done');
      case ScheduleItemStatus.postponed:
        return AppLocalizations.tr(widget.languageCode, 'postponed');
    }
  }
}
