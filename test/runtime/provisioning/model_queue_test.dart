import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/provisioning/model_queue.dart';

void main() {
  group('ModelQueue', () {
    test('starts empty', () {
      final q = ModelQueue();
      expect(q.isEmpty, true);
      expect(q.length, 0);
      expect(q.next, isNull);
    });

    test('add inserts at back', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      expect(q.items, ['a', 'b']);
    });

    test('add does not duplicate', () {
      final q = ModelQueue();
      q.add('a');
      q.add('a');
      expect(q.length, 1);
    });

    test('addFirst inserts at front', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      q.addFirst('c');
      expect(q.items, ['c', 'a', 'b']);
    });

    test('addFirst moves existing to front', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      q.addFirst('a');
      expect(q.items, ['a', 'b']);
    });

    test('remove removes model', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      q.remove('a');
      expect(q.items, ['b']);
    });

    test('contains checks membership', () {
      final q = ModelQueue();
      q.add('a');
      expect(q.contains('a'), true);
      expect(q.contains('b'), false);
    });

    test('next returns first item', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      expect(q.next, 'a');
    });

    test('items returns unmodifiable list', () {
      final q = ModelQueue();
      q.add('a');
      final items = q.items;
      expect(() => items.add('b'), throwsUnsupportedError);
    });
  });
}
