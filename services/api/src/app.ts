import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import sensible from '@fastify/sensible';
import Fastify, { type FastifyError } from 'fastify';

import { requestContextPlugin } from './common/plugins/request-context.js';
import { env } from './config/env.js';
import { adminRoutes } from './modules/admin/admin.routes.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { dashboardRoutes } from './modules/dashboard/dashboard.routes.js';
import { devicesRoutes } from './modules/devices/devices.routes.js';
import { healthRoutes } from './modules/health/health.routes.js';
import { preferencesRoutes } from './modules/preferences/preferences.routes.js';
import { remoteActionsRoutes } from './modules/remote-actions/remote-actions.routes.js';
import { securityEventsRoutes } from './modules/security-events/security-events.routes.js';
import { vpnRoutes } from './modules/vpn/vpn.routes.js';

export async function buildApp() {
  const app = Fastify({
    logger:
      env.NODE_ENV === 'development'
        ? {
            level: env.LOG_LEVEL,
            transport: {
              target: 'pino-pretty',
              options: {
                colorize: true,
                translateTime: 'SYS:standard',
              },
            },
          }
        : { level: env.LOG_LEVEL },
  });

  await app.register(cors, {
    origin: true,
    credentials: true,
  });

  await app.register(helmet, {
    contentSecurityPolicy: false,
  });

  await app.register(sensible);
  await app.register(requestContextPlugin);

  app.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error({ err: error }, 'request failed');

    if (reply.sent) {
      return;
    }

    const statusCode = error.statusCode ?? 500;
    const safeMessage =
      statusCode >= 500 ? 'An unexpected error occurred.' : error.message;

    reply.status(statusCode).send({
      error: error.name,
      message: safeMessage,
      requestId: request.id,
    });
  });

  await app.register(async (v1) => {
    await v1.register(healthRoutes, { prefix: '/health' });
    await v1.register(authRoutes, { prefix: '/auth' });
    await v1.register(dashboardRoutes, { prefix: '/dashboard' });
    await v1.register(devicesRoutes, { prefix: '/devices' });
    await v1.register(vpnRoutes, { prefix: '/vpn' });
    await v1.register(preferencesRoutes, { prefix: '/preferences' });
    await v1.register(remoteActionsRoutes, { prefix: '/remote-actions' });
    await v1.register(securityEventsRoutes, { prefix: '/security-events' });
    await v1.register(adminRoutes, { prefix: '/admin' });
  }, { prefix: '/v1' });

  return app;
}
