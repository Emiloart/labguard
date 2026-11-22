CREATE TABLE "AuthRateLimitBucket" (
    "key" VARCHAR(64) NOT NULL,
    "windowStartedAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "AuthRateLimitBucket_pkey" PRIMARY KEY ("key")
);
CREATE INDEX "AuthRateLimitBucket_windowStartedAt_idx" ON "AuthRateLimitBucket"("windowStartedAt");
