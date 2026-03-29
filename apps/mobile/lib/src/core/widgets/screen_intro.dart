import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class ScreenIntro extends StatelessWidget {
  const ScreenIntro({
    super.key,
    required this.title,
    required this.description,
    this.eyebrow = 'LabGuard',
    this.badge,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppMetrics.maxReadableWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _IntroPill(
                  label: eyebrow.toUpperCase(),
                  color: LabGuardColors.accent,
                  background: LabGuardColors.accentMuted.withValues(
                    alpha: 0.24,
                  ),
                ),
                if (badge != null && badge!.isNotEmpty)
                  _IntroPill(
                    label: badge!,
                    color: LabGuardColors.textPrimary,
                    background: LabGuardColors.panelElevated,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.32,
        ),
      ),
    );
  }
}
