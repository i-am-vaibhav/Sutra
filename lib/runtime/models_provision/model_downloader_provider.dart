import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model_downloader.dart';

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  return ModelDownloader();
});