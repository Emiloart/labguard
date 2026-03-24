import {
  listSecurityEvents,
  markSecurityEventRead,
} from '../../common/mock/control-plane-data.js';

export class SecurityEventsService {
  listEvents() {
    return listSecurityEvents();
  }

  markRead(eventId: string) {
    return markSecurityEventRead(eventId);
  }
}

export const securityEventsService = new SecurityEventsService();
