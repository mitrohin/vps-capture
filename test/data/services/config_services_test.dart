import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_capture/data/services/config_services.dart';

void main() {
  group('ConfigService.decodeTitleThemes', () {
    test('keeps defaults for missing templates and merges custom values', () {
      final decoded = ConfigService.decodeTitleThemes({
        'blue': {
          'fioFontScale': 0.2,
          'cityFontScale': 0.12,
          'fioColor': 'FF112233',
          'cityColor': 'FF445566',
        },
      });

      expect(decoded['blue']!.fioFontScale, 0.2);
      expect(decoded['blue']!.cityFontScale, 0.12);
      expect(decoded['blue']!.fioColor, const Color(0xFF112233));
      expect(decoded['blue']!.cityColor, const Color(0xFF445566));
      expect(decoded['red']!.cityColor, Colors.black);
      expect(decoded['fitness']!.fioFontScale, ConfigService.defaultTitleThemes['fitness']!.fioFontScale);
    });
  });
}
