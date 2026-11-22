import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { randomUUID } from 'node:crypto';
import { prisma } from '../src/common/db/prisma.js';
import { enforceAuthRateLimits } from '../src/common/auth/auth-rate-limit.js';

describe('PostgreSQL-backed authentication rate limits', () => {
  before(async () => {
    await prisma.$executeRawUnsafe('DELETE FROM "AuthRateLimitBucket"');
  });

  after(async () => {
    await prisma.$executeRawUnsafe('DELETE FROM "AuthRateLimitBucket"');
    await prisma.$disconnect();
  });

  it('blocks login attempts after the per-identity threshold', async () => {
    const ip = `192.0.2.${Math.floor(Math.random() * 200) + 1}`;
    const identity = `rate-limit-${randomUUID()}@example.invalid`;
    for (let attempt = 0; attempt < 8; attempt += 1) {
      await enforceAuthRateLimits(ip, identity, 'login');
    }
    await assert.rejects(
      enforceAuthRateLimits(ip, identity, 'login'),
      (error: unknown) => error != null && typeof error === 'object' && 'statusCode' in error && error.statusCode === 429,
    );
  });

  it('blocks invitation redemption attempts after the per-code threshold', async () => {
    const ip = `198.51.100.${Math.floor(Math.random() * 200) + 1}`;
    const inviteCode = `TEST-${randomUUID()}`;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await enforceAuthRateLimits(ip, inviteCode, 'invitation');
    }
    await assert.rejects(
      enforceAuthRateLimits(ip, inviteCode, 'invitation'),
      (error: unknown) => error != null && typeof error === 'object' && 'statusCode' in error && error.statusCode === 429,
    );
  });
});
