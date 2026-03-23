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

  factory SecurityEventRecord.fromJson(Map<String, dynamic> json) {
    return SecurityEventRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Event',
      summary: json['summary'] as String? ?? 'No summary available.',
      severity: eventSeverityFromWire(json['severity'] as String? ?? 'INFO'),
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unread: json['unread'] as bool? ?? false,
      deviceName: json['deviceName'] as String?,
    );
  }
}

EventSeverity eventSeverityFromWire(String value) {
  switch (value) {
    case 'CRITICAL':
      return EventSeverity.critical;
    case 'WARNING':
      return EventSeverity.warning;
    case 'INFO':
    default:
      return EventSeverity.info;
  }
}
