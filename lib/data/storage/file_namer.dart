import 'package:intl/intl.dart';

class FileNamer {
  static String outputClipName({required String id, required String fio, required String city}) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeFio = sanitizeSegment(fio);
    final safeApp = sanitizeSegment(city);
    return '$id ${safeFio}_$safeApp-$ts.mp4';
  }

  static String testRecordingName({DateTime? at}) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(at ?? DateTime.now());
    return 'test_$ts.mp4';
  }

  static String sanitizeSegment(String value) {
    final trimmed = value.trim();
    final specialCharacters = RegExp(r'''[!"#$%&'()*+,./:;<=>?@[\\\]^_`{|}~«»…№<>:"/|*\x00-\x1F]+''');
    return trimmed.replaceAll(specialCharacters, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
