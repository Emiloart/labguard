import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_vpn_bridge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/vpn_preferences_controller.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(vpnOverviewProvider);
    final policy = ref.watch(vpnPolicyControllerProvider);
    final policyController = ref.read(vpnPolicyControllerProvider.notifier);
    final servers = ref.watch(vpnServersProvider);
    final vpnBridge = ref.watch(androidVpnBridgeProvider);

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
                    label: overview.connected ? 'Connected' : 'Disconnected',
                    color: overview.connected
                        ? LabGuardColors.success
                        : LabGuardColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                overview.serverName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Current IP ${overview.currentIp}\nDNS ${overview.dnsMode}\nSession ${overview.sessionLabel}',
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
                initialValue: servers.first,
                items: [
                  for (final server in servers)
                    DropdownMenuItem<String>(
                      value: server,
                      child: Text(server),
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
                value: policy.killSwitchEnabled,
                onChanged: policyController.setKillSwitch,
                title: const Text('Kill switch'),
                subtitle: const Text(
                  'Prevent traffic leakage when the tunnel is expected to be active.',
                ),
              ),
              SwitchListTile.adaptive(
                value: policy.autoConnectEnabled,
                onChanged: policyController.setAutoConnect,
                title: const Text('Auto-connect'),
                subtitle: const Text(
                  'Bring the tunnel up automatically after app start or trusted policy match.',
                ),
              ),
              SwitchListTile.adaptive(
                value: policy.reconnectOnNetworkChange,
                onChanged: policyController.setReconnectOnNetworkChange,
                title: const Text('Reconnect on network change'),
                subtitle: const Text(
                  'Attempt tunnel recovery after Wi-Fi or cellular transitions.',
                ),
              ),
              SwitchListTile.adaptive(
                value: policy.customDnsEnabled,
                onChanged: policyController.setCustomDns,
                title: const Text('Tunnel DNS'),
                subtitle: const Text(
                  'Use backend-provisioned DNS resolvers inside the VPN profile.',
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
                    'Phase 1 exposes the native bridge only. WireGuard and foreground service work land in Phase 3.\n\n'
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
