import 'dart:async';

import 'package:sutra/runtime/llm/llm_runtime.dart';

class FakeLlmRuntime implements LlmRuntime {
  @override
  Stream<String> generateStream(String prompt) async* {
    final response = "Sutra streaming response to: $prompt";

    for (final word in response.split(' ')) {
      await Future.delayed(const Duration(milliseconds: 120));
      yield "$word ";
    }
  }
}