import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/provisioning/model_queue.dart';

void main() {
  group('ModelQueue', () {
    test('add enqueues model at back', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      expect(q.items, ['a', 'b']);
    });

    test('addFirst enqueues model at front', () {
      final q = ModelQueue();
      q.add('a');
      q.addFirst('b');
      expect(q.items, ['b', 'a']);
    });

    test('add deduplicates', () {
      final q = ModelQueue();
      q.add('a');
      q.add('a');
      expect(q.items, ['a']);
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
      expect(q.contains('a'), isTrue);
      expect(q.contains('b'), isFalse);
    });

    test('next returns first or null', () {
      final q = ModelQueue();
      expect(q.next, isNull);
      q.add('a');
      expect(q.next, 'a');
    });

    test('isEmpty and isNotEmpty', () {
      final q = ModelQueue();
      expect(q.isEmpty, isTrue);
      expect(q.isNotEmpty, isFalse);
      q.add('a');
      expect(q.isEmpty, isFalse);
      expect(q.isNotEmpty, isTrue);
    });

    test('addFirst deduplicates and reorders', () {
      final q = ModelQueue();
      q.add('a');
      q.add('b');
      q.addFirst('a');
      expect(q.items, ['a', 'b']);
    });
  });

  group('ModelManagerState', () {
    test('installedIds returns downloaded models', () {
      const state = ModelManagerState(
        modelStates: {
          'm1': ModelState.downloaded,
          'm2': ModelState.downloading,
          'm3': ModelState.downloaded,
        },
      );
      expect(state.installedIds, containsAll(['m1', 'm3']));
      expect(state.installedIds, isNot(contains('m2')));
    });

    test('downloadingIds returns downloading models', () {
      const state = ModelManagerState(
        modelStates: {
          'm1': ModelState.downloading,
          'm2': ModelState.downloaded,
        },
      );
      expect(state.downloadingIds, contains('m1'));
      expect(state.downloadingIds, isNot(contains('m2')));
    });

    test('failedIds returns failed models', () {
      const state = ModelManagerState(
        modelStates: {
          'm1': ModelState.failed,
          'm2': ModelState.downloaded,
        },
      );
      expect(state.failedIds, contains('m1'));
    });

    test('copyWith preserves unchanged fields', () {
      const original = ModelManagerState(
        modelStates: {'m1': ModelState.downloaded},
        progress: {'m1': 1.0},
      );
      final copied = original.copyWith(retryAttempts: {'m1': 2});
      expect(copied.modelStates, original.modelStates);
      expect(copied.progress, original.progress);
      expect(copied.retryAttempts['m1'], 2);
    });

    test('copyWith clearActiveDownload sets null', () {
      const original = ModelManagerState(activeDownloadId: 'm1');
      final cleared = original.copyWith(clearActiveDownload: true);
      expect(cleared.activeDownloadId, isNull);
    });
  });

  group('ModelState enum', () {
    test('has all required states', () {
      expect(ModelState.values.length, 6);
      expect(ModelState.values, contains(ModelState.notDownloaded));
      expect(ModelState.values, contains(ModelState.downloading));
      expect(ModelState.values, contains(ModelState.paused));
      expect(ModelState.values, contains(ModelState.downloaded));
      expect(ModelState.values, contains(ModelState.failed));
      expect(ModelState.values, contains(ModelState.deleted));
    });

    test('state name round-trips correctly', () {
      for (final state in ModelState.values) {
        final restored = ModelState.values.firstWhere(
          (e) => e.name == state.name,
          orElse: () => ModelState.notDownloaded,
        );
        expect(restored, state);
      }
    });
  });
}
