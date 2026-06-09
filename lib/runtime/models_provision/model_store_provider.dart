import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model_store.dart';

final modelStoreProvider = Provider<ModelStore>((ref) {
  return ModelStore();
});