import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:llamadart/llamadart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Model Response Integration Test', () {
    late LlamaEngine engine;
    late String modelPath;

    setUpAll(() async {
      // Find a GGUF model in the app's documents directory.
      // The model must be pushed via `run-as` before running this test.
      String? foundPath;

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final modelsDir = Directory(p.join(appDir.path, 'models'));
        if (await modelsDir.exists()) {
          final files = modelsDir.listSync().whereType<File>().toList();
          final ggufFiles =
              files.where((f) => f.path.endsWith('.gguf')).toList();
          if (ggufFiles.isNotEmpty) {
            foundPath = ggufFiles.first.path;
            print('Found model: $foundPath');
          }
        }
      } catch (e) {
        print('Error locating model: $e');
      }

      if (foundPath == null) {
        fail(
          'No .gguf model found in app directory.\n'
          'Setup steps:\n'
          '  1. adb install -r build/app/outputs/flutter-apk/app-debug.apk\n'
          '  2. adb push model.gguf /data/local/tmp/model.gguf\n'
          '  3. adb shell run-as <package> sh -c "cat /data/local/tmp/model.gguf > '
          '<app_dir>/app_flutter/models/model.gguf"\n'
          '  4. flutter test integration_test/ -d <device>',
        );
      }

      modelPath = foundPath;
      final fileSize = await File(modelPath).length();
      print(
        'Using model: $modelPath (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
    });

    tearDownAll(() async {
      try {
        await engine.dispose();
      } catch (_) {}
    });

    test('Model loads successfully', () async {
      engine = LlamaEngine(LlamaBackend());
      final stopwatch = Stopwatch()..start();
      await engine.loadModel(modelPath);
      stopwatch.stop();

      print('Model loaded in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Model responds to "capital of India"', () async {
      final stopwatch = Stopwatch()..start();
      final responseBuffer = StringBuffer();

      await for (final token in engine.generate(
        'What is the capital of India? Answer in one word.',
      )) {
        responseBuffer.write(token);
      }
      stopwatch.stop();

      final response = responseBuffer.toString();
      print('Response: "$response"');
      print('Generation time: ${stopwatch.elapsedMilliseconds}ms');

      expect(response, isNotEmpty, reason: 'Response should not be empty');

      final lowerResponse = response.toLowerCase();
      final containsDelhi = lowerResponse.contains('delhi');
      print('Contains "Delhi": $containsDelhi');

      expect(
        containsDelhi,
        true,
        reason: 'Response should mention "Delhi". Got: $response',
      );
    });

    test('Multiple generations work sequentially', () async {
      final buffer1 = StringBuffer();
      await for (final token in engine.generate('Say hello.')) {
        buffer1.write(token);
      }
      final response1 = buffer1.toString();
      print('Response 1: "$response1"');

      final buffer2 = StringBuffer();
      await for (final token in engine.generate('Say goodbye.')) {
        buffer2.write(token);
      }
      final response2 = buffer2.toString();
      print('Response 2: "$response2"');

      expect(response1, isNotEmpty);
      expect(response2, isNotEmpty);
    });
  });
}
