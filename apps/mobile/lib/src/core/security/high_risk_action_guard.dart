import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/app_feedback.dart';
import 'app_lock_controller.dart';

Future<bool> authorizeHighRiskAction(
  BuildContext context,
  WidgetRef ref, {
  required String biometricReason,
  required String pinPrompt,
  String cancelledMessage = 'Action cancelled.',
}) async {
  final appLockState = ref.read(appLockStateProvider);
  final appLockController = ref.read(appLockControllerProvider);

  if (appLockState.canUseBiometrics) {
    final authorized = await appLockController.authenticateBiometric(
      localizedReason: biometricReason,
    );
    if (authorized) {
      return true;
    }
  }

  if (appLockState.canUsePin) {
    if (!context.mounted) {
      return false;
    }

    final pin = await _promptForPin(context, message: pinPrompt);
    if (pin == null) {
      if (context.mounted) {
        showAppSnackBar(context, message: cancelledMessage);
      }
      return false;
    }

    final valid = await appLockController.verifyPin(pin);
    if (valid) {
      return true;
    }

    if (context.mounted) {
      showAppSnackBar(
        context,
        message: 'The app PIN is incorrect.',
        tone: AppFeedbackTone.warning,
      );
    }
    return false;
  }

  if (appLockState.canUseBiometrics && context.mounted) {
    showAppSnackBar(
      context,
      message: 'Biometric approval did not complete.',
      tone: AppFeedbackTone.warning,
    );
    return false;
  }

  return true;
}

Future<String?> _promptForPin(
  BuildContext context, {
  required String message,
}) async {
  final controller = TextEditingController();

  final pin = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm app PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(labelText: 'App PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  controller.dispose();
  if (pin == null || pin.isEmpty) {
    return null;
  }
  return pin;
}
