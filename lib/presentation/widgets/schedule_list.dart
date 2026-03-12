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
    required this.postponedItems,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDelete,
    required this.languageCode,
    required this.currentThreadTitle,
    required this.nextThreadTitle,
    required this.postponedTitle,
    required this.isRecordingMarked,
    this.middleControls,
  });

  final List<ScheduleListEntry> currentThreadItems;
  final List<ScheduleListEntry> nextThreadItems;
  final List<ScheduleListEntry> postponedItems;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;
  final String languageCode;
  final String currentThreadTitle;
  final String nextThreadTitle;
  final String postponedTitle;
  final bool isRecordingMarked;
  final Widget? middleControls;

  @override
  State<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  int? _hoveredIndex;
  int? _lastScrolledSelectedIndex;

  @override
  void didUpdateWidget(covariant ScheduleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedIndex = widget.selectedIndex;
    if (selectedIndex == null || selectedIndex == _lastScrolledSelectedIndex) {
      return;
    }
    _lastScrolledSelectedIndex = selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selectedItemKey.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
    });
  }

  final GlobalKey _selectedItemKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildThreadColumn(
            title: widget.currentThreadTitle,
            entries: widget.currentThreadItems,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildThreadColumn(
            title: widget.nextThreadTitle,
            entries: widget.nextThreadItems,
          ),
        ),
        if (widget.middleControls != null) ...[
          const SizedBox(width: 10),
          widget.middleControls!,
        ],
        const SizedBox(width: 10),
        Expanded(
          child: _buildThreadColumn(
            title: widget.postponedTitle,
            entries: widget.postponedItems,
          ),
        ),
      ],
    );
  }

  Widget _buildThreadColumn({
    required String title,
    required List<ScheduleListEntry> entries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A2D)),
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
    final isSelected = widget.selectedIndex == entry.filteredIndex;
    final isHovered = _hoveredIndex == entry.filteredIndex;
    final canDelete = !(widget.isRecordingMarked && entry.item.status == ScheduleItemStatus.active);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = entry.filteredIndex),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: AnimatedContainer(
        key: isSelected ? _selectedItemKey : null,
        duration: const Duration(milliseconds: 120),
        color: isSelected
            ? const Color(0xFF055A0A)
            : isHovered
                ? const Color(0xFF2A2A2D)
                : Colors.transparent,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onTap: () => widget.onSelect(entry.filteredIndex),
          title: Text(
            entry.item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              decoration: entry.item.status == ScheduleItemStatus.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            _statusText(entry.item.status),
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white70 : Colors.grey,
            ),
          ),
          trailing: isHovered
              ? IconButton(
                  tooltip: AppLocalizations.tr(widget.languageCode, 'deleteEntry'),
                  onPressed: canDelete ? () => widget.onDelete(entry.filteredIndex) : null,
                  icon: Icon(
                    Icons.close,
                    color: canDelete ? Colors.red : Colors.grey,
                    size: 18,
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
