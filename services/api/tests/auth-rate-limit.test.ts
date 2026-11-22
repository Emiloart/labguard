import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { readFile } from 'node:fs/promises';
describe('authentication rate limiting', () => {
  it('defines persistent atomic PostgreSQL buckets', async () => {
    const sql = await readFile(new URL('../prisma/migrations/20261122000200_add_auth_rate_limit_buckets/migration.sql', import.meta.url), 'utf8');
    assert.match(sql, /CREATE TABLE "AuthRateLimitBucket"/);
    assert.match(sql, /PRIMARY KEY \("key"\)/);
    assert.match(sql, /windowStartedAt/);
  });
  it('uses keyed hashes and distinct login and invitation thresholds', async () => {
    const source = await readFile(new URL('../src/common/auth/auth-rate-limit.ts', import.meta.url), 'utf8');
    assert.match(source, /createHmac\('sha256'/);
    assert.match(source, /maximum: 30/);
    assert.match(source, /maximum: 8/);
    assert.match(source, /maximum: 10/);
    assert.match(source, /maximum: 5/);
    assert.match(source, /ON CONFLICT/);
  });
});
