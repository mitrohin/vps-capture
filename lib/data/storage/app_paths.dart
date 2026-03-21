import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  Future<Directory> appSupportDir() async {
    if (Platform.isWindows) {
      final dir = Directory(p.join(getExecutableDirectory(), 'gym_capture_data'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'gym_capture'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> binDir() async {
    final dir = Directory(p.join((await appSupportDir()).path, 'bin'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> segmentsDir() async {
    final dir = Directory(p.join((await appSupportDir()).path, 'segments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> concatListFile() async {
    return File(p.join((await appSupportDir()).path, 'concat_list.txt'));
  }

  static String getExecutableDirectory() {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = Directory(executablePath).parent.path;
    return executableDir;
  }

  static List<String> getMacOSLegacyScheduleDirectories() {
    if (!Platform.isMacOS) {
      return const [];
    }

    final directories = <String>{};
    directories.add(Directory(Platform.resolvedExecutable).parent.path);
    directories.add(Directory(Platform.executable).parent.path);

    for (final executablePath in [Platform.resolvedExecutable, Platform.executable]) {
      final appIndex = executablePath.indexOf('.app/Contents/');
      if (appIndex == -1) continue;

      final appRootPath = executablePath.substring(0, appIndex + 4);
      final bundleMacOSPath = p.join(appRootPath, 'Contents', 'MacOS');
      directories.add(bundleMacOSPath);
    }

    return directories.toList(growable: false);
  }

  static String getScheduleStorageDirectory() {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final appSupportDir = Directory(
          p.join(home, 'Library', 'Application Support', 'gym_capture'),
        );
        if (!appSupportDir.existsSync()) {
          appSupportDir.createSync(recursive: true);
        }
        return appSupportDir.path;
      }

      final fallbackDir = Directory(
        p.join(Directory.systemTemp.path, 'gym_capture'),
      );
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      return fallbackDir.path;
    }

    return getExecutableDirectory();
  }
}
