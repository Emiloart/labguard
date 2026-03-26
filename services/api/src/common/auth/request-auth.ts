import type { FastifyReply, FastifyRequest } from 'fastify';

import type { LabGuardActor } from './auth-types.js';
import { authenticateAccessToken } from '../control-plane/control-plane-service.js';

const publicRoutes = new Set<string>([
  'GET /v1/health',
  'POST /v1/auth/login',
  'POST /v1/auth/invitations/accept',
  'POST /v1/auth/refresh',
]);

export async function requireLabGuardAuth(
  request: FastifyRequest,
  reply: FastifyReply,
) {
  if (request.method.toUpperCase() == 'OPTIONS') {
    return;
  }

  const routeKey = `${request.method.toUpperCase()} ${normalizePath(request.url)}`;

  if (publicRoutes.has(routeKey)) {
    return;
  }

  const authorization = request.headers.authorization;
  const accessToken = extractBearerToken(authorization);
  const actor = await authenticateAccessToken(accessToken);

  if (actor == null) {
    return reply.code(401).send({
      error: 'Unauthorized',
      message: 'A valid LabGuard access token is required.',
      requestId: request.id,
    });
  }

  request.labguardActor = actor;
}

export function requireActor(request: FastifyRequest): LabGuardActor {
  if (request.labguardActor == null) {
    throw Object.assign(new Error('A valid LabGuard session is required.'), {
      statusCode: 401,
    });
  }

  return request.labguardActor;
}

function extractBearerToken(authorization?: string) {
  if (authorization == null) {
    return undefined;
  }

  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1];
}

function normalizePath(url: string) {
  const path = url.split('?')[0] ?? '';
  if (path.length > 1 && path.endsWith('/')) {
    return path.slice(0, -1);
  }

  return path;
}
