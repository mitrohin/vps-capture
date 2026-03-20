import 'package:flutter_test/flutter_test.dart';
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
}
