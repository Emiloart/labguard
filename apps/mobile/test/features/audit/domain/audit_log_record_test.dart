import 'package:flutter_test/flutter_test.dart';

import 'package:labguard/src/features/audit/domain/audit_log_record.dart';

void main() {
  test('parses audit records from backend payloads', () {
    final record = AuditLogRecord.fromJson({
      'id': 'audit-01',
      'action': 'VPN_PROFILE_ROTATED',
      'targetType': 'VPN_PROFILE',
      'targetId': 'pixel-9-pro',
      'outcome': 'SUCCESS',
      'summary': 'A fresh WireGuard profile revision was issued.',
      'actorLabel': 'Emilo Owner',
      'createdAt': '2026-03-24T10:30:00.000Z',
    });

    expect(record.id, 'audit-01');
    expect(record.action, 'VPN_PROFILE_ROTATED');
    expect(record.targetType, 'VPN_PROFILE');
    expect(record.targetId, 'pixel-9-pro');
    expect(record.outcome, AuditLogOutcome.success);
    expect(record.actorLabel, 'Emilo Owner');
    expect(record.createdAt.toIso8601String(), '2026-03-24T10:30:00.000Z');
  });
}
