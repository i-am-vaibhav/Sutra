import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelPaths {
  static Future<Directory> modelsDirectory() async {
    final root =
    await getApplicationDocumentsDirectory();

    final dir = Directory(
      p.join(root.path, 'models'),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  static Future<File> fileFor(
      String relativePath,
      ) async {
    final dir = await modelsDirectory();

    return File(
      p.join(
        dir.path,
        relativePath,
      ),
    );
  }
}