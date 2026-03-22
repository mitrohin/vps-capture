import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/domain/models/app_config.dart';

void main() {
  group('AppConfig recordingStartTrimMillis', () {
    test('defaults to 500 milliseconds', () {
      const config = AppConfig();

      expect(config.recordingStartTrimMillis, 500);
    });

    test('copyWith overrides the trim value', () {
      const config = AppConfig(recordingStartTrimMillis: 500);
      final updated = config.copyWith(recordingStartTrimMillis: 1250);

      expect(updated.recordingStartTrimMillis, 1250);
      expect(config.recordingStartTrimMillis, 500);
    });
  });
}
