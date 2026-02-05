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
    final result = await Process.run(ffmpegPath, [
      '-hide_banner',
      '-list_devices',
      'true',
      '-f',
      'dshow',
      '-i',
      'dummy'
    ]);
    final log = '${result.stderr}\n${result.stdout}';
    final lines = log.split(RegExp(r'\r?\n'));
    final videos = <String>[];
    final audios = <String>[];
    var mode = '';
    final rx = RegExp(r'"(.+?)"');
    for (final line in lines) {
      if (line.contains('DirectShow video devices')) mode = 'v';
      if (line.contains('DirectShow audio devices')) mode = 'a';
      final m = rx.firstMatch(line);
      if (m != null) {
        if (mode == 'v') videos.add(m.group(1)!);
        if (mode == 'a') audios.add(m.group(1)!);
      }
    }
    return videos
        .map((v) => CaptureDevice(
              id: v,
              name: v,
              audioId: audios.isNotEmpty ? audios.first : null,
              audioName: audios.isNotEmpty ? audios.first : null,
            ))
        .toList();
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
