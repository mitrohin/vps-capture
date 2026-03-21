import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/storage/file_namer.dart';

void main() {
  group('FileNamer.testRecordingName', () {
    test('builds a timestamped test file name', () {
      final result = FileNamer.testRecordingName(
        at: DateTime.utc(2026, 3, 21, 12, 34, 56),
      );

      expect(result, 'test_20260321_123456.mp4');
    });
  });
}
