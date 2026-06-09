class ModelQueue {
  final Set<String> _queue = {};

  void add(String modelId) => _queue.add(modelId);

  void remove(String modelId) => _queue.remove(modelId);

  bool contains(String modelId) => _queue.contains(modelId);

  List<String> get items => _queue.toList();
}