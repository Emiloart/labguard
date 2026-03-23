import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vpn_overview.dart';

final vpnOverviewProvider = Provider<VpnOverview>((ref) {
  return const VpnOverview(
    connected: true,
    serverName: 'Casablanca Primary • wg-01',
    currentIp: '185.233.44.12',
    sessionDuration: Duration(hours: 3, minutes: 14),
    dnsMode: 'Private DNS via tunnel',
  );
});

final vpnServersProvider = Provider<List<String>>((ref) {
  return const [
    'Casablanca Primary • wg-01',
    'Reserved EU Secondary • placeholder',
  ];
});

final vpnPolicyControllerProvider =
    NotifierProvider<VpnPolicyController, VpnPolicySettings>(
      VpnPolicyController.new,
    );

class VpnPolicyController extends Notifier<VpnPolicySettings> {
  @override
  VpnPolicySettings build() {
    return const VpnPolicySettings(
      killSwitchEnabled: true,
      autoConnectEnabled: true,
      reconnectOnNetworkChange: true,
      customDnsEnabled: true,
    );
  }

  void setKillSwitch(bool enabled) {
    state = state.copyWith(killSwitchEnabled: enabled);
  }

  void setAutoConnect(bool enabled) {
    state = state.copyWith(autoConnectEnabled: enabled);
  }

  void setReconnectOnNetworkChange(bool enabled) {
    state = state.copyWith(reconnectOnNetworkChange: enabled);
  }

  void setCustomDns(bool enabled) {
    state = state.copyWith(customDnsEnabled: enabled);
  }
}
