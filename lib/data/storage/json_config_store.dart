import 'dart:convert';
import 'dart:io';

import 'app_paths.dart';

class JsonConfigStore {
  JsonConfigStore(this._paths);

  final AppPaths _paths;
  Map<String, dynamic> _data = <String, dynamic>{};

  Future<void> load() async {
    final file = await _paths.configFile();
    if (!await file.exists()) {
      _data = <String, dynamic>{};
      return;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      _data = <String, dynamic>{};
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _data = decoded;
      return;
    }

    if (decoded is Map) {
      _data = decoded.map((key, value) => MapEntry(key.toString(), value));
      return;
    }

    _data = <String, dynamic>{};
  }

  String? getString(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  int? getInt(String key) {
    final value = _data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? getBool(String key) {
    final value = _data[key];
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }

  bool get isEmpty => _data.isEmpty;

  Future<void> setAll(Map<String, dynamic> values) async {
    _data.addAll(values);
    await _save();
  }

  Future<void> clear() async {
    _data = <String, dynamic>{};
    await _save();
  }

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }

  Future<void> _save() async {
    final file = await _paths.configFile();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(_data));
  }
}
