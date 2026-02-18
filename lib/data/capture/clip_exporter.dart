import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/app_config.dart';
import '../storage/app_paths.dart';
import '../storage/file_namer.dart';

class ClipExporter {
  ClipExporter(this._paths);

  final AppPaths _paths;

  Future<String> exportClip({
    required AppConfig config,
    required DateTime start,
    required DateTime stop,
    required String id,
    required String fio,
    required String city,
    required void Function(String line) onLog,
  }) async {
    final segmentsDir = await _paths.segmentsDir();
    final files = await _pickSegments(
      segmentsDir,
      start,
      stop,
      segmentSeconds: config.segmentSeconds,
    );
    if (files.isEmpty) throw Exception('No segments found for selected time range.');

    final listFile = await _paths.concatListFile();
    final content = files.map((f) => "file '${f.path.replaceAll("'", "''")}'").join('\n');
    await listFile.writeAsString(content);

    final outputName = FileNamer.outputClipName(id:id ,fio: fio, city: city);
    final outputFolder = getOutputDir(config.outputDir!, id);
    final outputPath = p.join(outputFolder!, outputName);

    final copyArgs = [
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listFile.path,
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      outputPath,
      '-y',
    ];

    final copyCode = await _run(config.ffmpegPath!, copyArgs, onLog);
    if (copyCode == 0) return outputPath;

    final codec = config.codec ?? _defaultCodec();
    final encodeArgs = [
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listFile.path,
      '-c:v',
      codec,
      if (codec == 'libx264') ...['-preset', 'veryfast'],
      '-b:v',
      config.videoBitrate,
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      outputPath,
      '-y',
    ];

    final reencodeCode = await _run(config.ffmpegPath!, encodeArgs, onLog);
    if (reencodeCode != 0) throw Exception('Export failed in both copy and re-encode modes.');

    return outputPath;
  }

  Future<int> _run(String cmd, List<String> args, void Function(String line) onLog) async {
    final process = await Process.start(cmd, args);
    process.stdout.transform(SystemEncoding().decoder).listen(onLog);
    process.stderr.transform(SystemEncoding().decoder).listen(onLog);
    return process.exitCode;
  }

  Future<List<File>> _pickSegments(
    Directory dir,
    DateTime start,
    DateTime stop, {
    required int segmentSeconds,
  }) async {
    final segmentDuration = Duration(seconds: segmentSeconds.clamp(1, 60));
    final desiredWindowStart = start;
    final desiredWindowEnd = stop;
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.ts')) {
        final segmentStart = _segmentStart(entity.path) ?? (await entity.stat()).modified;
        final segmentEnd = segmentStart.add(segmentDuration);
        final intersectsWindow = segmentStart.isBefore(desiredWindowEnd) && segmentEnd.isAfter(desiredWindowStart);
        if (intersectsWindow) {
          files.add(entity);
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  DateTime? _segmentStart(String path) {
    final name = p.basename(path);
    final match = RegExp(r'^seg_(\d{8})_(\d{6})\.ts$').firstMatch(name);
    if (match == null) return null;
    final date = match.group(1)!;
    final time = match.group(2)!;
    return DateTime.tryParse(
      '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)} '
      '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}',
    );
  }

  String _defaultCodec() {
    if (Platform.isMacOS) return 'h264_videotoolbox';
    return 'libx264';
  }
  String? getOutputDir(String mainPath, String id) {
    final idThread = id.split('-')[0];
    final idType = id.split('-')[1];
    try{
      final directory = Directory(mainPath);
      final folders = directory.listSync().whereType<Directory>().toList();
      for (var folder in folders) {
        final folderName = folder.path.split(Platform.pathSeparator).last;
        if (folderName.startsWith(idThread)) {
          final dirThread = Directory(folder.path);
          if (!dirThread.existsSync()) continue;
          final typeFolders = dirThread.listSync().whereType<Directory>().toList();
          return typeFolders[int.parse(idType)-1].path;
        } else {
          continue;
        }
      }
    }
    catch (e) {
      return mainPath;
    }
    return mainPath;
  }
}
