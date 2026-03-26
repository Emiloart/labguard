import type { UserRole } from '@prisma/client';

export type LabGuardActor = {
  sessionId: string;
  accountId: string;
  userId: string;
  deviceId: string;
  role: UserRole;
  displayName: string;
  email: string;
  deviceName: string;
};

declare module 'fastify' {
  interface FastifyRequest {
    labguardActor?: LabGuardActor;
  }
}
