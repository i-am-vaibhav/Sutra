class MessageStreamController {
  final void Function(String token) onToken;
  final void Function(String finalText) onComplete;

  MessageStreamController({
    required this.onToken,
    required this.onComplete,
  });

  String _buffer = "";

  void feed(String token) {
    _buffer += token;
    onToken(_buffer);
  }

  void complete() {
    onComplete(_buffer);
  }
}