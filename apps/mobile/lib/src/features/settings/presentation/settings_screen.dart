import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../auth/application/auth_controller.dart';
import '../application/settings_controller.dart';
import '../domain/settings_bundle.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);

    return settings.when(
      data: (data) =>
          _SettingsContent(settings: data, onSignOut: authController.signOut),
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading security settings')],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(settingsControllerProvider),
          ),
        ],
      ),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent({required this.settings, required this.onSignOut});

  final SettingsBundle settings;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final preferences = settings.preferences;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Text(
          'Settings & Security',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${settings.profile.viewerDisplayName} • ${settings.profile.accountName}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: preferences.biometricEnabled,
                onChanged: (value) {
                  controller.updatePreferences(
                    (current) => current.copyWith(biometricEnabled: value),
                  );
                },
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                  'Require a trusted biometric before exposing protected data.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.pinLockEnabled,
                onChanged: (value) {
                  controller.updatePreferences(
                    (current) => current.copyWith(pinLockEnabled: value),
                  );
                },
                title: const Text('App PIN'),
                subtitle: const Text(
                  'Require an additional PIN before app access resumes.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.notificationsEnabled,
                onChanged: (value) {
                  controller.updatePreferences(
                    (current) => current.copyWith(notificationsEnabled: value),
                  );
                },
                title: const Text('Security notifications'),
                subtitle: const Text(
                  'Receive alerts for trust changes, revocations, and unexpected disconnects.',
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
                'Mode ${AppEnvironment.environment}\nAPI ${AppEnvironment.apiBaseUrl}\nVersion ${AppEnvironment.appVersion}\nTelemetry ${preferences.telemetryLevel}\nLocation ${preferences.locationPermissionStatus}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () => context.go('/settings/about'),
                child: const Text('About LabGuard'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await onSignOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
