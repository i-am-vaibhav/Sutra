import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/models/model_policy.dart';
import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';

void main() {
  group('ModelDefinition', () {
    test('constructor sets all fields', () {
      const model = ModelDefinition(
        id: 'test-id',
        name: 'Test Model',
        size: ModelSize.small,
        contextLength: 2048,
        downloadUrl: 'https://example.com/model.gguf',
        localPath: 'model.gguf',
        chatTemplate: QwenChatTemplate(),
      );
      expect(model.id, 'test-id');
      expect(model.name, 'Test Model');
      expect(model.size, ModelSize.small);
      expect(model.contextLength, 2048);
      expect(model.downloadUrl, 'https://example.com/model.gguf');
      expect(model.localPath, 'model.gguf');
      expect(model.chatTemplate, isA<QwenChatTemplate>());
    });

    test('defaults chatTemplate to GenericChatTemplate', () {
      const model = ModelDefinition(
        id: 'test',
        name: 'Test',
        size: ModelSize.tiny,
        contextLength: 1024,
        downloadUrl: 'https://example.com',
        localPath: 'test.gguf',
      );
      expect(model.chatTemplate, isA<GenericChatTemplate>());
    });

    test('ModelSize enum has all expected values', () {
      expect(ModelSize.values, containsAll([
        ModelSize.tiny,
        ModelSize.small,
        ModelSize.medium,
        ModelSize.large,
      ]));
      expect(ModelSize.values.length, 4);
    });
  });

  group('ModelRegistry', () {
    test('all list is not empty', () {
      expect(ModelRegistry.all, isNotEmpty);
    });

    test('all list contains expected number of models', () {
      expect(ModelRegistry.all.length, 10);
    });

    test('each model has a unique id', () {
      final ids = ModelRegistry.all.map((m) => m.id).toSet();
      expect(ids.length, ModelRegistry.all.length);
    });

    test('each model has a non-empty name', () {
      for (final model in ModelRegistry.all) {
        expect(model.name, isNotEmpty);
      }
    });

    test('each model has a valid downloadUrl', () {
      for (final model in ModelRegistry.all) {
        expect(model.downloadUrl, startsWith('https://'));
      }
    });

    test('each model has a non-empty localPath', () {
      for (final model in ModelRegistry.all) {
        expect(model.localPath, isNotEmpty);
      }
    });

    test('qwen3_0_6b is tiny size', () {
      expect(ModelRegistry.qwen3_0_6b.size, ModelSize.tiny);
    });

    test('qwen3_1_7b is small size', () {
      expect(ModelRegistry.qwen3_1_7b.size, ModelSize.small);
    });

    test('llama32_1b is small size', () {
      expect(ModelRegistry.llama32_1b.size, ModelSize.small);
    });

    test('phi4Mini is medium size', () {
      expect(ModelRegistry.phi4Mini.size, ModelSize.medium);
    });

    test('qwen3_4b is medium size', () {
      expect(ModelRegistry.qwen3_4b.size, ModelSize.medium);
    });

    test('all models have chatTemplate assigned', () {
      for (final model in ModelRegistry.all) {
        expect(model.chatTemplate, isNotNull);
      }
    });

    test('models have reasonable context lengths', () {
      for (final model in ModelRegistry.all) {
        expect(model.contextLength, greaterThanOrEqualTo(1024));
        expect(model.contextLength, lessThanOrEqualTo(32768));
      }
    });
  });

  group('ModelPolicy', () {
    test('returns exactly 2 models for any tier', () {
      for (final tier in DeviceTier.values) {
        final models = ModelPolicy.required(tier);
        expect(models.length, 2, reason: 'Expected 2 models for $tier');
      }
    });

    test('includes tiny chat model (qwen3-0.6b)', () {
      final models = ModelPolicy.required(DeviceTier.low);
      final ids = models.map((m) => m.id).toSet();
      expect(ids, contains('qwen3-0.6b'));
    });

    test('includes web search model (gemma-3-1b-it)', () {
      final models = ModelPolicy.required(DeviceTier.low);
      final ids = models.map((m) => m.id).toSet();
      expect(ids, contains('gemma-3-1b-it'));
    });

    test('web search model has ≥8K context', () {
      final models = ModelPolicy.required(DeviceTier.low);
      final searchModel = models.firstWhere((m) => m.id == 'gemma-3-1b-it');
      expect(searchModel.contextLength, greaterThanOrEqualTo(8192));
    });
  });
}
