enum EventSeverity {
  critical,
  warning,
  info;

  bool get isCritical => this == EventSeverity.critical;
}

class SecurityEventRecord {
  const SecurityEventRecord({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.occurredAt,
    required this.unread,
    this.deviceName,
  });

  final String id;
  final String title;
  final String summary;
  final EventSeverity severity;
  final DateTime occurredAt;
  final bool unread;
  final String? deviceName;
}
