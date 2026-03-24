import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

class LocalPreferences {
  LocalPreferences._(this._file, this._values);

  final File _file;
  final Map<String, dynamic> _values;

  static Future<LocalPreferences> load() async {
    final file = File(_defaultFilePath());
    if (!await file.exists()) {
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString('{}');
      return LocalPreferences._(file, <String, dynamic>{});
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return LocalPreferences._(file, decoded);
      }
      if (decoded is Map) {
        return LocalPreferences._(
          file,
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Ignore malformed json and reset storage.
    }

    await file.writeAsString('{}');
    return LocalPreferences._(file, <String, dynamic>{});
  }

  static String _defaultFilePath() {
    if (Platform.isWindows) {
      return p.join(AppPaths.getExecutableDirectory(), 'shared_preferences.json');
    }
    return p.join(AppPaths.getScheduleStorageDirectory(), 'shared_preferences.json');
  }

  String? getString(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  int? getInt(String key) {
    final value = _values[key];
    return value is int ? value : null;
  }

  bool? getBool(String key) {
    final value = _values[key];
    return value is bool ? value : null;
  }

  Future<void> setString(String key, String value) async {
    _values[key] = value;
    await _flush();
  }

  Future<void> setInt(String key, int value) async {
    _values[key] = value;
    await _flush();
  }

  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
    await _flush();
  }

  Future<void> clear() async {
    _values.clear();
    await _flush();
  }

  Future<void> _flush() async {
    await _file.writeAsString(jsonEncode(_values));
  }
}
