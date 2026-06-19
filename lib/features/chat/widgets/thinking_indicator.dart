import 'package:flutter/material.dart';
import 'package:sutra/features/chat/chat_message.dart';

/// Animated "Thinking…" indicator shown inside the assistant message bubble
/// while waiting for the first token from the model.
class ThinkingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  /// When true, dots cycle faster to indicate active token generation.
  final bool isActive;

  const ThinkingIndicator({super.key, required this.colorScheme, this.isActive = false});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _textFade;
  int _dotCount = 1;

  /// Slow speed (waiting for first token).
  static const _slowDotDuration = Duration(milliseconds: 600);
  static const _slowPulseDuration = Duration(milliseconds: 1200);

  /// Fast speed (tokens actively arriving).
  static const _fastDotDuration = Duration(milliseconds: 250);
  static const _fastPulseDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: _slowDotDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _fadeController.reverse().then((_) {
            if (!mounted) return;
            setState(() {
              _dotCount = _dotCount >= 3 ? 1 : _dotCount + 1;
            });
            _fadeController.forward();
          });
          _dotController.repeat();
        }
      });
    _dotController.forward();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.value = 1.0;

    _pulseController = AnimationController(
      vsync: this,
      duration: _slowPulseDuration,
    );
    _pulseAnimation = Tween<double>(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _updateSpeed(widget.isActive);
    }
  }

  void _updateSpeed(bool active) {
    final dotDuration = active ? _fastDotDuration : _slowDotDuration;
    final pulseDuration = active ? _fastPulseDuration : _slowPulseDuration;
    _dotController.duration = dotDuration;
    _pulseController.duration = pulseDuration;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _textFade]),
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: _pulseAnimation.value),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: _textFade.value,
                child: Text(
                  'Thinking${'.' * _dotCount}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onPrimaryContainer,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

/// Action chips row shown below completed assistant messages.
class MessageActions extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme colorScheme;
  final VoidCallback onCopy;
  final VoidCallback onReadAloud;
  final VoidCallback onStopReading;
  final bool isSpeaking;

  const MessageActions({
    super.key,
    required this.message,
    required this.colorScheme,
    required this.onCopy,
    required this.onReadAloud,
    required this.onStopReading,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ActionChip(
            icon: Icons.copy,
            label: 'Copy',
            onTap: onCopy,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: isSpeaking ? Icons.stop_circle : Icons.volume_up,
            label: isSpeaking ? 'Stop' : 'Read aloud',
            onTap: isSpeaking ? onStopReading : onReadAloud,
            colorScheme: colorScheme,
            isActive: isSpeaking,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isActive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? colorScheme.primary : colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
