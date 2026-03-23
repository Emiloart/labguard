import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/security_event_record.dart';

final securityEventsProvider = Provider<List<SecurityEventRecord>>((ref) {
  final now = DateTime.now();

  return [
    SecurityEventRecord(
      id: 'evt-01',
      title: 'Unexpected VPN reconnect',
      summary:
          'Primary Pixel re-established the WireGuard tunnel after a network transition.',
      severity: EventSeverity.info,
      occurredAt: now.subtract(const Duration(minutes: 9)),
      unread: true,
      deviceName: 'Primary Pixel',
    ),
    SecurityEventRecord(
      id: 'evt-02',
      title: 'Lost mode remains active',
      summary:
          'Travel Device is still marked lost and sending elevated location updates while online.',
      severity: EventSeverity.critical,
      occurredAt: now.subtract(const Duration(minutes: 21)),
      unread: true,
      deviceName: 'Travel Device',
    ),
    SecurityEventRecord(
      id: 'evt-03',
      title: 'Pending device approval',
      summary:
          'Owner Tablet registered but is waiting for owner approval before profile provisioning.',
      severity: EventSeverity.warning,
      occurredAt: now.subtract(const Duration(hours: 4)),
      unread: false,
      deviceName: 'Owner Tablet',
    ),
  ];
});
