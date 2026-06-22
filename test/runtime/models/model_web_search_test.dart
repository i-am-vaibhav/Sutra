import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';

void main() {
  group('ModelCapability.webSearch', () {
    test('qwen35_4b has webSearch capability (8K ctx)', () {
      expect(ModelRegistry.qwen35_4b.supports(ModelCapability.webSearch), isTrue);
    });

    test('qwen35_0_8b does NOT have webSearch capability (4K ctx)', () {
      expect(ModelRegistry.qwen35_0_8b.supports(ModelCapability.webSearch), isFalse);
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

  group('Web search model count (v1: 4 Qwen3.5 models)', () {
    test('3 out of 4 models have webSearch capability', () {
      final webSearchModels = ModelRegistry.all
          .where((m) => m.supports(ModelCapability.webSearch))
          .toList();
      expect(webSearchModels.length, 3);
    });

    test('qwen35_0_8b is the auto-downloaded tiny chat model (no web search)', () {
      expect(ModelRegistry.qwen35_0_8b.size, ModelSize.tiny);
      expect(ModelRegistry.qwen35_0_8b.supports(ModelCapability.webSearch), isFalse);
    });

    test('qwen35_4b is a web search model', () {
      expect(ModelRegistry.qwen35_4b.supports(ModelCapability.webSearch), isTrue);
      expect(ModelRegistry.qwen35_4b.contextLength, 8192);
    });

    test('qwen35_9b is a web search model', () {
      expect(ModelRegistry.qwen35_9b.supports(ModelCapability.webSearch), isTrue);
      expect(ModelRegistry.qwen35_9b.contextLength, 16384);
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
