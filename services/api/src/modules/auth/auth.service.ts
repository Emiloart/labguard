import {
  clearIssuedSession,
  getSessionSnapshot,
  issueLoginSession,
  recordAuditLogEntry,
  rotateRefreshSession,
} from '../../common/mock/control-plane-data.js';

export class AuthService {
  acceptInvitation() {
    recordAuditLogEntry({
      action: 'INVITATION_ACCEPTED',
      targetType: 'AUTH',
      targetId: viewerId,
      summary: 'An invitation was accepted for a trusted device session.',
    });
    return {
      invitationAccepted: true,
      deviceApprovalRequired: true,
      session: getSessionSnapshot().session,
      note: 'Phase 2 scaffold. Invite acceptance and approval still use mock control-plane data.',
    };
  }

  login() {
    recordAuditLogEntry({
      action: 'LOGIN_SUCCEEDED',
      targetType: 'AUTH',
      targetId: viewerId,
      summary: 'A trusted LabGuard session was issued.',
    });
    return issueLoginSession();
  }

  refresh() {
    const session = rotateRefreshSession();
    recordAuditLogEntry({
      action: 'SESSION_REFRESHED',
      targetType: 'AUTH',
      targetId: viewerId,
      summary: 'Access and refresh tokens were rotated.',
    });

    return {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresInSeconds: session.expiresInSeconds,
      session: session.session,
    };
  }

  getSession() {
    return getSessionSnapshot();
  }

  logout() {
    clearIssuedSession();
    recordAuditLogEntry({
      action: 'LOGOUT_COMPLETED',
      targetType: 'AUTH',
      targetId: viewerId,
      summary: 'The active LabGuard session was revoked.',
    });
    return {
      revoked: true,
    };
  }
}

export const authService = new AuthService();

const viewerId = 'user-owner-01';
