import '../../domain/models/schedule_item.dart';

class ScheduleParser {
  List<ScheduleItem> parse(String content) {
    final items = <ScheduleItem>[];
    final lines = content.split(RegExp(r'\r?\n'));
    int currentThreadIndex = -1;
    int currentTypeCount = 1;
    List<Map<String, dynamic>> currentParticipants = [];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('/*')) {
        if (currentParticipants.isNotEmpty && currentTypeCount > 0){
          for (int type = 0; type < currentTypeCount; type++) {
            for (final p in currentParticipants){
              String indexSchedule;
              if (currentParticipants.indexOf(p)+1 > 9) {
                indexSchedule = '${currentParticipants.indexOf(p)+1}';
              } else {indexSchedule = '0${currentParticipants.indexOf(p)+1}';}
              items.add(
                  ScheduleItem(
                    id: '0${currentThreadIndex+1}-0${type+1}-$indexSchedule',
                    fio: p['fio']!,
                    city: p['city']!,
                    apparatus: p['apparatus'],
                    threadIndex: currentThreadIndex+1,
                    typeIndex: type+1,
                  )
              );

            }
          }
        }
        currentThreadIndex++;
        try {
          final splittedTypeCount = line.split(' ')[0];
          currentTypeCount = int.parse(splittedTypeCount.substring(2));
        }
        catch (e) { 
          currentTypeCount = 1;
        }
        currentParticipants = [];
      } else {
        final parts = line.split(';').map((e) => e.trim()).toList();
        if (parts.length >= 2) {
          currentParticipants.add({
            'fio': parts[0],
            'city': parts[1],
            'apparatus': parts.length > 2 ? parts[2] : null,
          });
        }
      }
    }
    if (currentParticipants.isNotEmpty && currentTypeCount > 0) {
      for (int type = 0; type < currentTypeCount; type++) {
        for (final p in currentParticipants) {
          String indexSchedule;
          if (currentParticipants.indexOf(p)+1 > 9) {
            indexSchedule = '${currentParticipants.indexOf(p)+1}';
          } else {indexSchedule = '0${currentParticipants.indexOf(p)+1}';}
          items.add(ScheduleItem(
            id: '0${currentThreadIndex+1}-0${type+1}-$indexSchedule',
            fio: p['fio']!,
            city: p['city']!,
            apparatus: p['apparatus'],
            threadIndex: currentThreadIndex+1,
            typeIndex: type+1));
        }
      }
    }
    return items;
  }
}
