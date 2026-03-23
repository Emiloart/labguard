import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/widgets/app_panel.dart';
import '../../auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Text(
          'Settings & Security',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Local app protection, privacy posture, permissions, and product information.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: authState.biometricEnabled,
                onChanged: authController.setBiometric,
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                  'Require a trusted biometric before exposing protected data.',
                ),
              ),
              SwitchListTile.adaptive(
                value: authState.pinLockEnabled,
                onChanged: authController.setPinLock,
                title: const Text('App PIN'),
                subtitle: const Text(
                  'Require an additional PIN before app access resumes.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text(
                'Mode ${AppEnvironment.environment}\nAPI ${AppEnvironment.apiBaseUrl}\nVersion ${AppEnvironment.appVersion}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () => context.go('/settings/about'),
                child: const Text('About LabGuard'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: authController.signOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
