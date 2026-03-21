import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage/app_paths.dart';

class RecordedClipEntry {
  const RecordedClipEntry({
    required this.clipId,
    required this.participantId,
    required this.fio,
    required this.city,
    required this.path,
    required this.createdAt,
    this.apparatus,
    this.threadIndex,
    this.typeIndex,
  });

  final String clipId;
  final String participantId;
  final String fio;
  final String city;
  final String? apparatus;
  final String path;
  final DateTime createdAt;
  final int? threadIndex;
  final int? typeIndex;

  Map<String, dynamic> toJson() => {
        'clipId': clipId,
        'participantId': participantId,
        'fio': fio,
        'city': city,
        'apparatus': apparatus,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'threadIndex': threadIndex,
        'typeIndex': typeIndex,
      };

  factory RecordedClipEntry.fromJson(Map<String, dynamic> json) {
    return RecordedClipEntry(
      clipId: json['clipId'] as String,
      participantId: json['participantId'] as String,
      fio: json['fio'] as String,
      city: json['city'] as String,
      apparatus: json['apparatus'] as String?,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      threadIndex: json['threadIndex'] as int?,
      typeIndex: json['typeIndex'] as int?,
    );
  }
}

class RecordedClipIndex {
  RecordedClipIndex(this._paths);

  final AppPaths _paths;
  List<RecordedClipEntry> _entries = const [];

  List<RecordedClipEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final file = await _indexFile();
    if (!await file.exists()) {
      _entries = const [];
      return;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      _entries = const [];
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    _entries = decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(RecordedClipEntry.fromJson)
        .toList(growable: false);
    await _removeMissingFiles();
  }

  Future<RecordedClipEntry> add({
    required String participantId,
    required String fio,
    required String city,
    required String path,
    String? apparatus,
    int? threadIndex,
    int? typeIndex,
  }) async {
    final entry = RecordedClipEntry(
      clipId: DateTime.now().microsecondsSinceEpoch.toString(),
      participantId: participantId,
      fio: fio,
      city: city,
      apparatus: apparatus,
      path: path,
      createdAt: DateTime.now().toUtc(),
      threadIndex: threadIndex,
      typeIndex: typeIndex,
    );
    _entries = [..._entries.where((item) => item.path != path), entry]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    await _save();
    return entry;
  }

  RecordedClipEntry? latestForParticipant(String participantId) {
    for (final entry in _entries) {
      if (entry.participantId == participantId) {
        return entry;
      }
    }
    return null;
  }

  RecordedClipEntry? entryByClipId(String clipId) {
    for (final entry in _entries) {
      if (entry.clipId == clipId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> clear() async {
    _entries = const [];
    final file = await _indexFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _removeMissingFiles() async {
    final filtered = _entries.where((entry) => File(entry.path).existsSync()).toList(growable: false);
    if (filtered.length == _entries.length) {
      return;
    }
    _entries = filtered;
    await _save();
  }

  Future<void> _save() async {
    final file = await _indexFile();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(_entries.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }

  Future<File> _indexFile() async {
    final supportDir = await _paths.appSupportDir();
    return File(p.join(supportDir.path, 'recorded_clips.json'));
  }
}
