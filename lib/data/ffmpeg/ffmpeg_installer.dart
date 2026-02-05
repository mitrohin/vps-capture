import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../storage/app_paths.dart';

class FfmpegInstallResult {
  const FfmpegInstallResult({required this.ffmpegPath, required this.ffplayPath});

  final String ffmpegPath;
  final String ffplayPath;
}

class FfmpegInstaller {
  FfmpegInstaller(this._appPaths, this._dio);

  final AppPaths _appPaths;
  final Dio _dio;

  Future<FfmpegInstallResult> installAutomatically() async {
    if (Platform.isMacOS) return _installMac();
    if (Platform.isWindows) return _installWindows();
    throw UnsupportedError('Only macOS and Windows are supported');
  }

  Future<FfmpegInstallResult> _installMac() async {
    final bin = await _appPaths.binDir();
    final ffmpegZip = File(p.join(bin.path, 'ffmpeg.zip'));
    final ffplayZip = File(p.join(bin.path, 'ffplay.zip'));

    await _dio.download('https://evermeet.cx/ffmpeg/getrelease/zip', ffmpegZip.path);
    await _dio.download('https://evermeet.cx/ffplay/getrelease/zip', ffplayZip.path);

    final ffmpegPath = await _extractSingleBinary(ffmpegZip, bin, 'ffmpeg');
    final ffplayPath = await _extractSingleBinary(ffplayZip, bin, 'ffplay');

    await Process.run('chmod', ['+x', ffmpegPath]);
    await Process.run('chmod', ['+x', ffplayPath]);

    return FfmpegInstallResult(ffmpegPath: ffmpegPath, ffplayPath: ffplayPath);
  }

  Future<FfmpegInstallResult> _installWindows() async {
    final bin = await _appPaths.binDir();
    final zipFile = File(p.join(bin.path, 'ffmpeg-release-essentials.zip'));
    await _dio.download(
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
      zipFile.path,
    );

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? ffmpegPath;
    String? ffplayPath;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (name.endsWith('/ffmpeg.exe') || name.endsWith('/ffplay.exe')) {
        final outPath = p.join(bin.path, p.basename(name));
        await File(outPath).writeAsBytes(file.content as List<int>);
        if (name.endsWith('/ffmpeg.exe')) ffmpegPath = outPath;
        if (name.endsWith('/ffplay.exe')) ffplayPath = outPath;
      }
    }

    if (ffmpegPath == null || ffplayPath == null) {
      throw Exception('Could not extract ffmpeg/ffplay from downloaded archive.');
    }

    return FfmpegInstallResult(ffmpegPath: ffmpegPath, ffplayPath: ffplayPath);
  }

  Future<String> _extractSingleBinary(File zipFile, Directory outputDir, String name) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive.files) {
      if (file.isFile && p.basename(file.name) == name) {
        final outPath = p.join(outputDir.path, name);
        await File(outPath).writeAsBytes(file.content as List<int>);
        return outPath;
      }
    }
    throw Exception('Binary $name not found in archive ${zipFile.path}');
  }
}
