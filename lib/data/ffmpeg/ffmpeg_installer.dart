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

class FfmpegInstallException implements Exception {
  const FfmpegInstallException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return message;
    return '$message\nCause: $cause';
  }
}

class FfmpegInstaller {
  FfmpegInstaller(this._appPaths, this._dio);

  final AppPaths _appPaths;
  final Dio _dio;

  Future<FfmpegInstallResult> installAutomatically() async {
    if (Platform.isMacOS) return _installMac();
    if (Platform.isWindows) return _installWindows();
    throw const FfmpegInstallException('Automatic installation is supported only on macOS and Windows.');
  }

  Future<FfmpegInstallResult> _installMac() async {
    final bin = await _appPaths.binDir();
    final ffmpegZip = File(p.join(bin.path, 'ffmpeg.zip'));
    final ffplayZip = File(p.join(bin.path, 'ffplay.zip'));

    try {
      await _downloadWithTimeout('https://evermeet.cx/ffmpeg/getrelease/zip', ffmpegZip.path);
      await _downloadWithTimeout('https://evermeet.cx/ffmpeg/get/ffplay/zip', ffplayZip.path);
    } on DioException catch (e) {
      throw FfmpegInstallException(
        'Could not download ffmpeg automatically. On macOS desktop apps this often means network entitlement is missing or outbound network is blocked. '
        'Please use "Pick ffmpeg path..." / "Pick ffplay path..." as fallback.',
        e,
      );
    }

    final ffmpegPath = await _extractSingleBinary(ffmpegZip, bin, 'ffmpeg');
    final ffplayPath = await _extractSingleBinary(ffplayZip, bin, 'ffplay');

    await Process.run('chmod', ['+x', ffmpegPath]);
    if (ffplayPath != ffmpegPath) {
      await Process.run('chmod', ['+x', ffplayPath]);
    }

    return FfmpegInstallResult(ffmpegPath: ffmpegPath, ffplayPath: ffplayPath);
  }

  Future<FfmpegInstallResult> _installWindows() async {
    final bin = await _appPaths.binDir();
    final zipFile = File(p.join(bin.path, 'ffmpeg-release-essentials.zip'));

    try {
      await _downloadWithTimeout(
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
        zipFile.path,
      );
    } on DioException catch (e) {
      throw FfmpegInstallException(
        'Could not download ffmpeg build from gyan.dev. Check internet access/firewall or use manual path selection.',
        e,
      );
    }

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
      throw const FfmpegInstallException('Could not extract ffmpeg/ffplay from downloaded archive.');
    }

    return FfmpegInstallResult(ffmpegPath: ffmpegPath, ffplayPath: ffplayPath);
  }



  Future<void> _downloadWithTimeout(String url, String path) async {
    await _dio.download(
      url,
      path,
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
  }

  Future<String> _extractSingleBinary(File zipFile, Directory outputDir, String name) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? matched;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final baseName = p.basename(file.name).toLowerCase();
      final normalizedName = baseName.endsWith('.exe') ? baseName.substring(0, baseName.length - 4) : baseName;
      final target = name.toLowerCase();

      if (normalizedName == target || normalizedName.startsWith('$target-')) {
        matched = file;
        break;
      }
    }

    if (matched != null) {
      final outPath = p.join(outputDir.path, name);
      await File(outPath).writeAsBytes(matched.content as List<int>);
      return outPath;
    }

    throw FfmpegInstallException('Binary $name not found in archive ${zipFile.path}');
  }
}
