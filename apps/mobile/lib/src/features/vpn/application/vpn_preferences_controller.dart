import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../domain/vpn_overview.dart';

final vpnOverviewProvider = FutureProvider<VpnOverview>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return summary.vpnOverview;
});

final vpnRepositoryProvider = Provider<VpnRepository>((ref) {
  return VpnRepository(client: ref.watch(labGuardApiClientProvider));
});

final vpnServersProvider = FutureProvider<List<VpnServerRecord>>((ref) async {
  return ref.watch(vpnRepositoryProvider).fetchServers();
});

class VpnRepository {
  VpnRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<VpnServerRecord>> fetchServers() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/vpn/servers',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(VpnServerRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the LabGuard server registry.',
      );
    }
  }

  Future<VpnProfileBundle> fetchProfile(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/vpn/profiles/$deviceId',
      );

      return VpnProfileBundle.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to retrieve the WireGuard profile.',
      );
    }
  }

  Future<VpnSessionSnapshot> fetchSession(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/vpn/sessions/$deviceId',
      );

      return VpnSessionSnapshot.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to retrieve the VPN tunnel status.',
      );
    }
  }

  Future<VpnProfileBundle> rotateProfile(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/vpn/profiles/$deviceId/rotate',
      );
      final profile =
          response.data?['profile'] as Map<String, dynamic>? ?? const {};

      return VpnProfileBundle.fromJson(profile);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to rotate the VPN credentials.',
      );
    }
  }

  Future<VpnProfileBundle> revokeProfile(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/vpn/profiles/$deviceId/revoke',
      );
      final profile =
          response.data?['profile'] as Map<String, dynamic>? ?? const {};

      return VpnProfileBundle.fromJson(profile);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to revoke the VPN credentials.',
      );
    }
  }

  Future<VpnSessionSnapshot> connectSession({
    required String deviceId,
    required String serverId,
    required String currentIp,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/vpn/sessions/connect',
        data: {
          'deviceId': deviceId,
          'serverId': serverId,
          'currentIp': currentIp,
        },
      );

      return VpnSessionSnapshot.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sync the connected session state.',
      );
    }
  }

  Future<VpnSessionSnapshot> disconnectSession({
    required String deviceId,
    String? reason,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/vpn/sessions/disconnect',
        data: {
          'deviceId': deviceId,
          ...?(reason == null ? null : {'reason': reason}),
        },
      );

      return VpnSessionSnapshot.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sync the disconnected session state.',
      );
    }
  }

  Future<VpnSessionSnapshot> recordHeartbeat({
    required String deviceId,
    required VpnNativeStatus status,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/vpn/sessions/heartbeat',
        data: {
          'deviceId': deviceId,
          'serverId': status.serverId,
          'tunnelState': _tunnelStateToWire(status.tunnelState),
          'currentIp': status.currentIp,
          'bytesReceived': status.bytesReceived,
          'bytesSent': status.bytesSent,
          ...?(status.lastHandshakeAt == null
              ? null
              : {'lastHandshakeAt': status.lastHandshakeAt!.toIso8601String()}),
          ...?(status.lastError == null
              ? null
              : {'lastError': status.lastError}),
        },
      );

      final session =
          response.data?['session'] as Map<String, dynamic>? ?? const {};
      return VpnSessionSnapshot.fromJson(session);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sync the tunnel heartbeat.',
      );
    }
  }

  String _tunnelStateToWire(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connecting:
        return 'CONNECTING';
      case VpnConnectionState.connected:
        return 'CONNECTED';
      case VpnConnectionState.error:
        return 'ERROR';
      case VpnConnectionState.authRequired:
        return 'AUTH_REQUIRED';
      case VpnConnectionState.profileMissing:
        return 'PROFILE_MISSING';
      case VpnConnectionState.disconnected:
        return 'DISCONNECTED';
    }
  }
}
