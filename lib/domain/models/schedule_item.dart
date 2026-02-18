enum ScheduleItemStatus { pending, active, done, postponed }

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.fio,
    this.apparatus,
    required this.city,
    this.status = ScheduleItemStatus.pending,
    this.startedAt,
    this.threadIndex,
    this.typeIndex
  });

  final String id;
  final String fio;
  final String? apparatus;
  final String city;
  final ScheduleItemStatus status;
  final DateTime? startedAt;
  final int? threadIndex;
  final int? typeIndex;

  String get label => apparatus == null || apparatus!.isEmpty
      ? '$fio • $city'
      : '$fio • $city • $apparatus';
  String get threadLabel => threadIndex == null ? '' : 'T${threadIndex! + 1}';
  String get typeLabel => typeIndex == null ? '' : 'E${typeIndex! + 1}';

  ScheduleItem copyWith({
    String? id,
    String? fio,
    String? apparatus,
    String? city,
    ScheduleItemStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? threadIndex,
    int? typeIndex,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      fio: fio ?? this.fio,
      apparatus: apparatus ?? this.apparatus,
      city: city ?? this.city,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      threadIndex: threadIndex ?? this.threadIndex,
      typeIndex: typeIndex ?? this.typeIndex,
    );
  }
}
