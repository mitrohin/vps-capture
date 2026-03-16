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
              itemBuilder: (context, listIndex) {
                final entry = entries[listIndex];
                final showDivider = listIndex > 0 && 
                    entries[listIndex - 1].item.typeIndex != entry.item.typeIndex;
                
                return _buildListItemWithDivider(entry, showDivider);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItemWithDivider(ScheduleListEntry entry, bool showDivider) {
    final isSelected = widget.selectedIndex == entry.filteredIndex;
    final isHovered = _hoveredIndex == entry.filteredIndex;
    final canDelete = !(widget.isRecordingMarked && entry.item.status == ScheduleItemStatus.active);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = entry.filteredIndex),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: Container(
        key: isSelected ? _selectedItemKey : null,
        color: _getBackgroundColor(entry, isSelected, isHovered),
        child: Column(
          children: [
            if (showDivider)
              Container(
                height: 2,
                color: const Color(0xFF3A3A3D),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onTap: () => widget.onSelect(entry.filteredIndex),
              title: Row(
                children: [
                  if (entry.item.typeIndex != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTypeColor(entry.item.typeIndex!).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getTypeColor(entry.item.typeIndex!),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${entry.item.typeIndex}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getTypeColor(entry.item.typeIndex!),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      entry.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        decoration: entry.item.status == ScheduleItemStatus.done 
                            ? TextDecoration.lineThrough 
                            : null,
                      ),
                    ),
                  ),
                ],
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
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(ScheduleListEntry entry, bool isSelected, bool isHovered) {
    if (isSelected) {
      return const Color(0xFF055A0A);
    }
    if (isHovered) {
      return const Color(0xFF2A2A2D);
    }
    
    final typeIndex = entry.item.typeIndex;
    if (typeIndex != null) {
      return typeIndex.isOdd 
          ? const Color(0xFF1C1C1E)
          : const Color(0xFF2A2A2D);
    }
    
    return Colors.transparent;
  }

  Color _getTypeColor(int typeIndex) {
    switch (typeIndex) {
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFF2196F3); 
      case 3:
        return const Color(0xFFFF9800); 
      case 4:
        return const Color(0xFFE91E63); 
      default:
        return const Color(0xFF9C27B0); 
    }
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