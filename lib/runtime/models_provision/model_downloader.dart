import 'package:dio/dio.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'model_paths.dart';

class ModelDownloader {
  final Dio _dio = Dio();

  Future<void> download({
    required ModelDefinition model,
    required void Function(double progress) onProgress,
  }) async {
    final file = await ModelPaths.fileFor(
      model.localPath,
    );

    await _dio.download(
      model.downloadUrl,
      file.path,
      deleteOnError: true,
      onReceiveProgress: (
          received,
          total,
          ) {
        if (total <= 0) return;

        onProgress(
          received / total,
        );
      },
    );
  }
}