import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models_provision/model_store.dart';

final modelStoreProvider = Provider<ModelStore>((ref) {
  return ModelStore();
});