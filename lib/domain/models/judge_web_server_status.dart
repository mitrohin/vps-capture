class JudgeWebServerStatus {
  const JudgeWebServerStatus({
    this.isRunning = false,
    this.port,
    this.urls = const [],
    this.errorMessage,
  });

  final bool isRunning;
  final int? port;
  final List<String> urls;
  final String? errorMessage;

  JudgeWebServerStatus copyWith({
    bool? isRunning,
    int? port,
    List<String>? urls,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return JudgeWebServerStatus(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      urls: urls ?? this.urls,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
