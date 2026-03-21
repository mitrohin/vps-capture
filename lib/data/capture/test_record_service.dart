import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/app_config.dart';
import '../storage/app_paths.dart';
import '../storage/file_namer.dart';
import 'capture_service.dart';
import 'clip_exporter.dart';

class TestRecordService {
  TestRecordService(this._captureService, this._clipExporter);

  final CaptureService _captureService;
  final ClipExporter _clipExporter;
  DateTime? _startTime;

  bool get isRunning => _captureService.isBufferRunning;

  Future<void> start(
    AppConfig config,
    void Function(String line) onLog,
  ) async {
    onLog('Starting test recording...');
    _startTime = DateTime.now();
    await _captureService.startBuffer(config, onLog, () {
      onLog('Test recording stopped unexpectedly');
    });
    onLog('Test recording started');
  }

  Future<String?> stop(
    AppConfig config,
    void Function(String line) onLog,
  ) async {
    if (_startTime == null) {
      onLog('No test recording in progress');
      return null;
    }
    onLog('Stopping test recording...');
    final stopTime = DateTime.now();
    await _captureService.stopBuffer();
    onLog('Creating test recording file...');
    try {
      final outputDirPath = config.outputDir;
      if (outputDirPath == null || outputDirPath.trim().isEmpty) {
        onLog('Cannot save test recording: output directory is not configured');
        return null;
      }
      final outputDir = Directory(outputDirPath);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
        onLog('Created output directory for test recording: ${outputDir.path}');
      }
      final outputPath = p.join(
        outputDir.path,
        FileNamer.testRecordingName(at: _startTime),
      );
      final segmentsDir = await AppPaths().segmentsDir();
      final files = <File>[];
      await for (final entity in segmentsDir.list()) {
        if (entity is File && entity.path.endsWith('.ts')) {
          final stat = await entity.stat();
          if (stat.modified.isAfter(
                _startTime!.subtract(const Duration(seconds: 1)),
              ) &&
              stat.modified.isBefore(stopTime.add(const Duration(seconds: 1)))) {
            files.add(entity);
          }
        }
      }
      if (files.isEmpty) {
        onLog('No segments found for test recording');
        return null;
      }
      onLog('Found ${files.length} segments for test recording');
      files.sort((a, b) => a.path.compareTo(b.path));
      final listFile = File(p.join(segmentsDir.path, 'test_concat_list.txt'));
      final content = files.map((f) => "file '${f.path.replaceAll("'", "''")}'").join('\n');
      await listFile.writeAsString(content);
      onLog('Concatenating segments...');
      final args = [
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-c',
        'copy',
        '-movflags',
        config.movFlags,
        '-y',
        outputPath,
      ];
      final process = await Process.start(config.ffmpegPath!, args);
      process.stderr.transform(SystemEncoding().decoder).listen((line) {
        if (line.isNotEmpty) onLog('[ffmpeg] $line');
      });
      final exitCode = await process.exitCode;
      await listFile.delete();
      if (exitCode == 0) {
        final file = File(outputPath);
        if (await file.exists()) {
          final size = await file.length();
          onLog('Test recording saved to: $outputPath');
          onLog('File size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
          return outputPath;
        }
      } else {
        onLog('FFmpeg failed with code: $exitCode');
      }
      return null;
    } catch (e, stack) {
      onLog('Error creating test recording: $e');
      onLog('Stack: $stack');
      return null;
    } finally {
      _startTime = null;
    }
  }
}
