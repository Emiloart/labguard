import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  listSecurityEvents,
  markSecurityEventRead,
} from '../../common/control-plane/control-plane-service.js';

export class SecurityEventsService {
  listEvents(actor: LabGuardActor) {
    return listSecurityEvents(actor);
  }

  markRead(actor: LabGuardActor, eventId: string) {
    return markSecurityEventRead(actor, eventId);
  }
}

export const securityEventsService = new SecurityEventsService();
