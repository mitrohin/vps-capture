import 'package:flutter/material.dart';

import '../../domain/models/schedule_item.dart';
import '../../localization/app_localizations.dart';

class ScheduleListEntry {
  const ScheduleListEntry({
    required this.item,
    required this.globalIndex,
  });

  final ScheduleItem item;
  final int globalIndex;
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
    this.nextThreadEmptyLabel,
    required this.isRecordingMarked,
    this.middleControls,
    this.postponedBottomWidget,
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
  final String? nextThreadEmptyLabel;
  final bool isRecordingMarked;
  final Widget? middleControls;
  final Widget? postponedBottomWidget;

  @override
  State<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  int? _hoveredIndex;
  int? _lastScrolledSelectedIndex;
  final ScrollController _currentThreadScrollController = ScrollController();
  final ScrollController _nextThreadScrollController = ScrollController();
  final ScrollController _postponedScrollController = ScrollController();
  final GlobalKey _selectedItemKey = GlobalKey();

  @override
  void dispose() {
    _currentThreadScrollController.dispose();
    _nextThreadScrollController.dispose();
    _postponedScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScheduleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entriesChanged(oldWidget.currentThreadItems, widget.currentThreadItems) ||
        oldWidget.currentThreadTitle != widget.currentThreadTitle) {
      _scrollToTop(_currentThreadScrollController);
    }
    if (_entriesChanged(oldWidget.nextThreadItems, widget.nextThreadItems) ||
        oldWidget.nextThreadTitle != widget.nextThreadTitle) {
      _scrollToTop(_nextThreadScrollController);
    }

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

  bool _entriesChanged(List<ScheduleListEntry> previous, List<ScheduleListEntry> next) {
    if (previous.length != next.length) {
      return true;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].globalIndex != next[index].globalIndex ||
          previous[index].item.id != next[index].item.id) {
        return true;
      }
    }
    return false;
  }

  void _scrollToTop(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) {
        return;
      }
      controller.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildThreadColumn(
            title: widget.currentThreadTitle,
            entries: widget.currentThreadItems,
            showThreadBadge: false,
            scrollController: _currentThreadScrollController,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildThreadColumn(
            title: widget.nextThreadTitle,
            entries: widget.nextThreadItems,
            showThreadBadge: false,
            emptyLabel: widget.nextThreadEmptyLabel,
            scrollController: _nextThreadScrollController,
          ),
        ),
        if (widget.middleControls != null) ...[
          const SizedBox(width: 10),
          widget.middleControls!,
        ],
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: widget.postponedBottomWidget == null ? 1 : 2,
                child: _buildThreadColumn(
                  title: widget.postponedTitle,
                  entries: widget.postponedItems,
                  showThreadBadge: true,
                  scrollController: _postponedScrollController,
                ),
              ),
              if (widget.postponedBottomWidget != null) ...[
                const SizedBox(height: 10),
                Expanded(
                  flex: 2,
                  child: widget.postponedBottomWidget!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThreadColumn({
    required String title,
    required List<ScheduleListEntry> entries,
    required bool showThreadBadge,
    required ScrollController scrollController,
    String? emptyLabel,
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
              controller: scrollController,
              itemCount: entries.length,
              itemBuilder: (context, listIndex) {
                final entry = entries[listIndex];
                final showDivider = listIndex > 0 && 
                    entries[listIndex - 1].item.typeIndex != entry.item.typeIndex;
                
                return _buildListItemWithDivider(
                  entry,
                  showDivider,
                  showThreadBadge: showThreadBadge,
                );
              },
            ),
          ),
        ),
        if (entries.isEmpty && emptyLabel != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              emptyLabel,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListItemWithDivider(
    ScheduleListEntry entry,
    bool showDivider, {
    required bool showThreadBadge,
  }) {
    final isSelected = widget.selectedIndex == entry.globalIndex;
    final isHovered = _hoveredIndex == entry.globalIndex;
    final canDelete = !(widget.isRecordingMarked && entry.item.status == ScheduleItemStatus.active);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = entry.globalIndex),
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
              onTap: () => widget.onSelect(entry.globalIndex),
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
                  if (showThreadBadge && entry.item.threadIndex != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'П${entry.item.threadIndex}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
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
                        decorationThickness: 2.5
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
                      onPressed: canDelete ? () => widget.onDelete(entry.globalIndex) : null,
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
      case 5:
        return const Color.fromARGB(255, 0, 60, 151);
      case 6:
        return const Color.fromARGB(255, 0, 255, 191); 
      case 7:
        return const Color.fromARGB(255, 119, 0, 255); 
      case 8:
        return const Color.fromARGB(255, 255, 73, 133); 
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
