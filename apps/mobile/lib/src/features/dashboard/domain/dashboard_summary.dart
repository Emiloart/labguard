import '../../vpn/domain/vpn_overview.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.viewerDisplayName,
    required this.viewerRole,
    required this.accountName,
    required this.vpnOverview,
    required this.trustedDevicesCount,
    required this.lostDevicesCount,
    required this.unreadAlertsCount,
    required this.criticalAlertsCount,
    required this.quickActions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    final security = json['security'] as Map<String, dynamic>? ?? const {};
    final rawQuickActions = json['quickActions'] as List<dynamic>? ?? const [];

    return DashboardSummary(
      viewerDisplayName: viewer['displayName'] as String? ?? 'LabGuard User',
      viewerRole: viewer['role'] as String? ?? 'MEMBER',
      accountName: viewer['accountName'] as String? ?? 'Emilo Labs',
      vpnOverview: VpnOverview.fromJson(
        json['vpn'] as Map<String, dynamic>? ?? const {},
      ),
      trustedDevicesCount: security['trustedDevicesCount'] as int? ?? 0,
      lostDevicesCount: security['lostDevicesCount'] as int? ?? 0,
      unreadAlertsCount: security['unreadAlertsCount'] as int? ?? 0,
      criticalAlertsCount: security['criticalAlertsCount'] as int? ?? 0,
      quickActions: rawQuickActions
          .whereType<Map<String, dynamic>>()
          .map(DashboardQuickAction.fromJson)
          .toList(growable: false),
    );
  }

  final String viewerDisplayName;
  final String viewerRole;
  final String accountName;
  final VpnOverview vpnOverview;
  final int trustedDevicesCount;
  final int lostDevicesCount;
  final int unreadAlertsCount;
  final int criticalAlertsCount;
  final List<DashboardQuickAction> quickActions;
}

class DashboardQuickAction {
  const DashboardQuickAction({
    required this.id,
    required this.label,
    required this.route,
  });

  factory DashboardQuickAction.fromJson(Map<String, dynamic> json) {
    return DashboardQuickAction(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Open',
      route: json['route'] as String? ?? '/dashboard',
    );
  }

  final String id;
  final String label;
  final String route;
}
