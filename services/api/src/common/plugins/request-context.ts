import type { FastifyPluginAsync } from 'fastify';

export const requestContextPlugin: FastifyPluginAsync = async (app) => {
  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });
};
