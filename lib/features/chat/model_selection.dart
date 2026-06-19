import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';

/// Select the best model for a prompt based on its characteristics.
///
/// Rules:
/// - Files attached → largest installed model with ≥4096 ctx
/// - Long/complex messages (>200 chars) → largest installed model
/// - Short messages → smallest installed model (fast response)
/// - Always prefers the biggest available model if only one is installed
String? selectBestModel(Ref ref, {required bool hasFiles, required int msgLength}) {
  final manager = ref.read(modelManagerProvider);
  final installed = manager.state.installedIds;
  if (installed.isEmpty) return null;

  final candidates = ModelRegistry.all
      .where((m) => installed.contains(m.id))
      .toList()
    ..sort((a, b) => b.contextLength.compareTo(a.contextLength));

  // Only one model installed — use it.
  if (candidates.length == 1) return candidates.first.id;

  // Files or long messages → use the biggest model.
  if (hasFiles || msgLength > 200) {
    return candidates.first.id;
  }

  // Short simple message → use a small/fast model.
  final small = candidates.lastWhere(
    (m) => m.contextLength <= 4096,
    orElse: () => candidates.last,
  );
  return small.id;
}
