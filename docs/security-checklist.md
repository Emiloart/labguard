# LabGuard Security Hardening Checklist

This checklist is a release gate, not a claim that the controls are already implemented. Mark items complete only after code review and test evidence.

## Mobile

- [ ] Store tokens and VPN secrets using secure storage backed by platform security facilities where appropriate.
- [ ] Never log tokens, invite codes, refresh material, WireGuard private keys, or complete VPN configurations.
- [ ] Gate app entry with biometrics only when the user enables app lock.
- [ ] Apply a centralized, explicit biometric policy to sensitive actions (including connect/disconnect and high-impact remote actions where configured); do not prompt for routine navigation.
- [ ] Clear sensitive local state on logout, revoke, and wipe-app-data command.
- [ ] Use explicit permission rationale flows for notifications and location.
- [ ] Only elevate location frequency in visible, explicit lost mode.
- [ ] Restore only sanitized state after process death.
- [ ] Verify all remote actions are authorized server-side, idempotent where possible, and report pending/success/failure states accurately.
- [ ] Profile UI jank, Flutter rebuild frequency, native channel event volume, and animation state transitions on a physical device.

## Android VPN

- [ ] Use Android `VpnService` correctly and keep its foreground notification accurate.
- [ ] Do not display a connected/usable state merely because a start request succeeded.
- [ ] Validate handshake freshness and usable traffic where the selected backend exposes those signals.
- [ ] Validate routing/AllowedIPs, DNS, MTU, forwarding/NAT, firewall rules, and IPv4/IPv6 behavior.
- [ ] Confirm internet access and DNS resolution through the tunnel from a physical device.
- [ ] Handle network transitions and reconnects idempotently; use bounded backoff rather than tight retry loops.
- [ ] Keep the VPN functional when the developer laptop is powered off and disconnected.
- [ ] Enforce kill-switch behavior only through supported Android OS settings and accurately explain required user action.
- [ ] Store active profile state and revocation markers safely.
- [ ] Measure battery drain in connected idle, active traffic, background, reconnect, and lost-device modes.

## Region Readiness

- [ ] London and San Francisco each have a real deployed WireGuard server and independent endpoint.
- [ ] Endpoint, public key, and expected public exit IP are supplied from verified infrastructure, never invented.
- [ ] Server public keys are checked against the deployed server configuration.
- [ ] Server firewall, forwarding, NAT, DNS, updates, access control, and monitoring are configured.
- [ ] Region readiness reflects valid configuration and server health, not only non-empty environment variables.
- [ ] The selected region's observed public egress IP matches its declared exit IP.
- [ ] A missing/unhealthy region is unavailable in the UI; no fallback silently routes to another region.
- [ ] Server private keys remain on the server and are never sent to the app or committed to Git.

## Backend

- [ ] Replace or explicitly secure development bootstrap and seeded control-plane behavior before production.
- [ ] Hash refresh tokens and invitation codes.
- [ ] Encrypt VPN private material at rest and limit access to provisioning services.
- [ ] Enforce account scoping on every device, server, profile, and command query.
- [ ] Record sensitive actions in audit logs with actor, target, outcome, timestamp, and correlation ID.
- [ ] Use short-lived access tokens with refresh rotation and revocation.
- [ ] Validate inputs at route boundaries and rate-limit sensitive endpoints.
- [ ] Use request IDs for traceability without leaking secrets or sensitive location data.
- [ ] Keep production secrets outside source control and example files.

## Operations

- [ ] Separate development, staging, and production configuration and secrets.
- [ ] Maintain server key rotation and device revocation procedures.
- [ ] Maintain a tested server replacement/restore procedure.
- [ ] Alert on suspicious login, repeated failed approval, server health failures, and unexpected VPN disconnect patterns.
- [ ] Document location-data retention and access policy.
- [ ] Confirm API and VPN endpoints are publicly reachable only as intended and do not depend on a developer laptop.
