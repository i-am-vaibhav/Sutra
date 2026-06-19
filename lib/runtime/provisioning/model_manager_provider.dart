import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';

/// Central ModelManager provider — the single source of truth for model lifecycle.
final modelManagerProvider = Provider<ModelManager>((ref) {
  final manager = ModelManager(database: ModelDatabase());
  ref.onDispose(() => manager.dispose());
  return manager;
});
