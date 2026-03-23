import { listSecurityEvents } from '../../common/mock/control-plane-data.js';

export class SecurityEventsService {
  listEvents() {
    return listSecurityEvents();
  }

  markRead(eventId: string) {
    return {
      eventId,
      unread: false,
      readAt: new Date().toISOString(),
    };
  }
}

export const securityEventsService = new SecurityEventsService();
