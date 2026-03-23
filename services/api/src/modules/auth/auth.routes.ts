import type { FastifyPluginAsync } from 'fastify';

import { authService } from './auth.service.js';

export const authRoutes: FastifyPluginAsync = async (app) => {
  app.post('/invitations/accept', async () => {
    return authService.acceptInvitation();
  });

  app.post('/login', async () => {
    return authService.login();
  });

  app.post('/refresh', async () => {
    return authService.refresh();
  });

  app.get('/session', async () => {
    return authService.getSession();
  });

  app.post('/logout', async () => {
    return authService.logout();
  });
};
