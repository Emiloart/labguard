ALTER TABLE "User" ADD COLUMN "passwordHash" TEXT;

-- Invalidate sessions created before password verification was enforced.
UPDATE "Session"
SET "status" = 'REVOKED',
    "revokedAt" = CURRENT_TIMESTAMP,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "status" = 'ACTIVE';
