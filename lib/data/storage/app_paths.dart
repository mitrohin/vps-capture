import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  Future<Directory> appSupportDir() async {
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

  static List<String> getLegacyScheduleDirectories() {
    final directories = <String>{};
    directories.add(getExecutableDirectory());
    directories.add(Directory(Platform.executable).parent.path);

    if (!Platform.isMacOS) {
      return directories.toList(growable: false);
    }

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
    final resolvedDir = _resolveUserDataDirectory();
    final dir = Directory(p.join(resolvedDir, 'gym_capture'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  static String _resolveUserDataDirectory() {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Library', 'Application Support');
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return appData;
      }

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return localAppData;
      }

      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'AppData', 'Roaming');
      }
    } else {
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
        return xdgDataHome;
      }

      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, '.local', 'share');
      }
    }

    return Directory.systemTemp.path;
  }
}
