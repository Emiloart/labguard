import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/security/high_risk_action_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/panel_header.dart';
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
    final control = sessionState.valueOrNull;
    final serverList = (servers.valueOrNull ?? const <VpnServerRecord>[])
        .where((server) => server.selectable)
        .toList(growable: false);
    final preferences = settings.valueOrNull?.preferences;

    if ((sessionState.isLoading && control == null) ||
        (servers.isLoading && serverList.isEmpty) ||
        (settings.isLoading && preferences == null)) {
      return ListView(
        padding: AppMetrics.pagePadding,
        children: const [
          LoadingPanel(
            label: 'Loading VPN controls',
            message:
                'Preparing tunnel state, approved server metadata, and protection preferences.',
          ),
        ],
      );
    }

    final firstError = sessionState.error ?? servers.error ?? settings.error;

    if (firstError != null && (control == null || preferences == null)) {
      return ListView(
        padding: AppMetrics.pagePadding,
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

    final controlState = control!;
    final resolvedPreferences = preferences!;
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final vpnController = ref.read(vpnSessionControllerProvider.notifier);
    final vpnBridge = ref.read(androidVpnBridgeProvider);
    final busy = sessionState.isLoading;
    final selectedServerId =
        controlState.profile?.serverId ?? controlState.remoteSession.serverId;
    final selectedServer = _findServer(serverList, selectedServerId);
    final infrastructureReady = serverList.isNotEmpty;
    final tunnelState = controlState.effectiveTunnelState;
    final statusText = infrastructureReady
        ? [
            if (tunnelState == VpnConnectionState.connected)
              'Protection is active.'
            else if (tunnelState == VpnConnectionState.connecting)
              'Connecting now.'
            else
              'Protection is currently off.',
            'Session ${controlState.remoteSession.sessionLabel}',
            'Traffic ${controlState.remoteSession.trafficLabel}',
          ].join('\n')
        : 'No live VPN region is ready for this account yet.';

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        const ScreenIntro(
          eyebrow: 'Tunnel Control',
          title: 'VPN Core',
          description:
              'Manage the WireGuard tunnel, Android VPN permission, and tunnel safety preferences from one place.',
          badge: 'WIREGUARD',
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        if (!infrastructureReady) ...[
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHeader(
                  title: 'VPN infrastructure unavailable',
                  subtitle:
                      'Tunnel controls stay hidden until a live region is ready.',
                ),
                const SizedBox(height: AppMetrics.contentGap),
                Text(
                  'London and San Francisco are not available yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: busy ? null : vpnController.refresh,
                  child: const Text('Refresh availability'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                title: 'Active Tunnel',
                subtitle: infrastructureReady
                    ? 'Connect, disconnect, and confirm the current protection state.'
                    : 'Tunnel controls stay disabled until a live region is provisioned.',
                trailing: StatusBadge(
                  label: _connectionLabel(tunnelState),
                  color: _connectionColor(tunnelState),
                ),
              ),
              const SizedBox(height: AppMetrics.contentGap),
              Text(
                controlState.activeServerName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (controlState.activeLocationLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  controlState.activeLocationLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                controlState.nativeStatus.profileInstalled
                    ? 'This device is ready to use the current region.'
                    : 'Install the current region profile on this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(statusText, style: Theme.of(context).textTheme.bodyMedium),
              if ((controlState.remoteSession.lastError ??
                      controlState.nativeStatus.lastError) !=
                  null) ...[
                const SizedBox(height: 12),
                Text(
                  describeError(
                    controlState.effectiveError!,
                    fallback:
                        'The tunnel needs attention before it can continue.',
                  ),
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
                    onPressed: busy || !infrastructureReady
                        ? null
                        : () => _handlePrimaryTunnelAction(
                            context,
                            ref,
                            control: controlState,
                            controller: vpnController,
                          ),
                    child: Text(
                      tunnelState == VpnConnectionState.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy || !infrastructureReady
                        ? null
                        : vpnController.installLatestProfile,
                    child: const Text('Install Profile'),
                  ),
                  OutlinedButton(
                    onPressed: busy || !infrastructureReady
                        ? null
                        : vpnController.prepareAndroidVpn,
                    child: Text(
                      controlState.capabilities.permissionGranted
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
              const PanelHeader(
                title: 'Server Registry',
                subtitle: 'Only ready-to-use regions appear here.',
              ),
              const SizedBox(height: 14),
              if (serverList.isEmpty)
                const EmptyPanel(
                  title: 'No regions are ready',
                  message:
                      'Region switching will appear here once London or San Francisco is available.',
                  icon: Icons.dns_outlined,
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedServerId),
                  initialValue: selectedServer?.id,
                  items: [
                    for (final server in serverList)
                      DropdownMenuItem<String>(
                        value: server.id,
                        child: Text(
                          '${server.displayLabel} • ${server.locationLabel}',
                        ),
                      ),
                  ],
                  onChanged: busy || serverList.length < 2
                      ? null
                      : (value) {
                          if (value == null || value == selectedServerId) {
                            return;
                          }

                          _handleServerChange(
                            context,
                            ref,
                            controller: vpnController,
                            server: _findServer(serverList, value),
                            control: controlState,
                          );
                        },
                  decoration: const InputDecoration(labelText: 'Exit region'),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedServer == null
                      ? 'The current region is no longer available.'
                      : '${selectedServer.locationLabel}\nReady for secure routing through this region.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  controlState.profile?.note ??
                      'No active WireGuard profile is installed on this device.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelHeader(
                title: 'Protection Preferences',
                subtitle: 'Choose how LabGuard should behave on this device.',
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: resolvedPreferences.killSwitchEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(killSwitchEnabled: value),
                  );
                },
                title: const Text('Kill switch'),
                subtitle: const Text(
                  'Keep traffic from leaving the device outside the tunnel when Android supports it.',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: resolvedPreferences.autoConnectEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(autoConnectEnabled: value),
                  );
                },
                title: const Text('Auto-connect'),
                subtitle: const Text(
                  'Reconnect automatically when LabGuard is expected to stay on.',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: resolvedPreferences.notificationsEnabled,
                onChanged: (value) {
                  settingsController.updatePreferences(
                    (current) => current.copyWith(notificationsEnabled: value),
                  );
                },
                title: const Text('VPN security notifications'),
                subtitle: const Text(
                  'Show important tunnel alerts while protection is active.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lost-mode location access'),
                subtitle: Text(
                  resolvedPreferences.locationPermissionStatus ==
                          'granted_when_in_use'
                      ? 'Location is ready for recovery actions.'
                      : 'Review location access before using recovery tools.',
                ),
                trailing: StatusBadge(
                  label:
                      resolvedPreferences.locationPermissionStatus ==
                          'granted_when_in_use'
                      ? 'Ready'
                      : 'Review',
                  color:
                      resolvedPreferences.locationPermissionStatus ==
                          'granted_when_in_use'
                      ? LabGuardColors.success
                      : LabGuardColors.warning,
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
              const PanelHeader(
                title: 'Device Readiness',
                subtitle: 'Review the essentials before relying on the tunnel.',
              ),
              const SizedBox(height: 14),
              _MetadataRow(
                label: 'VPN permission',
                value: controlState.capabilities.permissionGranted
                    ? 'Granted'
                    : 'Required',
              ),
              _MetadataRow(
                label: 'Reconnect',
                value: controlState.nativeStatus.desiredConnected
                    ? 'Keep protection on'
                    : 'Manual only',
              ),
              _MetadataRow(
                label: 'Kill switch',
                value: controlState.nativeStatus.killSwitchRequested
                    ? 'On'
                    : 'Off',
              ),
              _MetadataRow(
                label: 'Profile',
                value: controlState.nativeStatus.profileInstalled
                    ? 'Installed'
                    : 'Not installed',
              ),
              _MetadataRow(
                label: 'Exit region',
                value: controlState.activeServerName,
              ),
              _MetadataRow(
                label: 'Last handshake',
                value: _timestampLabel(
                  controlState.remoteSession.lastHandshakeAt ??
                      controlState.nativeStatus.lastHandshakeAt,
                ),
              ),
              _MetadataRow(
                label: 'Connected at',
                value: _timestampLabel(controlState.remoteSession.connectedAt),
              ),
              _MetadataRow(
                label: 'Last heartbeat',
                value: _timestampLabel(
                  controlState.remoteSession.lastHeartbeatAt,
                ),
              ),
              const SizedBox(height: 12),
              if (controlState.nativeStatus.killSwitchRequested) ...[
                Text(
                  controlState.capabilities.killSwitchManagedBySystem
                      ? 'Complete kill switch setup from Android VPN settings if you want system-level enforcement.'
                      : 'System-level kill switch controls are not available on this device.',
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
                    child: const Text('Refresh Status'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : vpnController.rotateProfile,
                    child: const Text('Rotate Access'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _handleRevokeProfile(
                            context,
                            ref,
                            controller: vpnController,
                          ),
                    child: const Text('Remove Access'),
                  ),
                  if (controlState.capabilities.supportsAlwaysOnSystemSettings)
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

  Future<void> _handlePrimaryTunnelAction(
    BuildContext context,
    WidgetRef ref, {
    required VpnControlState control,
    required VpnSessionController controller,
  }) async {
    if (control.effectiveTunnelState != VpnConnectionState.connected) {
      final authorized = await authorizeHighRiskAction(
        context,
        ref,
        biometricReason: 'Approve connecting the LabGuard VPN.',
        pinPrompt: 'Enter your app PIN to connect the LabGuard VPN.',
      );
      if (!authorized || !context.mounted) {
        return;
      }

      await _runControllerAction(
        context,
        ref,
        action: controller.connect,
        successMessage: 'LabGuard VPN connected.',
        failureFallback: 'Unable to connect the LabGuard VPN right now.',
      );
      return;
    }

    final confirmed = await _confirmAction(
      context,
      title: 'Disconnect LabGuard VPN?',
      body:
          'Disconnecting stops tunnel protection on this device until you reconnect.',
      confirmLabel: 'Disconnect',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final authorized = await authorizeHighRiskAction(
      context,
      ref,
      biometricReason: 'Approve disconnecting the LabGuard VPN.',
      pinPrompt: 'Enter your app PIN to disconnect the LabGuard VPN.',
    );
    if (!authorized) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await _runControllerAction(
      context,
      ref,
      action: controller.disconnect,
      successMessage: 'LabGuard VPN disconnected.',
      failureFallback: 'Unable to disconnect the LabGuard VPN right now.',
    );
  }

  Future<void> _handleRevokeProfile(
    BuildContext context,
    WidgetRef ref, {
    required VpnSessionController controller,
  }) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Revoke this device profile?',
      body:
          'Revoking the current profile removes VPN access on this device until a fresh profile is issued.',
      confirmLabel: 'Revoke profile',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final authorized = await authorizeHighRiskAction(
      context,
      ref,
      biometricReason: 'Approve revoking this LabGuard VPN profile.',
      pinPrompt: 'Enter your app PIN to revoke this LabGuard VPN profile.',
    );
    if (!authorized) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await _runControllerAction(
      context,
      ref,
      action: controller.revokeProfile,
      successMessage: 'VPN access was revoked for this device.',
      failureFallback: 'Unable to revoke the VPN profile right now.',
    );
  }

  Future<void> _runControllerAction(
    BuildContext context,
    WidgetRef ref, {
    required Future<void> Function() action,
    required String successMessage,
    required String failureFallback,
  }) async {
    await action();
    final result = ref.read(vpnSessionControllerProvider);

    if (result.hasError) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: describeError(result.error!, fallback: failureFallback),
          tone: AppFeedbackTone.danger,
        );
      }
      return;
    }

    if (context.mounted) {
      showAppSnackBar(
        context,
        message: successMessage,
        tone: AppFeedbackTone.success,
      );
    }
  }

  Future<void> _handleServerChange(
    BuildContext context,
    WidgetRef ref, {
    required VpnSessionController controller,
    required VpnServerRecord? server,
    required VpnControlState control,
  }) async {
    if (server == null) {
      showAppSnackBar(
        context,
        message: 'The selected VPN region is not available.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    if (control.effectiveTunnelState == VpnConnectionState.connected ||
        control.effectiveTunnelState == VpnConnectionState.connecting) {
      final confirmed = await _confirmAction(
        context,
        title: 'Switch exit region?',
        body:
            'LabGuard will install a ${server.name} WireGuard profile and reconnect the tunnel through ${server.locationLabel}.',
        confirmLabel: 'Switch region',
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final authorized = await authorizeHighRiskAction(
      context,
      ref,
      biometricReason: 'Approve switching the LabGuard VPN region.',
      pinPrompt: 'Enter your app PIN to switch the LabGuard VPN region.',
    );
    if (!authorized || !context.mounted) {
      return;
    }

    await _runControllerAction(
      context,
      ref,
      action: () => controller.switchServer(server.id),
      successMessage: 'VPN region switched to ${server.name}.',
      failureFallback: 'Unable to switch the VPN region right now.',
    );
  }

  Color _connectionColor(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connected:
        return LabGuardColors.success;
      case VpnConnectionState.connecting:
        return LabGuardColors.info;
      case VpnConnectionState.authRequired:
      case VpnConnectionState.profileMissing:
        return LabGuardColors.warning;
      case VpnConnectionState.error:
        return LabGuardColors.danger;
      case VpnConnectionState.disconnected:
        return LabGuardColors.textSecondary;
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

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: danger
                    ? FilledButton.styleFrom(
                        backgroundColor: LabGuardColors.danger,
                        foregroundColor: LabGuardColors.textPrimary,
                      )
                    : null,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
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
