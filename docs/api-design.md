# LabGuard API Design

All endpoints are versioned under `/v1`.

## Auth / Access

- `POST /v1/auth/invitations/accept`
  Accept an invite with code or token and create a member record.
- `POST /v1/auth/login`
  Issue access and refresh tokens, begin device approval flow if needed.
- `POST /v1/auth/refresh`
  Rotate access token from a valid refresh session.
- `POST /v1/auth/logout`
  Revoke the current session.

## Devices

- `GET /v1/devices`
  List devices visible to the current account.
- `POST /v1/devices/register`
  Register a device and start approval/profile provisioning workflow.
- `GET /v1/devices/:deviceId`
  Load a single device detail view.
- `PATCH /v1/devices/:deviceId`
  Rename, tag primary, or update mutable metadata.
- `POST /v1/devices/:deviceId/revoke`
  Revoke device access and invalidate active VPN/session credentials.
- `POST /v1/devices/:deviceId/suspend`
  Suspend the device without permanent deletion.
- `POST /v1/devices/:deviceId/rotate-credentials`
  Rotate device session and provisioning credentials.
- `POST /v1/devices/:deviceId/lost-mode`
  Enable lost mode and raise location update expectations explicitly.
- `POST /v1/devices/:deviceId/recovered`
  Mark a device recovered and restore normal policy.
- `POST /v1/devices/:deviceId/location`
  Push a location update when policy allows.

## VPN

- `GET /v1/vpn/servers`
  List available VPN servers and current assignments.
- `GET /v1/vpn/profiles/:deviceId`
  Fetch the active WireGuard profile for an approved device.
- `POST /v1/vpn/profiles/:deviceId/rotate`
  Rotate the active VPN profile.
- `POST /v1/vpn/profiles/:deviceId/revoke`
  Revoke the active profile.
- `POST /v1/vpn/sessions/heartbeat`
  Report connection status, current public IP, bytes, and heartbeat metadata.

## Remote Actions

- `POST /v1/remote-actions/:deviceId`
  Queue a signed remote command.
- `GET /v1/remote-actions/:deviceId`
  List queued and historical remote commands for a device.
- `POST /v1/remote-actions/:commandId/result`
  Report execution result from the target device.

## Security Events

- `GET /v1/security-events`
  Fetch the account security feed.
- `POST /v1/security-events/:eventId/read`
  Mark an event read.

## Admin

- `GET /v1/admin/overview`
  Account, device, command, and server summary for owner/admin use.
- `GET /v1/admin/audit-logs`
  Search audit history with filters.
- `POST /v1/admin/invitations`
  Issue a new invitation.

## Operational Rules

- Sensitive endpoints require account-scoped authorization, not just authentication.
- Remote commands are asynchronous and auditable.
- Device state transitions must be idempotent where possible.
- Session rotation revokes previous refresh material on success.
