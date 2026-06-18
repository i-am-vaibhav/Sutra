import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/orchestration/message_stream_controller.dart';

void main() {
  group('MessageStreamController', () {
    test('feed accumulates tokens and calls onToken', () {
      final tokens = <String>[];
      final controller = MessageStreamController(
        onToken: (t) => tokens.add(t),
        onComplete: (_) {},
      );
      controller.feed('Hello');
      controller.feed(' ');
      controller.feed('World');
      expect(tokens, ['Hello', 'Hello ', 'Hello World']);
    });

    test('complete calls onComplete with full buffer', () {
      String? result;
      final controller = MessageStreamController(
        onToken: (_) {},
        onComplete: (t) => result = t,
      );
      controller.feed('Hello');
      controller.feed(' World');
      controller.complete();
      expect(result, 'Hello World');
    });

    test('complete with no tokens returns empty string', () {
      String? result;
      final controller = MessageStreamController(
        onToken: (_) {},
        onComplete: (t) => result = t,
      );
      controller.complete();
      expect(result, '');
    });
  });
}
