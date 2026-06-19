import 'package:flutter/material.dart';
import 'package:sutra/runtime/models/model_definition.dart';

/// Small badge showing a model capability (e.g. "🔍 Web Search").
class CapabilityBadge extends StatelessWidget {
  final ModelCapability capability;

  const CapabilityBadge({super.key, required this.capability});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label, color) = _forCapability(capability, cs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _forCapability(
    ModelCapability cap,
    ColorScheme cs,
  ) {
    return switch (cap) {
      ModelCapability.webSearch => (Icons.language, 'Web Search', cs.tertiary),
      ModelCapability.fileAnalysis => (Icons.attach_file, 'Files', cs.secondary),
    };
  }
}
