import 'package:flutter/material.dart';

import '../../domain/models/schedule_item.dart';
import '../../localization/app_localizations.dart';

class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.languageCode,
  });

  final List<ScheduleItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIndex == index;
        return ListTile(
          selected: isSelected,
          onTap: () => onSelect(index),
          title: Text(
            item.label,
            style: TextStyle(
              decoration: item.status == ScheduleItemStatus.done ? TextDecoration.lineThrough : null,
            ),
          ),
          trailing: Text(_statusText(item.status)),
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
