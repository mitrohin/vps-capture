import 'dart:io';
import 'package:path/path.dart' as path;

import '../storage/app_paths.dart';

class LocatedFfmpeg {
  const LocatedFfmpeg({this.ffmpegPath, this.ffplayPath});

  final String? ffmpegPath;
  final String? ffplayPath;
}

class FfmpegLocator {
  FfmpegLocator(this._appPaths);

  final AppPaths _appPaths;

  Future<LocatedFfmpeg> locate() async {
    final candidates = <String>[];
    if (Platform.isMacOS) {
      candidates.addAll([
        '/opt/homebrew/bin',
        '/usr/local/bin',
        '/usr/bin',
      ]);
    }

    final localBin = await _appPaths.binDir();
    candidates.add(localBin.path);

    String? ffmpeg;
    String? ffplay;

    if (Platform.isWindows) {

      final appDir = path.dirname(Platform.resolvedExecutable);
      final alreadyFfmepgPaths = [
        path.join(appDir, 'ffmpeg', 'bin', 'ffmpeg.exe'),
        path.join(appDir, 'ffmpeg', 'ffmpeg.exe'),
        path.join(appDir, 'ffmpeg.exe')
        ];
      for (final ffmpegPath in alreadyFfmepgPaths){
        final ffmepgFile = File(ffmpegPath);
        if (await ffmepgFile.exists()) {
          ffmpeg = ffmepgFile.path;
          final ffplayPath = File(path.join(path.dirname(ffmpegPath), 'ffplay.exe'));
          if (await ffplayPath.exists()) ffplay = ffplayPath.path;
          break;
        }
      }

      ffmpeg ??= await _where('ffmpeg.exe');
      ffplay ??= await _where('ffplay.exe');
    } else {
      for (final dir in candidates) {
        final ffmpegFile = File('$dir/ffmpeg');
        final ffplayFile = File('$dir/ffplay');
        if (ffmpeg == null && await ffmpegFile.exists()) ffmpeg = ffmpegFile.path;
        if (ffplay == null && await ffplayFile.exists()) ffplay = ffplayFile.path;
      }
      ffmpeg ??= await _which('ffmpeg');
      ffplay ??= await _which('ffplay');
    }

    return LocatedFfmpeg(ffmpegPath: ffmpeg, ffplayPath: ffplay);
  }

  Future<String?> _which(String binary) async {
    try {
      final result = await Process.run('which', [binary]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _where(String binary) async {
    try {
      final result = await Process.run('where', [binary]);
      if (result.exitCode == 0) {
        final first = (result.stdout as String).split(RegExp(r'\r?\n')).first.trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {}
    return null;
  }
}
