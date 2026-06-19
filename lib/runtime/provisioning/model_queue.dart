/// An ordered download queue that processes models one at a time.
///
/// Supports priority insertion (for retries) so that retried
/// downloads jump to the front of the line.
class ModelQueue {
  final List<String> _queue = [];

  /// Add a model to the **back** of the queue (normal provisioning).
  void add(String modelId) {
    if (!_queue.contains(modelId)) {
      _queue.add(modelId);
    }
  }

  /// Add a model to the **front** of the queue (retry / priority).
  void addFirst(String modelId) {
    _queue.remove(modelId);
    _queue.insert(0, modelId);
  }

  void remove(String modelId) => _queue.remove(modelId);

  bool contains(String modelId) => _queue.contains(modelId);

  /// The next model to download, or `null` if the queue is empty.
  String? get next => _queue.isEmpty ? null : _queue.first;

  int get length => _queue.length;

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;

  List<String> get items => List.unmodifiable(_queue);
}
