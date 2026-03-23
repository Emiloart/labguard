# LabGuard Security Hardening Checklist

## Mobile

- Use `flutter_secure_storage` or keystore-backed secure storage for tokens and VPN secrets
- Never log tokens, invite codes, refresh material, or WireGuard private keys
- Gate app unlock with biometrics and optional PIN
- Clear sensitive state on logout, revoke, or wipe-app-data command
- Use explicit permission rationale flows for notifications and location
- Only elevate location frequency in user-visible lost mode
- Prepare for process death by restoring only sanitized state

## Android VPN

- Use Android `VpnService` correctly
- Keep VPN lifecycle in a foreground service with a clear notification
- Enforce kill switch only through supported OS/network behavior
- Handle network transitions idempotently
- Store active profile state and revocation markers safely

## Backend

- Hash refresh tokens and invite codes
- Encrypt VPN private material at rest
- Enforce account scoping on every device, server, and command query
- Record all sensitive actions in `audit_logs`
- Prefer short-lived access tokens with refresh rotation
- Validate input at route boundaries
- Use request IDs for traceability

## Operations

- Separate development, staging, and production secrets
- Maintain server key rotation procedures
- Build a device revocation runbook
- Alert on suspicious login, repeated failed approval, and unexpected VPN disconnect patterns
