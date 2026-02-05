import '../../domain/models/schedule_item.dart';

class ScheduleParser {
  List<ScheduleItem> parse(String content) {
    final items = <ScheduleItem>[];
    final lines = content.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(';').map((e) => e.trim()).toList();
      if (parts.length < 2) continue;
      items.add(ScheduleItem(
        id: '${i + 1}_${parts[0]}_${parts[1]}',
        fio: parts[0],
        apparatus: parts[1],
        city: parts.length > 2 ? parts[2] : null,
      ));
    }
    return items;
  }
}
