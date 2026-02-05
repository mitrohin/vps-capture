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
    required String fio,
    required String apparatus,
    required void Function(String line) onLog,
  }) async {
    final segmentsDir = await _paths.segmentsDir();
    final files = await _pickSegments(segmentsDir, start, stop);
    if (files.isEmpty) throw Exception('No segments found for selected time range.');

    final listFile = await _paths.concatListFile();
    final content = files.map((f) => "file '${f.path.replaceAll("'", "''")}'").join('\n');
    await listFile.writeAsString(content);

    final outputName = FileNamer.outputClipName(fio: fio, apparatus: apparatus);
    final outputPath = p.join(config.outputDir!, outputName);

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

  Future<List<File>> _pickSegments(Directory dir, DateTime start, DateTime stop) async {
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.ts')) {
        final stat = await entity.stat();
        if (!stat.modified.isBefore(start) && !stat.modified.isAfter(stop)) {
          files.add(entity);
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String _defaultCodec() {
    if (Platform.isMacOS) return 'h264_videotoolbox';
    return 'libx264';
  }
}
