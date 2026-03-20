class FfmpegIssue {
  const FfmpegIssue({
    required this.id,
    required this.summary,
    required this.report,
    required this.occurredAt,
  });

  final String id;
  final String summary;
  final String report;
  final DateTime occurredAt;
}
