# LabGuard Data Model

## Core Principles

- Every user belongs to an account boundary.
- Every device is modeled explicitly and can be approved, suspended, revoked, or marked lost independently.
- VPN credentials are per device.
- Sensitive actions generate both security events and audit logs.
- Lost-device telemetry is explicit and state-driven, not ambient surveillance.

## Main Entities

### `accounts`

- Tenant boundary for the trusted user group
- Owns users, devices, invitations, servers, and audit context

### `users`

- Human account members
- Roles begin with `OWNER` and `MEMBER`
- Backed by sessions, invitations, and preferences

### `invitations`

- Invite-code or email-driven onboarding records
- Stores inviter, expiry, acceptance state, and a hashed code/token

### `sessions`

- Refresh-token session records
- Track revocation, expiry, IP, user agent, and last use

### `devices`

- Canonical registry of enrolled devices
- Holds trust state, approval, operational state, last network, battery, and lost-mode status

### `device_sessions`

- VPN connectivity and device heartbeat snapshots
- Records current public IP, connected/disconnected timestamps, and last heartbeat

### `vpn_servers`

- Current and future VPN exit nodes
- Region/priority metadata supports later multi-server expansion

### `vpn_profiles`

- Per-device WireGuard credentials and provisioning lifecycle
- Private and preshared keys are stored encrypted at rest

### `device_locations`

- Explicit location samples tied to a device
- Distinguishes normal and lost-mode capture context

### `remote_commands`

- Authenticated action requests sent to a device
- Examples: sign out, wipe app data, ring alarm, rotate session, disable device

### `remote_command_results`

- Execution acknowledgements and outcome details for remote commands

### `security_events`

- User-visible security feed with severity, summaries, read state, and device/user association

### `audit_logs`

- Immutable security/operations trail for sensitive actions and actor intent

### `user_preferences`

- Security and UX policy toggles like biometrics, PIN, kill switch defaults, privacy preferences, and notifications

## Relationship Notes

- `account -> users`: one-to-many
- `account -> devices`: one-to-many
- `user -> sessions`: one-to-many
- `device -> vpn_profile`: one-to-many over time, one active at once
- `device -> device_locations`: one-to-many
- `device -> remote_commands`: one-to-many
- `remote_command -> remote_command_results`: one-to-many for retries and acknowledgements
- `account -> audit_logs`: one-to-many

## Security-Sensitive Storage Rules

- Refresh tokens are stored hashed, never plaintext.
- WireGuard private material is encrypted before persistence.
- Invite codes are hashed, never stored raw.
- Audit logs must capture actor, target, outcome, and request correlation ID.
