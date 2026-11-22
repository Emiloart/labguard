# P0 Authentication Hardening

## Scope

This change removes identity-only authentication and the fixed seeded invitation code. Authentication now requires a password verifier stored on the user record.

## Changes

- Added nullable `User.passwordHash` and a database migration.
- Passwords are hashed with Node.js scrypt using a per-password random salt and a versioned parameter encoding.
- Login rejects unknown, inactive, passwordless, or incorrectly authenticated users with the same generic credential error.
- Invitation acceptance requires an email, a valid unexpired invitation, and a password of at least 12 characters. Email-bound invitations must match the supplied identity.
- Existing invited accounts without a password can establish one only by accepting a valid invitation; existing accounts with a password cannot overwrite it through invitation acceptance.
- Removed the fixed `EMILO-TRUST-01` invitation seed and automatic owner identity creation.
- Initial production owner creation requires `LABGUARD_BOOTSTRAP_OWNER_EMAIL` and `LABGUARD_BOOTSTRAP_OWNER_PASSWORD`. Existing legacy owner records with no password hash can be initialized once when the configured email matches.
- The mobile sign-in form now submits a password rather than relying on an identity alone.

## Deployment procedure

1. Back up the production database.
2. This incremental migration assumes the existing database already has the LabGuard tables from the current Prisma schema. The repository did not previously contain a baseline migration. Do not run this migration against an empty database; create and validate a baseline migration first for any fresh environment.
3. Back up PostgreSQL, then apply the incremental migration: `pnpm --dir services/api prisma:deploy`.
4. For a first-time production database, configure both bootstrap owner variables with a unique email and a strong password of at least 12 characters before the API starts.
5. For a database with the legacy `owner@emilolabs.com` owner record, set the bootstrap email to that exact account email and configure a strong password. Startup will populate the password hash only if it is currently null.
6. Remove `LABGUARD_BOOTSTRAP_OWNER_EMAIL` and `LABGUARD_BOOTSTRAP_OWNER_PASSWORD` from the runtime environment after the owner password is initialized.
7. Issue fresh invitation codes from the authenticated owner account for members who need to establish credentials.
8. The migration revokes all active sessions created before password verification. The API startup also revokes any still-pending legacy fixed-code invitation when its former signing secret is unchanged. Review existing audit logs and access history.

## Release gates still required

- Add automated tests for password hashing, invalid credentials, inactive users, invitation expiry, email-bound invitations, one-time invitation consumption, and legacy owner initialization.
- Add distributed login rate limiting and abuse monitoring before public exposure.
- Complete full device testing of the mobile password sign-in and invitation-acceptance flows.
- Verify migration and bootstrap behavior against a disposable PostgreSQL database and the production-like deployment environment.
- Review and rotate credentials or secrets that may have been exposed through earlier development defaults.

This is the first P0 remediation pass, not a declaration that authentication is fully production-ready. The release gates above remain mandatory.
