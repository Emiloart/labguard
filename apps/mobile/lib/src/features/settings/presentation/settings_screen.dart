import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/platform/android_system_security_bridge.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../auth/application/auth_controller.dart';
import '../application/device_security_posture_provider.dart';
import '../application/settings_controller.dart';
import '../domain/settings_bundle.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(deviceSecurityPostureControllerProvider).refresh();
    }
  }

  Future<void> _openNotificationSettings() {
    return ref
        .read(deviceSecurityPostureControllerProvider)
        .openNotificationSettings();
  }

  Future<void> _openApplicationSettings() {
    return ref
        .read(deviceSecurityPostureControllerProvider)
        .openApplicationSettings();
  }

  Future<void> _requestNotificationPermission() async {
    await ref
        .read(deviceSecurityPostureControllerProvider)
        .requestNotificationPermission();
  }

  Future<void> _requestLocationPermission(
    SecurityPreferences preferences,
  ) async {
    final posture = await ref
        .read(deviceSecurityPostureControllerProvider)
        .requestLocationPermission();
    final locationPolicyStatus =
        posture.locationPermissionStatus == 'granted_precise' ||
            posture.locationPermissionStatus == 'granted_approximate'
        ? 'granted_when_in_use'
        : 'not_requested';

    if (preferences.locationPermissionStatus != locationPolicyStatus) {
      await ref
          .read(settingsControllerProvider.notifier)
          .updatePreferences(
            (current) => current.copyWith(
              locationPermissionStatus: locationPolicyStatus,
            ),
          );
    }
  }

  Future<void> _reviewBatteryOptimization(
    SecurityPreferences preferences,
  ) async {
    if (!preferences.batteryOptimizationAcknowledged) {
      await ref
          .read(settingsControllerProvider.notifier)
          .updatePreferences(
            (current) =>
                current.copyWith(batteryOptimizationAcknowledged: true),
          );
    }

    await ref
        .read(deviceSecurityPostureControllerProvider)
        .openBatteryOptimizationSettings();
  }

  void _refreshPosture() {
    ref.read(deviceSecurityPostureControllerProvider).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.read(authControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final posture = ref.watch(deviceSecurityPostureProvider);

    return settings.when(
      data: (data) => _SettingsContent(
        settings: data,
        posture: posture,
        onSignOut: authController.signOut,
        onRefreshPosture: _refreshPosture,
        onRequestNotificationPermission: _requestNotificationPermission,
        onRequestLocationPermission: () =>
            _requestLocationPermission(data.preferences),
        onOpenNotificationSettings: _openNotificationSettings,
        onOpenApplicationSettings: _openApplicationSettings,
        onReviewBatteryOptimization: () =>
            _reviewBatteryOptimization(data.preferences),
      ),
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
  const _SettingsContent({
    required this.settings,
    required this.posture,
    required this.onSignOut,
    required this.onRefreshPosture,
    required this.onRequestNotificationPermission,
    required this.onRequestLocationPermission,
    required this.onOpenNotificationSettings,
    required this.onOpenApplicationSettings,
    required this.onReviewBatteryOptimization,
  });

  final SettingsBundle settings;
  final AsyncValue<DeviceSecurityPosture> posture;
  final Future<void> Function() onSignOut;
  final VoidCallback onRefreshPosture;
  final Future<void> Function() onRequestNotificationPermission;
  final Future<void> Function() onRequestLocationPermission;
  final Future<void> Function() onOpenNotificationSettings;
  final Future<void> Function() onOpenApplicationSettings;
  final Future<void> Function() onReviewBatteryOptimization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final preferences = settings.preferences;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        ScreenIntro(
          eyebrow: 'Trusted Access',
          title: 'Settings & Security',
          description:
              '${settings.profile.viewerDisplayName} • ${settings.profile.accountName}',
          badge: AppEnvironment.environment.toUpperCase(),
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: preferences.biometricEnabled,
                onChanged: (value) async {
                  await controller.updatePreferences(
                    (current) => current.copyWith(biometricEnabled: value),
                  );
                  if (value) {
                    ref.read(appLockControllerProvider).lock();
                  }
                },
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                  'Require a trusted biometric before exposing protected data.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.pinLockEnabled,
                onChanged: (value) async {
                  await _handlePinToggle(context, ref, controller, value);
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
        _DeviceSecurityPosturePanel(
          posture: posture,
          preferences: preferences,
          onRefresh: onRefreshPosture,
          onRequestNotificationPermission: onRequestNotificationPermission,
          onRequestLocationPermission: onRequestLocationPermission,
          onOpenNotificationSettings: onOpenNotificationSettings,
          onOpenApplicationSettings: onOpenApplicationSettings,
          onReviewBatteryOptimization: onReviewBatteryOptimization,
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
                'Mode ${AppEnvironment.environment}\nAPI ${AppEnvironment.apiBaseUrl}\nVersion ${AppEnvironment.appVersion}\nBrand ${settings.profile.brandAttribution}\nTelemetry ${preferences.telemetryLevel}\nLost-mode location policy ${preferences.locationPermissionStatus}\nBattery review ${preferences.batteryOptimizationAcknowledged ? 'acknowledged' : 'pending'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () => context.go('/settings/about'),
                child: const Text('About LabGuard'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => context.go('/settings/audit'),
                child: const Text('Audit Trail'),
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

Future<void> _handlePinToggle(
  BuildContext context,
  WidgetRef ref,
  SettingsController controller,
  bool enabled,
) async {
  final appLockController = ref.read(appLockControllerProvider);

  if (!enabled) {
    await appLockController.clearPin();
    await controller.updatePreferences(
      (current) => current.copyWith(pinLockEnabled: false),
      clearAppPin: true,
    );
    return;
  }

  final pin = await _promptForPin(context);
  if (pin == null) {
    return;
  }

  await appLockController.configurePin(pin);
  await controller.updatePreferences(
    (current) => current.copyWith(pinLockEnabled: true),
    appPin: pin,
  );
  appLockController.lock();
}

Future<String?> _promptForPin(BuildContext context) async {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();

  final pin = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LabGuardColors.panel,
      title: const Text('Set App PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'App PIN'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final pin = pinController.text.trim();
            final confirmation = confirmController.text.trim();
            if (pin.length < 4 || pin != confirmation) {
              Navigator.of(context).pop('');
              return;
            }
            Navigator.of(context).pop(pin);
          },
          child: const Text('Save PIN'),
        ),
      ],
    ),
  );

  if (pin == null || pin.isEmpty) {
    return null;
  }

  return pin;
}

class _DeviceSecurityPosturePanel extends StatelessWidget {
  const _DeviceSecurityPosturePanel({
    required this.posture,
    required this.preferences,
    required this.onRefresh,
    required this.onRequestNotificationPermission,
    required this.onRequestLocationPermission,
    required this.onOpenNotificationSettings,
    required this.onOpenApplicationSettings,
    required this.onReviewBatteryOptimization,
  });

  final AsyncValue<DeviceSecurityPosture> posture;
  final SecurityPreferences preferences;
  final VoidCallback onRefresh;
  final Future<void> Function() onRequestNotificationPermission;
  final Future<void> Function() onRequestLocationPermission;
  final Future<void> Function() onOpenNotificationSettings;
  final Future<void> Function() onOpenApplicationSettings;
  final Future<void> Function() onReviewBatteryOptimization;

  @override
  Widget build(BuildContext context) {
    return posture.when(
      data: (data) => _buildContent(context, data),
      loading: () =>
          const LoadingPanel(label: 'Inspecting Android runtime posture'),
      error: (error, _) => AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Runtime Posture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRefresh,
              child: const Text('Retry posture check'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DeviceSecurityPosture posture) {
    if (!posture.supported) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Runtime Posture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Native Android posture checks are unavailable on this build.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      );
    }

    final notificationsRequireReview = !posture.notificationsEnabled;
    final locationRequiresReview =
        posture.locationPermissionStatus != 'granted_precise';
    final batteryRequiresReview = !posture.batteryOptimizationIgnored;
    final requiresReview =
        notificationsRequireReview ||
        locationRequiresReview ||
        batteryRequiresReview;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Runtime Posture',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            requiresReview
                ? 'Android runtime controls need operator review before this device is trusted for continuous protection.'
                : 'Android runtime controls meet the current LabGuard protection baseline.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _PostureStatusRow(
            label: 'Security notifications',
            value: posture.notificationsEnabled ? 'Enabled' : 'Disabled',
            detail: posture.notificationsEnabled
                ? 'Critical revocations and disconnect alerts can surface immediately.'
                : 'Security alerts can be missed until the app is opened again.',
            tone: posture.notificationsEnabled
                ? _PostureStatusTone.healthy
                : _PostureStatusTone.critical,
          ),
          const SizedBox(height: 12),
          _PostureStatusRow(
            label: 'Location access',
            value: _locationLabel(posture.locationPermissionStatus),
            detail: posture.locationPermissionStatus == 'granted_precise'
                ? 'Lost-device recovery can capture precise location samples.'
                : posture.locationPermissionStatus == 'granted_approximate'
                ? 'Recovery remains available, but approximate-only access reduces map accuracy.'
                : 'Lost-device recovery cannot refresh location until Android permission is restored.',
            tone: _locationTone(posture.locationPermissionStatus),
          ),
          const SizedBox(height: 12),
          _PostureStatusRow(
            label: 'Battery optimization',
            value: posture.batteryOptimizationIgnored ? 'Exempt' : 'Restricted',
            detail: posture.batteryOptimizationIgnored
                ? 'Background sync and command delivery are less likely to be throttled.'
                : preferences.batteryOptimizationAcknowledged
                ? 'Background delivery can still be delayed by Android power management.'
                : 'Review is still pending for Android power-management restrictions.',
            tone: posture.batteryOptimizationIgnored
                ? _PostureStatusTone.healthy
                : _PostureStatusTone.review,
          ),
          const SizedBox(height: 12),
          _PostureStatusRow(
            label: 'Platform build',
            value: 'Android API ${posture.sdkInt}',
            detail: posture.postNotificationsRuntimePermissionRequired
                ? 'Runtime notification permission is enforced on this Android release.'
                : 'Notification delivery is governed by the app-level system toggle.',
            tone: _PostureStatusTone.healthy,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (notificationsRequireReview)
                FilledButton.tonal(
                  onPressed: posture.postNotificationsRuntimePermissionRequired
                      ? onRequestNotificationPermission
                      : onOpenNotificationSettings,
                  child: Text(
                    posture.postNotificationsRuntimePermissionRequired
                        ? 'Request Notifications'
                        : 'Notification Settings',
                  ),
                ),
              if (notificationsRequireReview &&
                  posture.postNotificationsRuntimePermissionRequired)
                FilledButton.tonal(
                  onPressed: onOpenNotificationSettings,
                  child: const Text('Notification Settings'),
                ),
              if (locationRequiresReview)
                FilledButton.tonal(
                  onPressed: onRequestLocationPermission,
                  child: Text(
                    posture.locationPermissionStatus == 'granted_approximate'
                        ? 'Request Precise Location'
                        : 'Request Location Access',
                  ),
                ),
              if (locationRequiresReview)
                FilledButton.tonal(
                  onPressed: onOpenApplicationSettings,
                  child: const Text('App Permissions'),
                ),
              if (batteryRequiresReview)
                FilledButton.tonal(
                  onPressed: onReviewBatteryOptimization,
                  child: const Text('Battery Optimization'),
                ),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _locationLabel(String status) {
    switch (status) {
      case 'granted_precise':
        return 'Precise';
      case 'granted_approximate':
        return 'Approximate';
      case 'denied':
        return 'Denied';
      default:
        return 'Unavailable';
    }
  }

  static _PostureStatusTone _locationTone(String status) {
    switch (status) {
      case 'granted_precise':
        return _PostureStatusTone.healthy;
      case 'granted_approximate':
        return _PostureStatusTone.review;
      case 'denied':
        return _PostureStatusTone.critical;
      default:
        return _PostureStatusTone.review;
    }
  }
}

enum _PostureStatusTone { healthy, review, critical }

class _PostureStatusRow extends StatelessWidget {
  const _PostureStatusRow({
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final _PostureStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _PostureStatusTone.healthy => LabGuardColors.success,
      _PostureStatusTone.review => LabGuardColors.warning,
      _PostureStatusTone.critical => LabGuardColors.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Text(
                value,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
