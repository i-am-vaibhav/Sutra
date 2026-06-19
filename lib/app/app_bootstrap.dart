import 'package:sutra/core/logging/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/app/app.dart';
import 'package:sutra/app/bootstrap.dart';
import 'package:sutra/runtime/llm/llama_cpp_runtime.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';

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
    });
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
