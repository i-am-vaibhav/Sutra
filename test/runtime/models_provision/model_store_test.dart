import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/models_provision/model_store.dart';

void main() {
  group('ModelStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadInstalled returns empty set when nothing saved', () async {
      final store = ModelStore();
      final result = await store.loadInstalled();
      expect(result, isEmpty);
    });

    test('saveInstalled persists models', () async {
      final store = ModelStore();
      await store.saveInstalled({'model-a', 'model-b'});
      final result = await store.loadInstalled();
      expect(result, containsAll(['model-a', 'model-b']));
    });

    test('saveInstalled overwrites previous', () async {
      final store = ModelStore();
      await store.saveInstalled({'old-model'});
      await store.saveInstalled({'new-model'});
      final result = await store.loadInstalled();
      expect(result, contains('new-model'));
      expect(result, isNot(contains('old-model')));
    });

    test('saveInstalled with empty set clears data', () async {
      final store = ModelStore();
      await store.saveInstalled({'model-a'});
      await store.saveInstalled({});
      final result = await store.loadInstalled();
      expect(result, isEmpty);
    });
  });
}
