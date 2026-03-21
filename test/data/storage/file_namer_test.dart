import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/storage/file_namer.dart';

void main() {
  group('FileNamer.sanitizeSegment', () {
    test('replaces special characters with spaces', () {
      final result = FileNamer.sanitizeSegment(' Иванов, Петр. Судья №1 / финал ');

      expect(result, 'Иванов Петр Судья 1 финал');
    });
  });

  group('FileNamer.outputClipName', () {
    test('keeps sanitized words separated by spaces', () {
      final result = FileNamer.outputClipName(
        id: '01',
        fio: 'Иванов, Петр.',
        city: 'г. Москва',
      );

      expect(result, matches(r'^01 Иванов Петр_г Москва-\d{8}_\d{6}\.mp4$'));
    });
  });

  group('FileNamer.testRecordingName', () {
    test('builds a timestamped test file name', () {
      final result = FileNamer.testRecordingName(
        at: DateTime.utc(2026, 3, 21, 12, 34, 56),
      );

      expect(result, 'test_20260321_123456.mp4');
    });
  });
}
