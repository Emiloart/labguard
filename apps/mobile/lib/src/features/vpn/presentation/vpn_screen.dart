import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/platform/android_vpn_bridge.dart';
import '../../settings/application/settings_controller.dart';
import '../application/vpn_preferences_controller.dart';
import '../application/vpn_session_controller.dart';
import '../domain/vpn_overview.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(vpnSessionControllerProvider);
    final servers = ref.watch(vpnServersProvider);
    final settings = ref.watch(settingsControllerProvider);

    if (sessionState.isLoading || servers.isLoading || settings.isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading VPN controls')],
      );
    }

    final firstError = sessionState.error ?? servers.error ?? settings.error;

    if (firstError != null &&
        (sessionState.valueOrNull == null ||
            servers.valueOrNull == null ||
            settings.valueOrNull == null)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: firstError.toString(),
            onRetry: () {
              ref.invalidate(vpnSessionControllerProvider);
              ref.invalidate(vpnServersProvider);
              ref.invalidate(settingsControllerProvider);
            },
          ),
        ],
      );
    }

    final control = sessionState.valueOrNull!;
    final serverList = servers.valueOrNull ?? const <VpnServerRecord>[];
    final preferences = settings.valueOrNull!.preferences;
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final vpnController = ref.read(vpnSessionControllerProvider.notifier);
    final vpnBridge = ref.read(androidVpnBridgeProvider);
    final busy = sessionState.isLoading;
    final selectedServerId =
        control.profile?.serverId ?? control.remoteSession.serverId;
    final selectedServer = _findServer(serverList, selectedServerId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        const ScreenIntro(
          eyebrow: 'Tunnel Control',
          title: 'VPN Core',
          description:
              'WireGuard tunnel control, profile lifecycle, and Android VPN authorization are managed here.',
          badge: 'WIREGUARD',
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
                    label: _connectionLabel(control.nativeStatus.tunnelState),
                    color: _connectionColor(control.nativeStatus.tunnelState),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                control.remoteSession.serverName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tunnel ${control.profile?.tunnelName ?? control.nativeStatus.tunnelName} • Revision ${control.profile?.revision ?? control.nativeStatus.profileRevision}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Current IP ${control.remoteSession.currentIp}\nDNS ${control.remoteSession.dnsMode}\nSession ${control.remoteSession.sessionLabel}\nTraffic ${control.remoteSession.trafficLabel}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if ((control.remoteSession.lastError ??
                      control.nativeStatus.lastError) !=
                  null) ...[
                const SizedBox(height: 12),
                Text(
                  control.remoteSession.lastError ??
                      control.nativeStatus.lastError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFFB65C),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : control.nativeStatus.tunnelState ==
                              VpnConnectionState.connected
                        ? vpnController.disconnect
                        : vpnController.connect,
                    child: Text(
                      control.nativeStatus.tunnelState ==
                              VpnConnectionState.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.installLatestProfile,
                    child: const Text('Install Profile'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.prepareAndroidVpn,
                    child: Text(
                      control.capabilities.permissionGranted
                          ? 'VPN Permission Ready'
                          : 'Prepare Android VPN',
                    ),
                  ),
                ],
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
                initialValue: selectedServerId.isEmpty
                    ? null
                    : selectedServerId,
                items: [
                  for (final server in serverList)
                    DropdownMenuItem<String>(
                      value: server.id,
                      child: Text(server.displayLabel),
                    ),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 12),
              Text(
                selectedServer == null
                    ? 'The current device is pinned to an approved LabGuard server by the control plane.'
                    : 'Endpoint ${selectedServer.endpoint}\nDNS ${selectedServer.dnsServers.join(', ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                control.profile?.note ??
                    'The current device does not have an active WireGuard profile.',
                style: Theme.of(context).textTheme.bodySmall,
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
                  'Request OS-level blocking through Android Always-on VPN and Block connections without VPN.',
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
                  'Reconnect on startup and recovery only while LabGuard still has an active keep-connected intent.',
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
                  'Keep disconnects, reconnects, and key changes visible while the tunnel is active.',
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
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android Runtime',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _MetadataRow(
                label: 'Platform',
                value:
                    '${control.capabilities.platform} • WireGuard ${control.nativeStatus.backendVersion}',
              ),
              _MetadataRow(
                label: 'VPN permission',
                value: control.capabilities.permissionGranted
                    ? 'Granted'
                    : 'Required',
              ),
              _MetadataRow(
                label: 'Connection intent',
                value: control.nativeStatus.desiredConnected
                    ? 'Maintain tunnel'
                    : 'Manual only',
              ),
              _MetadataRow(
                label: 'Kill switch',
                value: control.nativeStatus.killSwitchRequested
                    ? 'Requested'
                    : 'Not requested',
              ),
              _MetadataRow(
                label: 'Profile installed',
                value: control.nativeStatus.profileInstalled
                    ? 'Revision ${control.nativeStatus.profileRevision}'
                    : 'No active profile',
              ),
              _MetadataRow(
                label: 'Last handshake',
                value: _timestampLabel(control.nativeStatus.lastHandshakeAt),
              ),
              _MetadataRow(
                label: 'Connected at',
                value: _timestampLabel(control.remoteSession.connectedAt),
              ),
              _MetadataRow(
                label: 'Last heartbeat',
                value: _timestampLabel(control.remoteSession.lastHeartbeatAt),
              ),
              const SizedBox(height: 12),
              if (control.nativeStatus.killSwitchRequested) ...[
                Text(
                  control.capabilities.killSwitchManagedBySystem
                      ? 'LabGuard can only enforce the kill switch through Android VPN settings. Enable Always-on VPN and Block connections without VPN there.'
                      : 'Kill switch enforcement is unavailable on this Android build.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.syncTunnelState,
                    child: const Text('Sync Status'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.rotateProfile,
                    child: const Text('Rotate Credentials'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.revokeProfile,
                    child: const Text('Revoke Profile'),
                  ),
                  if (control.capabilities.supportsAlwaysOnSystemSettings)
                    OutlinedButton(
                      onPressed: () => vpnBridge.openVpnSettings(),
                      child: const Text('Android VPN Settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _connectionColor(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connected:
        return const Color(0xFF74D6A2);
      case VpnConnectionState.connecting:
        return const Color(0xFF7BA7FF);
      case VpnConnectionState.authRequired:
      case VpnConnectionState.profileMissing:
        return const Color(0xFFFFB65C);
      case VpnConnectionState.error:
        return const Color(0xFFFF7F7F);
      case VpnConnectionState.disconnected:
        return const Color(0xFFA3A9B8);
    }
  }

  String _connectionLabel(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connected:
        return 'Connected';
      case VpnConnectionState.connecting:
        return 'Connecting';
      case VpnConnectionState.authRequired:
        return 'Permission Required';
      case VpnConnectionState.profileMissing:
        return 'Profile Missing';
      case VpnConnectionState.error:
        return 'Error';
      case VpnConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  String _timestampLabel(DateTime? value) {
    if (value == null) {
      return 'Unavailable';
    }

    return DateFormat('MMM d, HH:mm').format(value.toLocal());
  }

  VpnServerRecord? _findServer(List<VpnServerRecord> servers, String serverId) {
    for (final server in servers) {
      if (server.id == serverId) {
        return server;
      }
    }

    return null;
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
