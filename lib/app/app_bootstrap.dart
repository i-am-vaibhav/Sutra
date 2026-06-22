import 'package:sutra/core/feature_flags.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/app/app.dart';
import 'package:sutra/app/bootstrap.dart';
import 'package:sutra/runtime/llm/llama_cpp_runtime.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/provisioning/model_update_provider.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    Future.microtask(() async {
      await bootstrapModels(ref);
      // Start daily model update checks after provisioning is complete.
      ref.read(modelUpdateProvider.notifier).init();
    });
    // v1: Preload runtime in background (warm-up gated by FeatureFlag.modelWarmUp)
    _preloadRuntimeIfNeeded(ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Best-effort cleanup when the app is killed. The runtimeProvider's
      // ref.onDispose handles model switches; this covers process death.
      ref.read(runtimeProvider.future).then((rm) async {
        if (rm.llm is LlamaCppRuntime) {
          await (rm.llm as LlamaCppRuntime).dispose();
        }
      }).catchError((e) {
        Log.d('[AppBootstrap] Failed to dispose runtime on detach: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SutraApp();
  }
}

/// Preload runtime in background. Warm-up generation is gated by
/// [FeatureFlag.modelWarmUp] — when off (v1 default), the model is loaded
/// but no warm-up prompt is sent, saving 2-5s on startup.
Future<void> _preloadRuntimeIfNeeded(WidgetRef ref) async {
  try {
    final runtime = await ref.read(runtimeProvider.future);
    final flags = ref.read(featureFlagsProvider);
    if (runtime.isReady && flags.isEnabled(FeatureFlag.modelWarmUp)) {
      Log.d('[AppBootstrap] Warm-up enabled — sending warm-up prompt');
      await for (final _ in runtime.generateStream('Hi')) {
        // Discard tokens — only trigger JIT/AOT compilation.
      }
      Log.d('[AppBootstrap] Warm-up completed');
    } else if (runtime.isReady) {
      Log.d('[AppBootstrap] Model loaded (warm-up skipped per feature flag)');
    }
  } catch (e) {
    Log.w('[AppBootstrap] Runtime preload failed (non-fatal): $e');
  }
}
