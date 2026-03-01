import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../storage/app_paths.dart';

class ConfigService {
  static const String configFileName = 'config.json';

  Map<String, Map<String, double>> textPositions = {};

  Future<void> loadConfig() async {
    String configPath = AppPaths.getExecutableDirectory();
    final configFile = File(path.join(configPath, configFileName));
    final contents = await configFile.readAsString();
    final jsonConfig = jsonDecode(contents);
    if (jsonConfig['textPositions'] != null) {
      final positionsJson = jsonConfig['textPositions'] as Map;
      textPositions = {};
      positionsJson.forEach((key, value) {
        textPositions[key] = Map<String, double>.from(value);
      });
    }
  }
}