import 'package:intl/intl.dart';

class FileNamer {
  static String outputClipName({required String fio, required String apparatus}) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeFio = _sanitize(fio);
    final safeApp = _sanitize(apparatus);
    return '${safeFio}_${safeApp}_$ts.mp4';
  }

  static String _sanitize(String value) {
    final trimmed = value.trim();
    final invalid = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
    return trimmed.replaceAll(invalid, '_').replaceAll(RegExp(r'\s+'), '_');
  }
}
