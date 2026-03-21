import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/domain/models/schedule_item.dart';
import 'package:vps_capture/presentation/screens/work_screen.dart';

void main() {
  group('normalizeDropdownValue', () {
    test('returns null when selection is missing from available values', () {
      expect(normalizeDropdownValue(0, const [1, 2]), isNull);
    });

    test('returns the selected value when it is available', () {
      expect(normalizeDropdownValue(2, const [1, 2, 3]), 2);
    });

    test('returns null when selection is null', () {
      expect(normalizeDropdownValue(null, const [1, 2, 3]), isNull);
    });
  });

  group('countReadyItemsForThread', () {
    test('counts only active, pending, and postponed items in the selected filter', () {
      final items = [
        ScheduleItem(id: '1', fio: 'A', city: 'X', threadIndex: 1, typeIndex: 1),
        const ScheduleItem(
          id: '2',
          fio: 'B',
          city: 'X',
          threadIndex: 1,
          typeIndex: 1,
          status: ScheduleItemStatus.active,
        ),
        const ScheduleItem(
          id: '3',
          fio: 'C',
          city: 'X',
          threadIndex: 1,
          typeIndex: 1,
          status: ScheduleItemStatus.postponed,
        ),
        const ScheduleItem(
          id: '4',
          fio: 'D',
          city: 'X',
          threadIndex: 1,
          typeIndex: 1,
          status: ScheduleItemStatus.done,
        ),
        ScheduleItem(id: '5', fio: 'E', city: 'X', threadIndex: 2, typeIndex: 1),
      ];

      expect(
        countReadyItemsForThread(items, threadIndex: 1, typeIndex: 1),
        3,
      );
    });
  });

  group('findNextThreadWithReadyItems', () {
    test('returns the next thread that still has ready items for the type filter', () {
      final items = [
        const ScheduleItem(
          id: '1',
          fio: 'A',
          city: 'X',
          threadIndex: 1,
          typeIndex: 1,
          status: ScheduleItemStatus.done,
        ),
        const ScheduleItem(
          id: '2',
          fio: 'B',
          city: 'X',
          threadIndex: 2,
          typeIndex: 1,
          status: ScheduleItemStatus.done,
        ),
        ScheduleItem(id: '3', fio: 'C', city: 'X', threadIndex: 3, typeIndex: 1),
        ScheduleItem(id: '4', fio: 'D', city: 'X', threadIndex: 4, typeIndex: 2),
      ];

      expect(
        findNextThreadWithReadyItems(
          items,
          const [1, 2, 3, 4],
          currentThread: 1,
          typeIndex: 1,
        ),
        3,
      );
    });

    test('returns null when there is no later thread with ready items', () {
      final items = [
        const ScheduleItem(
          id: '1',
          fio: 'A',
          city: 'X',
          threadIndex: 1,
          typeIndex: 1,
          status: ScheduleItemStatus.done,
        ),
        const ScheduleItem(
          id: '2',
          fio: 'B',
          city: 'X',
          threadIndex: 2,
          typeIndex: 1,
          status: ScheduleItemStatus.done,
        ),
      ];

      expect(
        findNextThreadWithReadyItems(
          items,
          const [1, 2],
          currentThread: 1,
          typeIndex: 1,
        ),
        isNull,
      );
    });
  });
}
