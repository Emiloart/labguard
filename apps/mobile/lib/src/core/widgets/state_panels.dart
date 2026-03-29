import 'package:flutter/material.dart';

import '../errors/user_facing_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import 'app_panel.dart';
import 'panel_header.dart';

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({
    super.key,
    required this.label,
    this.message = 'Preparing the latest trusted state for this view.',
  });

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label. Loading.',
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelHeader(title: label, subtitle: message),
            const SizedBox(height: AppMetrics.contentGap),
            const LinearProgressIndicator(minHeight: 4),
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Unable to load this view',
    this.actionLabel = 'Try again',
  });

  final String message;
  final VoidCallback onRetry;
  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final displayMessage = userFacingErrorMessage(
      message,
      fallback: 'This view could not be refreshed.',
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            title: title,
            subtitle: displayMessage,
            trailing: const Icon(
              Icons.error_outline,
              color: LabGuardColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try again in a moment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppMetrics.contentGap),
          FilledButton.tonal(onPressed: onRetry, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LabGuardColors.accent),
          const SizedBox(height: AppMetrics.denseGap),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppMetrics.contentGap),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
