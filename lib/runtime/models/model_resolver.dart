import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models_provision/model_paths.dart';
import 'model_definition.dart';

final modelResolverProvider = Provider<ModelResolver>((ref) {
  return ModelResolver();
});

class ModelResolver {
  Future<File> resolve(
      ModelDefinition model,
      ) async {
    final file = await ModelPaths.fileFor(
      model.localPath,
    );

    if (!await file.exists()) {
      throw Exception(
        'Model not installed: ${model.id}',
      );
    }

    return file;
  }
}