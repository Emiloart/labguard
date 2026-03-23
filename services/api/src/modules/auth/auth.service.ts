import {
  getAuthSessionEnvelope,
  getSessionSnapshot,
} from '../../common/mock/control-plane-data.js';

export class AuthService {
  acceptInvitation() {
    return {
      invitationAccepted: true,
      deviceApprovalRequired: true,
      session: getSessionSnapshot().session,
      note: 'Phase 2 scaffold. Invite acceptance and approval still use mock control-plane data.',
    };
  }

  login() {
    return getAuthSessionEnvelope();
  }

  refresh() {
    const session = getAuthSessionEnvelope();

    return {
      accessToken: session.accessToken,
      expiresInSeconds: session.expiresInSeconds,
      session: session.session,
    };
  }

  getSession() {
    return getSessionSnapshot();
  }

  logout() {
    return {
      revoked: true,
    };
  }
}

export const authService = new AuthService();
