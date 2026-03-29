import 'package:flutter/material.dart';

import '../errors/user_facing_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

enum AppFeedbackTone { info, success, warning, danger }

void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppFeedbackTone tone = AppFeedbackTone.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final (icon, color) = switch (tone) {
    AppFeedbackTone.info => (Icons.info_outline, LabGuardColors.accent),
    AppFeedbackTone.success => (
      Icons.verified_outlined,
      LabGuardColors.success,
    ),
    AppFeedbackTone.warning => (
      Icons.warning_amber_rounded,
      LabGuardColors.warning,
    ),
    AppFeedbackTone.danger => (Icons.error_outline, LabGuardColors.danger),
  };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LabGuardColors.panelElevated,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      content: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LabGuardColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String describeError(
  Object error, {
  String fallback = 'Unable to complete that action right now.',
}) {
  return userFacingErrorMessage(error, fallback: fallback);
}
