import 'package:flutter/material.dart';

import '../../domain/models/schedule_item.dart';
import '../../localization/app_localizations.dart';

class ScheduleListEntry {
  const ScheduleListEntry({
    required this.item,
    required this.filteredIndex,
  });

  final ScheduleItem item;
  final int filteredIndex;
}

class ScheduleList extends StatefulWidget {
  const ScheduleList({
    super.key,
    required this.currentThreadItems,
    required this.nextThreadItems,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDelete,
    required this.languageCode,
    required this.currentThreadTitle,
    required this.nextThreadTitle,
    required this.isRecordingMarked,
  });

  final List<ScheduleListEntry> currentThreadItems;
  final List<ScheduleListEntry> nextThreadItems;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;
  final String languageCode;
  final String currentThreadTitle;
  final String nextThreadTitle;
  final bool isRecordingMarked;

  @override
  State<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildThreadColumn(
            title: widget.currentThreadTitle,
            entries: widget.currentThreadItems,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildThreadColumn(
            title: widget.nextThreadTitle,
            entries: widget.nextThreadItems,
          ),
        ),
      ],
    );
  }

  Widget _buildThreadColumn({
    required String title,
    required List<ScheduleListEntry> entries,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, listIndex) => _buildListItem(entries[listIndex]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(ScheduleListEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.selectedIndex == entry.filteredIndex;
    final isHovered = _hoveredIndex == entry.filteredIndex;
    final canDelete = !(widget.isRecordingMarked && entry.item.status == ScheduleItemStatus.active);
    final rowColor = isSelected
        ? colorScheme.primary
        : isHovered
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = entry.filteredIndex),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: rowColor,
        child: ListTile(
          dense: true,
          onTap: () => widget.onSelect(entry.filteredIndex),
          title: Text(
            entry.item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 28,
              color: isSelected ? colorScheme.onPrimary : null,
              decoration: entry.item.status == ScheduleItemStatus.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            _statusText(entry.item.status),
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? colorScheme.onPrimary.withValues(alpha: 0.9)
                  : colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          trailing: isHovered
              ? IconButton(
                  tooltip: AppLocalizations.tr(widget.languageCode, 'deleteEntry'),
                  onPressed: canDelete ? () => widget.onDelete(entry.filteredIndex) : null,
                  icon: Icon(
                    Icons.close,
                    color: canDelete
                        ? (isSelected ? colorScheme.onPrimary : Colors.red)
                        : (isSelected ? colorScheme.onPrimary.withValues(alpha: 0.4) : null),
                  ),
                )
              : null,
        ),
      ),
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
