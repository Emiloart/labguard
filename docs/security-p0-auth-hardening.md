# P0 Authentication Hardening

## Scope

This remediation removes identity-only authentication, removes the fixed seeded invitation path, adds password-based account access, and introduces database-backed authentication throttling. It is a security-hardening milestone, not a production-readiness declaration.

## Implemented controls

- Added nullable `User.passwordHash` and an incremental migration.
- Passwords are hashed with Node.js scrypt using a per-password random salt and encoded work parameters. Verification uses constant-time comparison.
- Login rejects unknown, inactive, passwordless, or incorrectly authenticated users with a generic credential error.
- Invitation acceptance requires an email, a valid unexpired invitation, and a password of 12–256 characters. Email-bound invitations must match the supplied identity.
- Invitation redemption uses a conditional database update so a pending invitation can be consumed only once under concurrent requests.
- Existing invited accounts without a password can establish one only by accepting a valid invitation. Existing password-protected accounts cannot overwrite credentials through invitation acceptance.
- Removed the fixed `EMILO-TRUST-01` invitation seed and automatic owner identity creation.
- Initial owner creation requires `LABGUARD_BOOTSTRAP_OWNER_EMAIL` and `LABGUARD_BOOTSTRAP_OWNER_PASSWORD`. A matching legacy passwordless owner can be initialized once. Remove both variables after initialization.
- Active sessions are revoked by the password migration.
- Login and invitation acceptance use PostgreSQL-backed, atomic fixed-window counters. Identifiers are HMACed before storage; raw email addresses and invitation codes are not written to rate-limit buckets.
- Current limits are 30 login attempts per IP and 8 per normalized identity per 15-minute window; invitation acceptance is limited to 10 attempts per IP and 5 per invitation code per 15-minute window. Rejections return HTTP 429 and a `Retry-After` header.
- Rate-limit bucket rows older than one day are pruned during authentication traffic.

## Migration history limitation

The repository did not have a baseline Prisma migration before the password-hardening change. The two committed SQL migrations are incremental:
1. `20261122000100_add_user_password_hash` adds `User.passwordHash` and revokes active sessions.
2. `20261122000200_add_auth_rate_limit_buckets` creates the rate-limit bucket table.

They assume the pre-existing LabGuard schema is already present. The CI workflow currently creates its disposable schema with `prisma db push` and applies the rate-limit SQL directly to test the rate limiter. It does **not** prove that `prisma migrate deploy` can build a fresh database from an empty schema, nor does it validate the full migration history.

Do not run `prisma migrate deploy` against production or a fresh database until a reviewed baseline migration and an adoption procedure for already-provisioned databases have been created and tested.

## Deployment procedure (not yet authorized for production)

1. Back up the database and verify a tested restore path.
2. Identify whether the target database was created with `prisma db push` or has an existing migration history. Do not guess.
3. Generate a baseline from the exact pre-hardening Prisma schema and review the SQL against a clean PostgreSQL database.
4. Test two paths independently: a genuinely empty database using the baseline plus incremental migrations; and a copy of the existing provisioned schema using a documented `prisma migrate resolve` adoption procedure.
5. Verify that migration #1 revokes active sessions and migration #2 creates the exact table/index expected by the application.
6. Configure bootstrap owner variables only for the controlled first initialization. Use a unique email and a strong password of at least 12 characters.
7. Remove bootstrap variables after initialization. Confirm no default owner or fixed invitation remains usable.
8. Verify login, invitation acceptance, refresh, logout, and rate-limit behavior before opening access.

## Verification currently available

- GitHub Actions provisions PostgreSQL 16.
- CI runs Prisma Client generation, creates a disposable schema using `prisma db push`, applies the rate-limit table SQL, and runs the PostgreSQL-backed rate-limit tests, API typecheck, and API build.
- The rate-limit tests cover the per-identity login threshold and per-invitation-code threshold.
- This does not yet cover route-level HTTP behavior, IP thresholds, concurrent requests, password hashing/login behavior, invitation expiry/email binding/single-use behavior, bootstrap behavior, or migration deployment from empty.

## Remaining release gates

- Fix and pass the current CI test suite; the first PostgreSQL-backed run exposed a syntax error in the test setup.
- Add behavioral integration tests for password hashing, invalid credentials, inactive users, invitation expiry, email-bound invitations, concurrent one-time redemption, owner bootstrap, IP limits, and HTTP 429/Retry-After behavior.
- Add monitoring and alerting for authentication abuse and database failures. Do not convert database errors into rate-limit responses.
- Keep Fastify proxy trust restrictive and explicitly configure trusted reverse proxies; otherwise client-supplied forwarding headers can undermine IP-based limits.
- Review synchronous `scryptSync` CPU impact under concurrent login load and move to asynchronous scrypt or bounded worker execution if load testing warrants it.
- Review rate-limit cleanup write overhead and define an operational cleanup strategy as traffic grows.
- Verify migration and bootstrap behavior against a disposable PostgreSQL database and a production-like deployment.
- Complete physical Android testing of password sign-in and invitation acceptance.
- Review and rotate credentials or secrets that may have been exposed through earlier development defaults.

## Operational constraints

- Rate limiting depends on PostgreSQL availability and the configured `JWT_REFRESH_SECRET` for HMAC key derivation. Secret rotation changes bucket identifiers and effectively resets existing counters; plan this as part of rotation operations.
- Do not trust arbitrary `X-Forwarded-For` headers. Configure Fastify's `trustProxy` only for known proxy hops/networks.
- Limits are fixed-window controls, not a substitute for WAF controls, credential-stuffing detection, MFA, alerting, or account recovery protections.
- Never log passwords, raw invitation codes, access tokens, refresh tokens, or private VPN keys.

This document records implemented repository controls and outstanding validation. It does not claim production deployment, a completed database migration, or successful physical-device verification.
