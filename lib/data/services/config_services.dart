import 'package:flutter/material.dart';

import '../../domain/models/gif_title_theme.dart';

class ConfigService {
  static const Map<String, Map<String, double>> defaultTextPositions = {
    'blue': {
      'fioLeft': 0.19,
      'fioBottom': 0.44,
      'cityLeft': 0.05,
      'cityBottom': 0.15,
    },
    'red': {
      'fioLeft': 0.19,
      'fioBottom': 0.44,
      'cityLeft': 0.05,
      'cityBottom': 0.15,
    },
    'fitness': {
      'fioLeft': 0.25,
      'fioBottom': 0.5,
      'cityLeft': 0.45,
      'cityBottom': 0.23,
    },
    'lenta': {
      'fioLeft': 0.23,
      'fioBottom': 0.28,
      'cityLeft': 0.25,
      'cityBottom': 0.18,
    },
  };

  static final Map<String, GifTitleTheme> defaultTitleThemes = {
    'blue': GifTitleTheme(
      fioLeft: defaultTextPositions['blue']!['fioLeft']!,
      fioBottom: defaultTextPositions['blue']!['fioBottom']!,
      cityLeft: defaultTextPositions['blue']!['cityLeft']!,
      cityBottom: defaultTextPositions['blue']!['cityBottom']!,
      fioFontScale: 0.15,
      cityFontScale: 0.1,
      fioColor: Colors.white,
      cityColor: Colors.white,
    ),
    'red': GifTitleTheme(
      fioLeft: defaultTextPositions['red']!['fioLeft']!,
      fioBottom: defaultTextPositions['red']!['fioBottom']!,
      cityLeft: defaultTextPositions['red']!['cityLeft']!,
      cityBottom: defaultTextPositions['red']!['cityBottom']!,
      fioFontScale: 0.15,
      cityFontScale: 0.1,
      fioColor: Colors.white,
      cityColor: Colors.black,
    ),
    'fitness': GifTitleTheme(
      fioLeft: defaultTextPositions['fitness']!['fioLeft']!,
      fioBottom: defaultTextPositions['fitness']!['fioBottom']!,
      cityLeft: defaultTextPositions['fitness']!['cityLeft']!,
      cityBottom: defaultTextPositions['fitness']!['cityBottom']!,
      fioFontScale: 0.15,
      cityFontScale: 0.1,
      fioColor: Colors.white,
      cityColor: Colors.white,
    ),
    'lenta': GifTitleTheme(
      fioLeft: defaultTextPositions['lenta']!['fioLeft']!,
      fioBottom: defaultTextPositions['lenta']!['fioBottom']!,
      cityLeft: defaultTextPositions['lenta']!['cityLeft']!,
      cityBottom: defaultTextPositions['lenta']!['cityBottom']!,
      fioFontScale: 0.15,
      cityFontScale: 0.1,
      fioColor: Colors.white,
      cityColor: Colors.white,
    ),
  };

  static Map<String, GifTitleTheme> copyDefaultTitleThemes() {
    return {
      for (final entry in defaultTitleThemes.entries)
        entry.key: entry.value.copyWith(),
    };
  }

  static Map<String, GifTitleTheme> decodeTitleThemes(Object? rawValue) {
    final decoded = copyDefaultTitleThemes();
    if (rawValue is! Map) {
      return decoded;
    }

    rawValue.forEach((key, value) {
      final gifKey = key.toString();
      final fallback = decoded[gifKey] ?? defaultTitleThemes['blue']!;
      if (value is! Map) {
        decoded[gifKey] = fallback;
        return;
      }

      decoded[gifKey] = GifTitleTheme(
        fioLeft: (value['fioLeft'] as num?)?.toDouble() ?? fallback.fioLeft,
        fioBottom: (value['fioBottom'] as num?)?.toDouble() ?? fallback.fioBottom,
        cityLeft: (value['cityLeft'] as num?)?.toDouble() ?? fallback.cityLeft,
        cityBottom: (value['cityBottom'] as num?)?.toDouble() ?? fallback.cityBottom,
        fioFontScale: (value['fioFontScale'] as num?)?.toDouble() ?? fallback.fioFontScale,
        cityFontScale: (value['cityFontScale'] as num?)?.toDouble() ?? fallback.cityFontScale,
        fioColor: GifTitleTheme.colorFromValue(value['fioColor'], fallback.fioColor),
        cityColor: GifTitleTheme.colorFromValue(value['cityColor'], fallback.cityColor),
      );
    });

    return decoded;
  }

  static Map<String, dynamic> encodeTitleThemes(Map<String, GifTitleTheme> themes) {
    return {
      for (final entry in themes.entries) entry.key: entry.value.toJson(),
    };
  }
}
