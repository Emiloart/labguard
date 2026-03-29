import type { FastifyPluginAsync } from 'fastify';

import { getPublicHealthSnapshot } from '../../common/control-plane/control-plane-service.js';

export const healthRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async () => {
    return getPublicHealthSnapshot();
  });
};
