import type { FastifyPluginAsync } from 'fastify';

export const healthRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async () => {
    return {
      status: 'ok',
      service: 'labguard-api',
      brandAttribution: 'Built by Emilo Labs',
      timestamp: new Date().toISOString(),
    };
  });
};
