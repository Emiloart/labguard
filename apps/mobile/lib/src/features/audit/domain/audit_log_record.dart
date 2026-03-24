enum AuditLogOutcome { success, failure }

AuditLogOutcome auditLogOutcomeFromWire(String value) {
  switch (value) {
    case 'FAILURE':
      return AuditLogOutcome.failure;
    case 'SUCCESS':
    default:
      return AuditLogOutcome.success;
  }
}

class AuditLogRecord {
  const AuditLogRecord({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.outcome,
    required this.summary,
    required this.actorLabel,
    required this.createdAt,
  });

  factory AuditLogRecord.fromJson(Map<String, dynamic> json) {
    return AuditLogRecord(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? 'UNKNOWN_ACTION',
      targetType: json['targetType'] as String? ?? 'UNKNOWN_TARGET',
      targetId: json['targetId'] as String? ?? '',
      outcome: auditLogOutcomeFromWire(json['outcome'] as String? ?? 'SUCCESS'),
      summary: json['summary'] as String? ?? 'No audit detail available.',
      actorLabel: json['actorLabel'] as String? ?? 'LabGuard',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String action;
  final String targetType;
  final String targetId;
  final AuditLogOutcome outcome;
  final String summary;
  final String actorLabel;
  final DateTime createdAt;
}
