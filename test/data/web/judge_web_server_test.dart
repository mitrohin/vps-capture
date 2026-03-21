import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/web/judge_web_server.dart';

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
