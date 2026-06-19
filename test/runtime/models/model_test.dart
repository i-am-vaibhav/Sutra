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

    test('all list contains 8 models', () {
      expect(ModelRegistry.all.length, 8);
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

    test('micro model is tiny size', () {
      expect(ModelRegistry.micro.size, ModelSize.tiny);
    });

    test('tiny model is small size', () {
      expect(ModelRegistry.tiny.size, ModelSize.small);
    });

    test('llama32_1b is tiny size', () {
      expect(ModelRegistry.llama32_1b.size, ModelSize.tiny);
    });

    test('phi3Mini is medium size', () {
      expect(ModelRegistry.phi3Mini.size, ModelSize.medium);
    });

    test('medium model is medium size', () {
      expect(ModelRegistry.medium.size, ModelSize.medium);
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
    test('low tier returns micro and tiny models', () {
      final models = ModelPolicy.required(DeviceTier.low);
      expect(models.length, 2);
      expect(models.map((m) => m.id), containsAll(['qwen2.5-0.5b', 'tinyllama-1.1b']));
    });

    test('mid tier returns 4 models', () {
      final models = ModelPolicy.required(DeviceTier.mid);
      expect(models.length, 4);
    });

    test('mid tier includes tiny, small, gemma2b, llama32_1b', () {
      final models = ModelPolicy.required(DeviceTier.mid);
      final ids = models.map((m) => m.id).toSet();
      expect(ids, containsAll([
        'tinyllama-1.1b',
        'qwen2.5-1.5b',
        'gemma-2-2b-it',
        'llama-3.2-1b-instruct',
      ]));
    });

    test('high tier returns all 8 models', () {
      final models = ModelPolicy.required(DeviceTier.high);
      expect(models.length, 8);
    });

    test('high tier includes all registry models', () {
      final models = ModelPolicy.required(DeviceTier.high);
      final ids = models.map((m) => m.id).toSet();
      final registryIds = ModelRegistry.all.map((m) => m.id).toSet();
      expect(ids, equals(registryIds));
    });

    test('low tier has fewer models than mid tier', () {
      final low = ModelPolicy.required(DeviceTier.low);
      final mid = ModelPolicy.required(DeviceTier.mid);
      expect(low.length, lessThan(mid.length));
    });

    test('mid tier has fewer models than high tier', () {
      final mid = ModelPolicy.required(DeviceTier.mid);
      final high = ModelPolicy.required(DeviceTier.high);
      expect(mid.length, lessThan(high.length));
    });
  });
}
