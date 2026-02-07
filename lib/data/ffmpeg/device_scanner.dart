import 'dart:io';

import '../../domain/models/capture_device.dart';

class DeviceScanner {
  Future<List<CaptureDevice>> scan({
    required String ffmpegPath,
    required CaptureSourceKind kind,
  }) async {
    switch (kind) {
      case CaptureSourceKind.avFoundation:
        return _scanAvFoundation(ffmpegPath);
      case CaptureSourceKind.directShow:
        return _scanDshow(ffmpegPath);
      case CaptureSourceKind.deckLink:
        return _scanDecklink(ffmpegPath);
    }
  }

  Future<List<CaptureDevice>> _scanAvFoundation(String ffmpegPath) async {
    final result = await Process.run(ffmpegPath, ['-f', 'avfoundation', '-list_devices', 'true', '-i', '']);
    final log = '${result.stderr}\n${result.stdout}';
    final lines = log.split(RegExp(r'\r?\n'));
    final video = <CaptureDevice>[];
    final audio = <CaptureDevice>[];
    var inVideo = false;
    var inAudio = false;
    final rx = RegExp(r'\[(\d+)\]\s+(.+)$');
    for (final line in lines) {
      if (line.contains('AVFoundation video devices')) {
        inVideo = true;
        inAudio = false;
        continue;
      }
      if (line.contains('AVFoundation audio devices')) {
        inVideo = false;
        inAudio = true;
        continue;
      }
      final m = rx.firstMatch(line.trim());
      if (m != null) {
        final id = m.group(1)!;
        final name = m.group(2)!.trim();
        if (inVideo) video.add(CaptureDevice(id: id, name: name));
        if (inAudio) audio.add(CaptureDevice(id: id, name: name));
      }
    }
    return video
        .map((v) => CaptureDevice(
              id: v.id,
              name: v.name,
              audioId: audio.isNotEmpty ? audio.first.id : null,
              audioName: audio.isNotEmpty ? audio.first.name : null,
            ))
        .toList();
  }

  Future<List<CaptureDevice>> _scanDshow(String ffmpegPath) async {
    final logs = <String>[];
    final listDevicesTries = [
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      ['-hide_banner', '-list_devices', '1', '-f', 'dshow', '-i', 'dummy'],
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'video=dummy'],
    ];

    for (final args in listDevicesTries) {
      final result = await Process.run(ffmpegPath, args);
      logs.add('${result.stderr}\n${result.stdout}');
    }

    final sourceResult = await Process.run(ffmpegPath, ['-hide_banner', '-sources', 'dshow']);
    logs.add('${sourceResult.stderr}\n${sourceResult.stdout}');

    final parsed = _parseDshowLogs(logs);
    return parsed.videos
        .map((v) => CaptureDevice(
              id: v,
              name: v,
              audioId: parsed.audios.isNotEmpty ? parsed.audios.first : null,
              audioName: parsed.audios.isNotEmpty ? parsed.audios.first : null,
            ))
        .toList();
  }

  ({List<String> videos, List<String> audios}) _parseDshowLogs(List<String> logs) {
    final videos = <String>[];
    final audios = <String>[];

    for (final log in logs) {
      var mode = '';
      for (final rawLine in log.split(RegExp(r'\r?\n'))) {
        final line = rawLine.trim();
        if (line.contains('DirectShow video devices')) {
          mode = 'v';
          continue;
        }
        if (line.contains('DirectShow audio devices')) {
          mode = 'a';
          continue;
        }

        final quoted = _extractQuotedValue(line);
        if (quoted != null && !line.contains('Alternative name')) {
          if (mode == 'v') _addUnique(videos, quoted);
          if (mode == 'a') _addUnique(audios, quoted);
        }

        // Fallback parser for `ffmpeg -sources dshow` output:
        //   * video="Device"
        //   * audio="Device"
        final source = RegExp(r'^\*\s*(video|audio)="(.+?)"$', caseSensitive: false).firstMatch(line);
        if (source != null) {
          final type = source.group(1)!.toLowerCase();
          final name = source.group(2)!;
          if (type == 'video') _addUnique(videos, name);
          if (type == 'audio') _addUnique(audios, name);
        }
      }
    }

    return (videos: videos, audios: audios);
  }

  String? _extractQuotedValue(String line) {
    final m = RegExp(r'"(.+?)"').firstMatch(line);
    return m?.group(1);
  }

  void _addUnique(List<String> items, String value) {
    if (!items.contains(value)) {
      items.add(value);
    }
  }

  Future<List<CaptureDevice>> _scanDecklink(String ffmpegPath) async {
    final tries = [
      ['-hide_banner', '-f', 'decklink', '-list_devices', '1', '-i', 'dummy'],
      ['-hide_banner', '-f', 'decklink', '-list_devices', 'true', '-i', 'dummy'],
    ];
    final devices = <CaptureDevice>[];
    final rx = RegExp(r'\"(.+?)\"');
    for (final args in tries) {
      final result = await Process.run(ffmpegPath, args);
      final log = '${result.stderr}\n${result.stdout}';
      for (final line in log.split(RegExp(r'\r?\n'))) {
        final m = rx.firstMatch(line);
        if (m != null) {
          final name = m.group(1)!;
          if (!devices.any((d) => d.name == name)) {
            devices.add(CaptureDevice(id: name, name: name));
          }
        }
      }
      if (devices.isNotEmpty) break;
    }
    return devices;
  }
}
