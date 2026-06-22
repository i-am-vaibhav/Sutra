import 'package:flutter/material.dart';
import 'package:sutra/app/theme/app_theme.dart';

/// A consistent card row used for settings toggles and info display.
///
/// Renders: [icon] + [title]/[subtitle] column + optional [trailing] widget.
/// Used across settings screens to eliminate duplicated Card+Row+Column patterns.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool isActive;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle(context)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.label(context)),
                ],
              ),
            ),
            if (trailing != null) ...[trailing!],
          ],
        ),
      ),
    );
  }
}

/// A consistent section header with optional description text.
class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionHeader(context)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: AppTextStyles.subtitle(context)),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// A consistent info warning banner shown below settings toggles.
class SettingsWarning extends StatelessWidget {
  final String message;
  final IconData icon;

  const SettingsWarning({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSmall(context).copyWith(
                color: cs.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
