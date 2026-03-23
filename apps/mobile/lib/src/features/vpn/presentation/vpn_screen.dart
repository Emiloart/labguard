import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_vpn_bridge.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../../settings/application/settings_controller.dart';
import '../application/vpn_preferences_controller.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(vpnOverviewProvider);
    final servers = ref.watch(vpnServersProvider);
    final settings = ref.watch(settingsControllerProvider);
    final vpnBridge = ref.watch(androidVpnBridgeProvider);

    if (overview.isLoading || servers.isLoading || settings.isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading VPN controls')],
      );
    }

    final firstError = overview.error ?? servers.error ?? settings.error;

    if (firstError != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: firstError.toString(),
            onRetry: () {
              ref.invalidate(vpnOverviewProvider);
              ref.invalidate(vpnServersProvider);
              ref.invalidate(settingsControllerProvider);
            },
          ),
        ],
      );
    }

    final vpnOverview = overview.valueOrNull!;
    final serverList = servers.valueOrNull!;
    final preferences = settings.valueOrNull!.preferences;
    final settingsController = ref.read(settingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Text('VPN Core', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'WireGuard-based tunnel lifecycle, DNS posture, and reconnect policy are managed here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Tunnel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  StatusBadge(
                    label: vpnOverview.connected ? 'Connected' : 'Disconnected',
                    color: vpnOverview.connected
                        ? const Color(0xFF74D6A2)
                        : const Color(0xFFFFB65C),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                vpnOverview.serverName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Current IP ${vpnOverview.currentIp}\nDNS ${vpnOverview.dnsMode}\nSession ${vpnOverview.sessionLabel}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  await vpnBridge.prepareVpn();
                },
                child: const Text('Prepare Android VPN Layer'),
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
                'Server Registry',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: serverList.isEmpty ? null : serverList.first.id,
                items: [
                  for (final server in serverList)
                    DropdownMenuItem<String>(
                      value: server.id,
                      child: Text(server.displayLabel),
                    ),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: preferences.killSwitchEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(killSwitchEnabled: value),
                  );
                },
                title: const Text('Kill switch'),
                subtitle: const Text(
                  'Prevent traffic leakage when the tunnel is expected to be active.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.autoConnectEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(autoConnectEnabled: value),
                  );
                },
                title: const Text('Auto-connect'),
                subtitle: const Text(
                  'Bring the tunnel up automatically after app start or trusted policy match.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.notificationsEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(notificationsEnabled: value),
                  );
                },
                title: const Text('VPN security notifications'),
                subtitle: const Text(
                  'Keep device and disconnect alerts visible while the tunnel is active.',
                ),
              ),
              SwitchListTile.adaptive(
                value: preferences.locationPermissionStatus != 'not_requested',
                onChanged: (_) {},
                title: const Text('Location permissions'),
                subtitle: Text(
                  'Current policy: ${preferences.locationPermissionStatus}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: vpnBridge.getPlatformCapabilities(),
          builder: (context, snapshot) {
            final capabilities = snapshot.data ?? const <String, dynamic>{};

            return AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Android Integration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Phase 2 keeps the native bridge and API-backed policy surface aligned. WireGuard and foreground service work land in Phase 3.\n\n'
                    'Bridge response: ${capabilities.isEmpty ? 'pending' : capabilities}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
