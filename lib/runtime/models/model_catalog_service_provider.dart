import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_catalog_service.dart';

/// Singleton provider for the model catalog service.
final modelCatalogServiceProvider = Provider<ModelCatalogService>((ref) {
  return ModelCatalogService();
});
