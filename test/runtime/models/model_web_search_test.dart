import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';

void main() {
  group('ModelCapability.webSearch', () {
    test('gemma3_1b has webSearch capability', () {
      expect(ModelRegistry.gemma3_1b.supports(ModelCapability.webSearch), isTrue);
    });

    test('qwen3_4b has webSearch capability', () {
      expect(ModelRegistry.qwen3_4b.supports(ModelCapability.webSearch), isTrue);
    });

    test('phi4Mini has webSearch capability', () {
      expect(ModelRegistry.phi4Mini.supports(ModelCapability.webSearch), isTrue);
    });

    test('gemma3_4b has webSearch capability', () {
      expect(ModelRegistry.gemma3_4b.supports(ModelCapability.webSearch), isTrue);
    });

    test('smolLM3 has webSearch capability', () {
      expect(ModelRegistry.smolLM3.supports(ModelCapability.webSearch), isTrue);
    });

    test('ministral3b has webSearch capability', () {
      expect(ModelRegistry.ministral3b.supports(ModelCapability.webSearch), isTrue);
    });

    test('qwen3_0_6b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.qwen3_0_6b.supports(ModelCapability.webSearch), isFalse);
    });

    test('qwen3_1_7b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.qwen3_1_7b.supports(ModelCapability.webSearch), isFalse);
    });

    test('llama32_1b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.llama32_1b.supports(ModelCapability.webSearch), isFalse);
    });

    test('llama32_3b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.llama32_3b.supports(ModelCapability.webSearch), isFalse);
    });

    test('qwen25Coder_3b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.qwen25Coder_3b.supports(ModelCapability.webSearch), isFalse);
    });

    test('models with ≥8K context always have webSearch capability', () {
      for (final model in ModelRegistry.all) {
        if (model.contextLength >= 8192) {
          expect(
            model.supports(ModelCapability.webSearch),
            isTrue,
            reason: '${model.id} has ${model.contextLength} ctx but lacks webSearch',
          );
        }
      }
    });

    test('models with <8K context never have webSearch capability', () {
      for (final model in ModelRegistry.all) {
        if (model.contextLength < 8192) {
          expect(
            model.supports(ModelCapability.webSearch),
            isFalse,
            reason: '${model.id} has ${model.contextLength} ctx but has webSearch',
          );
        }
      }
    });
  });

  group('ModelDefinition.supports()', () {
    test('returns true for capability in set', () {
      const model = ModelDefinition(
        id: 'test',
        name: 'Test',
        size: ModelSize.small,
        contextLength: 8192,
        downloadUrl: 'https://example.com',
        localPath: 'test.gguf',
        capabilities: {ModelCapability.webSearch},
      );
      expect(model.supports(ModelCapability.webSearch), isTrue);
    });

    test('returns false for capability not in set', () {
      const model = ModelDefinition(
        id: 'test',
        name: 'Test',
        size: ModelSize.small,
        contextLength: 4096,
        downloadUrl: 'https://example.com',
        localPath: 'test.gguf',
      );
      expect(model.supports(ModelCapability.webSearch), isFalse);
    });

    test('empty capabilities set returns false for all', () {
      const model = ModelDefinition(
        id: 'test',
        name: 'Test',
        size: ModelSize.tiny,
        contextLength: 1024,
        downloadUrl: 'https://example.com',
        localPath: 'test.gguf',
        capabilities: <ModelCapability>{},
      );
      expect(model.supports(ModelCapability.webSearch), isFalse);
      expect(model.supports(ModelCapability.fileAnalysis), isFalse);
    });
  });

  group('ModelCapability enum', () {
    test('has webSearch and fileAnalysis values', () {
      expect(ModelCapability.values, contains(ModelCapability.webSearch));
      expect(ModelCapability.values, contains(ModelCapability.fileAnalysis));
      expect(ModelCapability.values.length, 2);
    });
  });

  group('Web search model count', () {
    test('exactly 6 out of 10 models have webSearch capability', () {
      final webSearchModels = ModelRegistry.all
          .where((m) => m.supports(ModelCapability.webSearch))
          .toList();
      expect(webSearchModels.length, 6);
    });

    test('web search models span small and medium size tiers', () {
      final webSearchModels = ModelRegistry.all
          .where((m) => m.supports(ModelCapability.webSearch))
          .toList();
      final sizes = webSearchModels.map((m) => m.size).toSet();
      expect(sizes, contains(ModelSize.small));
      expect(sizes, contains(ModelSize.medium));
    });

    test('qwen3_0_6b is the auto-downloaded tiny chat model (no web search)', () {
      expect(ModelRegistry.qwen3_0_6b.size, ModelSize.tiny);
      expect(ModelRegistry.qwen3_0_6b.supports(ModelCapability.webSearch), isFalse);
    });

    test('gemma3_1b is the auto-downloaded web search model', () {
      expect(ModelRegistry.gemma3_1b.size, ModelSize.small);
      expect(ModelRegistry.gemma3_1b.supports(ModelCapability.webSearch), isTrue);
      expect(ModelRegistry.gemma3_1b.contextLength, 8192);
    });
  });

  group('Custom model with mixed capabilities', () {
    test('model with webSearch and fileAnalysis supports both', () {
      const model = ModelDefinition(
        id: 'multi',
        name: 'Multi-Cap Model',
        size: ModelSize.medium,
        contextLength: 8192,
        downloadUrl: 'https://example.com',
        localPath: 'multi.gguf',
        capabilities: {ModelCapability.webSearch, ModelCapability.fileAnalysis},
      );
      expect(model.supports(ModelCapability.webSearch), isTrue);
      expect(model.supports(ModelCapability.fileAnalysis), isTrue);
    });

    test('model with only fileAnalysis does not support webSearch', () {
      const model = ModelDefinition(
        id: 'file-only',
        name: 'File Model',
        size: ModelSize.small,
        contextLength: 4096,
        downloadUrl: 'https://example.com',
        localPath: 'file.gguf',
        capabilities: {ModelCapability.fileAnalysis},
      );
      expect(model.supports(ModelCapability.webSearch), isFalse);
      expect(model.supports(ModelCapability.fileAnalysis), isTrue);
    });
  });
}
