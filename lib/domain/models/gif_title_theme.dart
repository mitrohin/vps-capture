import 'package:flutter/material.dart';

class GifTitleTheme {
  const GifTitleTheme({
    required this.fioLeft,
    required this.fioBottom,
    required this.cityLeft,
    required this.cityBottom,
    required this.fioFontScale,
    required this.cityFontScale,
    required this.fioColor,
    required this.cityColor,
  });

  final double fioLeft;
  final double fioBottom;
  final double cityLeft;
  final double cityBottom;
  final double fioFontScale;
  final double cityFontScale;
  final Color fioColor;
  final Color cityColor;

  GifTitleTheme copyWith({
    double? fioLeft,
    double? fioBottom,
    double? cityLeft,
    double? cityBottom,
    double? fioFontScale,
    Color? fioColor,
    double? cityFontScale,
    Color? cityColor,
  }) {
    return GifTitleTheme(
      fioLeft: fioLeft ?? this.fioLeft,
      fioBottom: fioBottom ?? this.fioBottom,
      cityLeft: cityLeft ?? this.cityLeft,
      cityBottom: cityBottom ?? this.cityBottom,
      fioFontScale: fioFontScale ?? this.fioFontScale,
      cityFontScale: cityFontScale ?? this.cityFontScale,
      fioColor: fioColor ?? this.fioColor,
      cityColor: cityColor ?? this.cityColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fioLeft': fioLeft,
      'fioBottom': fioBottom,
      'cityLeft': cityLeft,
      'cityBottom': cityBottom,
      'fioFontScale': fioFontScale,
      'cityFontScale': cityFontScale,
      'fioColor': fioColor.value,
      'cityColor': cityColor.value,
    };
  }

  static Color colorFromValue(Object? value, Color fallback) {
    if (value is int) {
      return Color(value);
    }
    if (value is String) {
      final normalized = value.replaceAll('#', '').trim();
      final parsed = int.tryParse(
        normalized.length == 6 ? 'FF$normalized' : normalized,
        radix: 16,
      );
      if (parsed != null) {
        return Color(parsed);
      }
    }
    return fallback;
  }
}
