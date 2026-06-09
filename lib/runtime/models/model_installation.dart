import 'package:sutra/runtime/models_provision/model_paths.dart';

import 'model_definition.dart';

class ModelInstallation {
  static Future<bool> isInstalled(
      ModelDefinition model,
      ) async {
    final file = await ModelPaths.fileFor(
      model.localPath,
    );

    return file.exists();
  }
}