import { createHmac } from 'node:crypto';
import { prisma } from '../db/prisma.js';
import { env } from '../../config/env.js';

const WINDOW_MINUTES = 15;
type BucketResult = { attempts: number; windowStartedAt: Date };

export async function enforceAuthRateLimits(requestIp: string, identifier: string | undefined, scope: 'login' | 'invitation') {
  const limits = scope === 'login' ? [{ scope: 'ip', value: requestIp, maximum: 30 }, ...(identifier ? [{ scope: 'identity', value: identifier.trim().toLowerCase(), maximum: 8 }] : [])] : [{ scope: 'ip', value: requestIp, maximum: 10 }, ...(identifier ? [{ scope: 'invitation', value: identifier.trim().toUpperCase(), maximum: 5 }] : [])];
  await prisma.$executeRaw`DELETE FROM "AuthRateLimitBucket" WHERE "windowStartedAt" < CURRENT_TIMESTAMP - INTERVAL '1 day'`;
  for (const limit of limits) {
    const key = createHmac('sha256', env.JWT_REFRESH_SECRET).update('auth-rate-limit:').update(scope).update(':').update(limit.scope).update(':').update(limit.value).digest('hex');
    const rows = await prisma.$queryRaw<BucketResult[]>`
      INSERT INTO "AuthRateLimitBucket" ("key", "windowStartedAt", "attempts", "updatedAt") VALUES (${key}, CURRENT_TIMESTAMP, 1, CURRENT_TIMESTAMP)
      ON CONFLICT ("key") DO UPDATE SET
        "attempts" = CASE WHEN "AuthRateLimitBucket"."windowStartedAt" <= CURRENT_TIMESTAMP - INTERVAL '15 minutes' THEN 1 ELSE "AuthRateLimitBucket"."attempts" + 1 END,
        "windowStartedAt" = CASE WHEN "AuthRateLimitBucket"."windowStartedAt" <= CURRENT_TIMESTAMP - INTERVAL '15 minutes' THEN CURRENT_TIMESTAMP ELSE "AuthRateLimitBucket"."windowStartedAt" END,
        "updatedAt" = CURRENT_TIMESTAMP RETURNING "attempts", "windowStartedAt"
    `;
    const bucket = rows[0];
    if (bucket != null && bucket.attempts > limit.maximum) {
      const resetAt = bucket.windowStartedAt.getTime() + WINDOW_MINUTES * 60_000;
      const retryAfterSeconds = Math.max(1, Math.ceil((resetAt - Date.now()) / 1000));
      throw Object.assign(new Error('Too many authentication attempts. Try again later.'), { statusCode: 429, retryAfterSeconds });
    }
  }
}
