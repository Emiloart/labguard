import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { enforceAuthRateLimits } from '../../common/auth/auth-rate-limit.js';
import { authService } from './auth.service.js';

export const authRoutes: FastifyPluginAsync = async (app) => {
  app.addHook('preHandler', async (request, reply) => {
    const route = request.routeOptions.url;
    if (request.method !== 'POST' || (route !== '/login' && route !== '/invitations/accept')) return;
    const body = (request.body ?? {}) as Record<string, unknown>;
    const identifier = route === '/login' ? (typeof body['identity'] === 'string' ? body['identity'] : undefined) : (typeof body['inviteCode'] === 'string' ? body['inviteCode'] : undefined);
    try {
      await enforceAuthRateLimits(request.ip, identifier, route === '/login' ? 'login' : 'invitation');
    } catch (error) {
      const retryAfter = error != null && typeof error === 'object' && 'retryAfterSeconds' in error ? Number(error.retryAfterSeconds) : 60;
      reply.header('retry-after', String(Math.max(1, retryAfter)));
      return reply.code(429).send({ error: 'TooManyRequests', message: 'Too many authentication attempts. Try again later.', requestId: request.id });
    }
  });
  app.post('/invitations/accept', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;

    return authService.acceptInvitation({
      ...(typeof body['identity'] == 'string' ? { identity: body['identity'] } : {}),
      ...(typeof body['inviteCode'] == 'string' ? { inviteCode: body['inviteCode'] } : {}),
      ...(typeof body['password'] == 'string' ? { password: body['password'] } : {}),
      device: parseDeviceRegistration(body['device']),
      ipAddress: request.ip,
      userAgent: requestUserAgent(request),
    });
  });

  app.post('/login', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;

    return authService.login({
      ...(typeof body['identity'] == 'string' ? { identity: body['identity'] } : {}),
      ...(typeof body['password'] == 'string' ? { password: body['password'] } : {}),
      device: parseDeviceRegistration(body['device']),
      ipAddress: request.ip,
      userAgent: requestUserAgent(request),
    });
  });

  app.post('/refresh', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    return authService.refresh(
      typeof body['refreshToken'] == 'string' ? body['refreshToken'] : undefined,
    );
  });

  app.get('/session', async (request) => {
    return authService.getSession(requireActor(request));
  });

  app.post('/logout', async (request) => {
    return authService.logout(requireActor(request));
  });
};

function parseDeviceRegistration(value: unknown) {
  if (value == null || typeof value != 'object' || Array.isArray(value)) {
    return undefined;
  }

  const body = value as Record<string, unknown>;

  return {
    ...(typeof body['clientId'] == 'string' ? { clientId: body['clientId'] } : {}),
    ...(typeof body['name'] == 'string' ? { name: body['name'] } : {}),
    ...(typeof body['model'] == 'string' ? { model: body['model'] } : {}),
    ...(typeof body['platform'] == 'string' ? { platform: body['platform'] } : {}),
    ...(typeof body['osVersion'] == 'string' ? { osVersion: body['osVersion'] } : {}),
    ...(typeof body['appVersion'] == 'string' ? { appVersion: body['appVersion'] } : {}),
  };
}

function requestUserAgent(request: { headers: Record<string, unknown> }) {
  const userAgent = request.headers['user-agent'];
  return typeof userAgent == 'string' ? userAgent : undefined;
}
