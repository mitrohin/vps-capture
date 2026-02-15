import 'dart:io';
import 'dart:convert';
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
    final devices = <CaptureDevice>[];
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
        if (inVideo) devices.add(CaptureDevice.videoDevice(id: id, name: name));
        if (inAudio) devices.add(CaptureDevice.audioDevice(id: id, name: name));
      }
    }
    return devices;
  }

  Future<List<CaptureDevice>> _scanDshow(String ffmpegPath) async {
    final logs = <String>[];
    final listDevicesTries = [
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      ['-hide_banner', '-list_devices', '1', '-f', 'dshow', '-i', 'dummy'],
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'video=dummy'],
    ];

    for (final args in listDevicesTries) {
      final result = await Process.run(
        ffmpegPath, 
        args,
        stdoutEncoding: null,  
        stderrEncoding: null,  
      );
      final stderrBytes = result.stderr as List<int>;
      final stdoutBytes = result.stdout as List<int>;
      final decodedStderr = _decodeBytes(stderrBytes);
      final decodedStdout = _decodeBytes(stdoutBytes);
      final combined = decodedStderr + (decodedStdout.isNotEmpty ? '\n$decodedStdout' : '');
      logs.add(combined);
    }

    final sourceResult = await Process.run(ffmpegPath, ['-hide_banner', '-sources', 'dshow'], stdoutEncoding: null, stderrEncoding: null);
    final sourceStderrBytes = sourceResult.stderr as List<int>;
    final sourceStdoutBytes = sourceResult.stdout as List<int>;
    final decodedSourceStderr = _decodeBytes(sourceStderrBytes);
    final decodedSourceStdout = _decodeBytes(sourceStdoutBytes);
    
    final combinedSource = decodedSourceStderr + (decodedSourceStdout.isNotEmpty ? '\n$decodedSourceStdout' : '');
    logs.add(combinedSource);

    final parsed = _parseDshowLogs(logs);
    final devices = <CaptureDevice>[];

  for (final video in parsed.videos) {
    devices.add(CaptureDevice.videoDevice(
      id: video.inputName,
      name: video.displayName,
    ));
  }
  for (final audio in parsed.audios) {
    devices.add(CaptureDevice.audioDevice(
      id: audio.inputName,
      name: audio.displayName,
    ));
  }
    return devices;
  }

  String _decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      final decoded = utf8.decode(bytes);
      return decoded;
    } catch (e) {
      return String.fromCharCodes(bytes);
    }
  }

  ({List<_DshowDevice> videos, List<_DshowDevice> audios}) _parseDshowLogs(List<String> logs) {
    final videos = <_DshowDevice>[];
    final audios = <_DshowDevice>[];
    _DshowDevice? pendingVideo;
    _DshowDevice? pendingAudio;

    for (final log in logs) {
      var mode = '';
      for (final rawLine in log.split(RegExp(r'\r?\n'))) {
        final line = rawLine.trim();
        if (line.contains('DirectShow video devices') || (line.contains('dshow')) && line.contains('video')) {
          mode = 'v';
          continue;
        }
        if (line.contains('DirectShow audio devices') || (line.contains('dshow')) && line.contains('audio')) {
          mode = 'a';
          continue;
        }

        final quoted = _extractQuotedValue(line);
        
        if (quoted != null && !line.contains('Alternative name')) {
          final device = _DshowDevice(displayName: quoted, inputName: quoted);
          if (mode == 'v') {
            _addUnique(videos, device);
            pendingVideo = device;
          }
          if (mode == 'a') {
            _addUnique(audios, device);
            pendingAudio = device;
          }
        }

        if (line.contains('Alternative name')) {
          if (quoted != null && mode == 'v' && pendingVideo != null) {

            _replaceInputName(videos, pendingVideo, quoted);
          }
          if (quoted != null && mode == 'a' && pendingAudio != null) {
            _replaceInputName(audios, pendingAudio, quoted);
          }
        }

        // Fallback parser for `ffmpeg -sources dshow` output:
        //   * video="Device"
        //   * audio="Device"
        final source = RegExp(r'^\*\s*(video|audio)="(.+?)"$', caseSensitive: false).firstMatch(line);
        final sourcesAlternative = RegExp(r'^([^ ]+)\s+\[(.+?)\]\s+\((video|audio)\)$', caseSensitive: false).firstMatch(line);
        if (source != null) {
          final type = source.group(1)!.toLowerCase();
          final name = source.group(2)!;
          print('$name $type');
          if (type == 'video') _addUnique(videos, _DshowDevice(displayName: name, inputName: name));
          if (type == 'audio') _addUnique(audios, _DshowDevice(displayName: name, inputName: name));
        } else if (sourcesAlternative != null) {
          final type = sourcesAlternative.group(3)!.toLowerCase();
          final name = sourcesAlternative.group(2)!;
          print('$name $type');
          if (type == 'video') _addUnique(videos, _DshowDevice(displayName: name, inputName: name));
          if (type == 'audio') _addUnique(audios, _DshowDevice(displayName: name, inputName: name));
        }
      }
    }
    return (videos: videos, audios: audios);
  }

  String? _extractQuotedValue(String line) {
    final m = RegExp(r'"(.+?)"').firstMatch(line);
    return m?.group(1);
  }

  void _addUnique(List<_DshowDevice> items, _DshowDevice value) {
    if (!items.any((item) => item.displayName == value.displayName)) {
      items.add(value);
    }
  }

  void _replaceInputName(List<_DshowDevice> items, _DshowDevice target, String inputName) {
    final index = items.indexOf(target);
    if (index == -1) return;
    items[index] = _DshowDevice(displayName: target.displayName, inputName: inputName);
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
            devices.add(CaptureDevice.videoDevice(id: name, name: name));
          }
        }
      }
      if (devices.isNotEmpty) break;
    }
    return devices;
  }
}

class _DshowDevice {
  const _DshowDevice({required this.displayName, required this.inputName});

  final String displayName;
  final String inputName;
}
