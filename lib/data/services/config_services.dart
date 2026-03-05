import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../storage/app_paths.dart';

class ConfigService {
  static const String configFileName = 'config.json';

  static const Map<String, Map<String, double>> defaultTextPositions = {
    'blue': {
      'fioLeft': 0.08,
      'fioBottom': 0.16,
      'cityLeft': 0.08,
      'cityBottom': 0.05,
    },
    'red': {
      'fioLeft': 0.08,
      'fioBottom': 0.16,
      'cityLeft': 0.08,
      'cityBottom': 0.05,
    },
    'fitness': {
      'fioLeft': 0.08,
      'fioBottom': 0.16,
      'cityLeft': 0.08,
      'cityBottom': 0.05,
    },
    'lenta': {
      'fioLeft': 0.08,
      'fioBottom': 0.16,
      'cityLeft': 0.08,
      'cityBottom': 0.05,
    },
  };

  Map<String, Map<String, double>> textPositions = {
    for (final entry in defaultTextPositions.entries)
      entry.key: Map<String, double>.from(entry.value),
  };

  Future<void> loadConfig() async {
    final configPath = AppPaths.getExecutableDirectory();
    final configFile = File(path.join(configPath, configFileName));
    if (!await configFile.exists()) return;

    final contents = await configFile.readAsString();
    final jsonConfig = jsonDecode(contents) as Map<String, dynamic>;
    if (jsonConfig['textPositions'] == null) return;

    final positionsJson = jsonConfig['textPositions'] as Map;
    final loaded = {
      for (final entry in defaultTextPositions.entries)
        entry.key: Map<String, double>.from(entry.value),
    };
    positionsJson.forEach((key, value) {
      if (value is Map) {
        loaded[key.toString()] = Map<String, double>.from(value);
      }
    });
    textPositions = loaded;
  }
}

