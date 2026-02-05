enum ScheduleItemStatus { pending, active, done, postponed }

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.fio,
    required this.apparatus,
    this.city,
    this.status = ScheduleItemStatus.pending,
    this.startedAt,
  });

  final String id;
  final String fio;
  final String apparatus;
  final String? city;
  final ScheduleItemStatus status;
  final DateTime? startedAt;

  String get label => city == null || city!.isEmpty
      ? '$fio • $apparatus'
      : '$fio • $apparatus • $city';

  ScheduleItem copyWith({
    String? id,
    String? fio,
    String? apparatus,
    String? city,
    ScheduleItemStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      fio: fio ?? this.fio,
      apparatus: apparatus ?? this.apparatus,
      city: city ?? this.city,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }
}
