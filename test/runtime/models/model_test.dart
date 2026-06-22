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

    test('all list contains 4 Qwen3.5 models', () {
      expect(ModelRegistry.all.length, 4);
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

    test('qwen35_0_8b is tiny size', () {
      expect(ModelRegistry.qwen35_0_8b.size, ModelSize.tiny);
    });

    test('qwen35_4b is medium size', () {
      expect(ModelRegistry.qwen35_4b.size, ModelSize.medium);
    });

    test('qwen35_9b is large size', () {
      expect(ModelRegistry.qwen35_9b.size, ModelSize.large);
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

    test('all models have fileSizeBytes set', () {
      for (final model in ModelRegistry.all) {
        expect(model.fileSizeBytes, isNotNull);
        expect(model.fileSizeBytes!, greaterThan(0));
      }
    });
  });

  group('ModelPolicy', () {
    test('low tier returns 1 model (0.8B only)', () {
      final models = ModelPolicy.required(DeviceTier.low);
      expect(models.length, 1);
      expect(models.first.id, 'qwen3.5-0.8b');
    });

    test('mid tier returns 2 models (0.8B + 2B)', () {
      final models = ModelPolicy.required(DeviceTier.mid);
      expect(models.length, 2);
      final ids = models.map((m) => m.id).toSet();
      expect(ids, containsAll({'qwen3.5-0.8b', 'qwen3.5-2b'}));
    });

    test('high tier returns 2 models (0.8B + 4B)', () {
      final models = ModelPolicy.required(DeviceTier.high);
      expect(models.length, 2);
      final ids = models.map((m) => m.id).toSet();
      expect(ids, containsAll({'qwen3.5-0.8b', 'qwen3.5-4b'}));
    });

    test('all tiers include the 0.8B model', () {
      for (final tier in DeviceTier.values) {
        final models = ModelPolicy.required(tier);
        final ids = models.map((m) => m.id).toSet();
        expect(ids, contains('qwen3.5-0.8b'),
            reason: 'Tier $tier should include 0.8B');
      }
    });

    test('9B is never auto-provisioned', () {
      for (final tier in DeviceTier.values) {
        final models = ModelPolicy.required(tier);
        final ids = models.map((m) => m.id).toSet();
        expect(ids, isNot(contains('qwen3.5-9b')),
            reason: 'Tier $tier should not auto-provision 9B');
      }
    });
  });
}
