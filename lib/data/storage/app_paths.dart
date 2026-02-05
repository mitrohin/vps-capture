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
}
