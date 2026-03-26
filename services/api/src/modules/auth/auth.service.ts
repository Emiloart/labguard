import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  acceptInvitation,
  type AcceptInvitationInput,
  getSessionSnapshot,
  login,
  logout,
  refresh,
  type LoginInput,
} from '../../common/control-plane/control-plane-service.js';

export class AuthService {
  acceptInvitation(input: AcceptInvitationInput) {
    return acceptInvitation(input);
  }

  login(input: LoginInput) {
    return login(input);
  }

  refresh(refreshToken?: string) {
    return refresh(refreshToken);
  }

  getSession(actor: LabGuardActor) {
    return getSessionSnapshot(actor);
  }

  logout(actor: LabGuardActor) {
    return logout(actor);
  }
}

export const authService = new AuthService();
