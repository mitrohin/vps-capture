import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/storage/app_paths.dart';
import 'package:vps_capture/data/web/judge_web_server.dart';
import 'package:vps_capture/data/web/recorded_clip_index.dart';

void main() {
  group('parseRangeHeader', () {
    test('parses explicit byte range', () {
      final range = parseRangeHeader('bytes=10-25', 100);
      expect(range, isNotNull);
      expect(range!.start, 10);
      expect(range.end, 25);
    });

    test('parses suffix byte range', () {
      final range = parseRangeHeader('bytes=-20', 100);
      expect(range, isNotNull);
      expect(range!.start, 80);
      expect(range.end, 99);
    });

    test('rejects invalid ranges', () {
      expect(parseRangeHeader('bytes=150-160', 100), isNull);
      expect(parseRangeHeader('bytes=25-20', 100), isNull);
    });
  });

  test('events endpoint streams initial snapshot without mutating response encoding', () async {
    final server = JudgeWebServer(RecordedClipIndex(AppPaths()));
    final snapshot = buildJudgeWebSnapshot(
      languageCode: 'ru',
      participants: const [
        JudgeWebParticipant(
          id: '1',
          fio: 'Анна',
          city: 'Москва',
          status: 'done',
          statusLabel: 'ГОТОВО',
          clipId: 'clip-1',
          threadIndex: 0,
          threadLabel: 'T1',
        ),
      ],
    );

    final status = await server.start(port: 0, snapshot: snapshot);
    expect(status.isRunning, isTrue);
    final baseUrl = Uri.parse('http://127.0.0.1:${status.port}');

    final client = HttpClient();
    try {
      final request = await client.getUrl(baseUrl.replace(path: '/events'));
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/event-stream');
      expect(response.headers.contentType?.charset?.toLowerCase(), 'utf-8');

      final chunk = await response.transform(const Utf8Decoder()).first;
      expect(chunk, contains('retry: 1500'));
      expect(chunk, contains('data: '));
      expect(chunk, contains('Анна'));
    } finally {
      client.close(force: true);
      await server.stop();
    }
  });

  test('buildJudgeWebSnapshot includes thread options and replay counts', () {
    final snapshot = buildJudgeWebSnapshot(
      languageCode: 'ru',
      participants: const [
        JudgeWebParticipant(
          id: '1',
          fio: 'Анна',
          city: 'Москва',
          status: 'done',
          statusLabel: 'ГОТОВО',
          clipId: 'clip-1',
          threadIndex: 0,
          threadLabel: 'T1',
        ),
        JudgeWebParticipant(
          id: '2',
          fio: 'Мария',
          city: 'Казань',
          status: 'pending',
          statusLabel: 'В ОЧЕРЕДИ',
          threadIndex: 1,
          threadLabel: 'T2',
        ),
      ],
    );

    final json = snapshot.toJson();
    expect(json['languageCode'], 'ru');
    expect((json['stats'] as Map<String, dynamic>)['withReplay'], 1);
    expect((json['threads'] as List).length, 2);
  });
}
