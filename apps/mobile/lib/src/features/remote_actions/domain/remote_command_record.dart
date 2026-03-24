enum RemoteCommandStatus { queued, delivered, succeeded, failed }

enum RemoteCommandType {
  signOut,
  revokeVpn,
  rotateSession,
  wipeAppData,
  ringAlarm,
  showRecoveryMessage,
  markRecovered,
  disableDeviceAccess,
}

RemoteCommandType remoteCommandTypeFromWire(String value) {
  switch (value) {
    case 'SIGN_OUT':
      return RemoteCommandType.signOut;
    case 'REVOKE_VPN':
      return RemoteCommandType.revokeVpn;
    case 'ROTATE_SESSION':
      return RemoteCommandType.rotateSession;
    case 'WIPE_APP_DATA':
      return RemoteCommandType.wipeAppData;
    case 'SHOW_RECOVERY_MESSAGE':
      return RemoteCommandType.showRecoveryMessage;
    case 'MARK_RECOVERED':
      return RemoteCommandType.markRecovered;
    case 'DISABLE_DEVICE_ACCESS':
      return RemoteCommandType.disableDeviceAccess;
    case 'RING_ALARM':
    default:
      return RemoteCommandType.ringAlarm;
  }
}

RemoteCommandStatus remoteCommandStatusFromWire(String value) {
  switch (value) {
    case 'DELIVERED':
      return RemoteCommandStatus.delivered;
    case 'SUCCEEDED':
      return RemoteCommandStatus.succeeded;
    case 'FAILED':
      return RemoteCommandStatus.failed;
    case 'QUEUED':
    default:
      return RemoteCommandStatus.queued;
  }
}

class RemoteCommandRecord {
  const RemoteCommandRecord({
    required this.commandId,
    required this.deviceId,
    required this.commandType,
    required this.status,
    required this.queuedAt,
    required this.expiresAt,
    required this.attemptCount,
    this.deliveredAt,
    this.completedAt,
    this.message,
    this.resultMessage,
    this.failureCode,
  });

  factory RemoteCommandRecord.fromJson(Map<String, dynamic> json) {
    return RemoteCommandRecord(
      commandId: json['commandId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      commandType: remoteCommandTypeFromWire(
        json['commandType'] as String? ?? 'RING_ALARM',
      ),
      status: remoteCommandStatusFromWire(
        json['status'] as String? ?? 'QUEUED',
      ),
      queuedAt:
          DateTime.tryParse(json['queuedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attemptCount: json['attemptCount'] as int? ?? 1,
      deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      message: json['message'] as String?,
      resultMessage: json['resultMessage'] as String?,
      failureCode: json['failureCode'] as String?,
    );
  }

  final String commandId;
  final String deviceId;
  final RemoteCommandType commandType;
  final RemoteCommandStatus status;
  final DateTime queuedAt;
  final DateTime expiresAt;
  final int attemptCount;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final String? message;
  final String? resultMessage;
  final String? failureCode;

  bool get isPending =>
      status == RemoteCommandStatus.queued ||
      status == RemoteCommandStatus.delivered;
}
