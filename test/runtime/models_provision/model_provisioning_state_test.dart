import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_state.dart';

void main() {
  group('ModelProvisioningState', () {
    test('empty factory creates empty state', () {
      final s = ModelProvisioningState.empty();
      expect(s.installed, isEmpty);
      expect(s.downloading, isEmpty);
      expect(s.failed, isEmpty);
      expect(s.progress, isEmpty);
      expect(s.retryAttempts, isEmpty);
    });

    test('copyWith preserves fields', () {
      final s = ModelProvisioningState(
        progress: {'a': 0.5},
        downloading: {'a'},
        installed: {'b'},
        failed: {},
        retryAttempts: {},
      );
      final s2 = s.copyWith();
      expect(s2.installed, contains('b'));
      expect(s2.downloading, contains('a'));
    });

    test('copyWith overrides fields', () {
      final s = ModelProvisioningState.empty();
      final s2 = s.copyWith(installed: {'x'}, progress: {'x': 1.0});
      expect(s2.installed, contains('x'));
      expect(s2.progress['x'], 1.0);
    });
  });
}
