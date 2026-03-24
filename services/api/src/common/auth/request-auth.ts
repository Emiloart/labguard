import type { FastifyReply, FastifyRequest } from 'fastify';

import { isAccessTokenValid } from '../mock/control-plane-data.js';

const publicRoutes = new Set<string>([
  'GET /v1/health',
  'POST /v1/auth/login',
  'POST /v1/auth/invitations/accept',
  'POST /v1/auth/refresh',
]);

export function requireLabGuardAuth(
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

  if (!isAccessTokenValid(accessToken)) {
    return reply.code(401).send({
      error: 'Unauthorized',
      message: 'A valid LabGuard access token is required.',
      requestId: request.id,
    });
  }
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
