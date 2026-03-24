import 'package:flutter_test/flutter_test.dart';

import 'package:labguard/src/features/remote_actions/domain/remote_command_record.dart';

void main() {
  test('parses remote command lifecycle metadata from backend payloads', () {
    final command = RemoteCommandRecord.fromJson({
      'commandId': 'cmd-01',
      'deviceId': 'pixel-9-pro',
      'commandType': 'SIGN_OUT',
      'status': 'FAILED',
      'queuedAt': '2026-03-24T10:00:00.000Z',
      'deliveredAt': '2026-03-24T10:00:04.000Z',
      'completedAt': '2026-03-24T10:00:09.000Z',
      'expiresAt': '2026-03-24T10:10:00.000Z',
      'attemptCount': 2,
      'resultMessage': 'Local action could not complete.',
      'failureCode': 'LOCAL_ACTION_FAILED',
    });

    expect(command.commandId, 'cmd-01');
    expect(command.commandType, RemoteCommandType.signOut);
    expect(command.status, RemoteCommandStatus.failed);
    expect(command.attemptCount, 2);
    expect(command.failureCode, 'LOCAL_ACTION_FAILED');
    expect(command.deliveredAt?.toIso8601String(), '2026-03-24T10:00:04.000Z');
    expect(command.expiresAt.toIso8601String(), '2026-03-24T10:10:00.000Z');
    expect(command.isPending, isFalse);
  });
}
