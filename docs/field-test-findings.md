# LabGuard Field-Test Findings and Remediation

## Purpose

This document records issues observed while testing LabGuard on a physical Android phone. Each issue remains open until the root cause is identified, a fix is tested, and evidence is recorded.

## Current Release-Blocking Findings

### F-01: UI glitching

**Observed:** UI transitions and/or rendering glitch during real-device use.

**Investigation targets:** Flutter rebuild frequency, provider invalidation, duplicate platform-channel events, animation restarts, and lifecycle races between API state, local state, and native tunnel state.

**Acceptance criteria:** Repeated navigation and connect/disconnect operations produce no flicker, layout jumps, stuck loaders, or duplicate transitions. Profile on a physical device and record results.

### F-02: VPN activates but internet access fails

**Observed:** Android shows the VPN as enabled, but internet traffic does not work.

**Priority:** Highest functional priority. Do not mask this with UI changes.

**Debug in order:** Confirm profile endpoint/server key; verify deployed WireGuard reachability and handshake; inspect transfer counters; verify Android addresses, routes, AllowedIPs, DNS, and MTU; verify server forwarding, NAT, firewall, return routing, and outbound access; test DNS separately from direct-IP connectivity; test IPv4/IPv6 independently; ensure UI state reflects actual tunnel signals.

**Acceptance criteria:** Multiple external sites load after connection, DNS resolves according to policy, disconnect restores normal networking, reconnect/network changes recover safely, and UI does not imply end-to-end validation that has not occurred.

### F-03: Biometric prompts are too broad

**Required policy:** Biometrics may gate app opening when app lock is enabled and configured sensitive actions such as VPN connect/disconnect or high-impact remote security actions. Do not prompt during routine navigation or harmless settings inspection. Centralize policy and handle unavailable biometrics, cancellation, lockout, and fallback behavior.

**Acceptance criteria:** A test matrix covers app lock on/off, connect/disconnect, remote actions, routine navigation, cancellation, and biometric unavailability.

### F-04: VPN must not depend on the developer laptop

The VPN service and API must remain available when the developer laptop is offline.

**Required architecture:** Deploy WireGuard exit nodes and API/database on always-on remote infrastructure; configure release builds with remotely reachable HTTPS and WireGuard endpoints; keep local endpoints development-only; document operations, key rotation, monitoring, backups, and recovery.

**Acceptance criteria:** With the laptop powered off and USB debugging disconnected, an authorized phone can authenticate, retrieve a valid profile, connect, and pass traffic through the deployed server.

### F-05: Battery consumption is excessive

Measure before optimizing. Compare connected-idle, active-traffic, background, reconnect, and lost-mode scenarios. Investigate polling, heartbeats, WorkManager duplication, reconnect loops, location tracking, platform events, wake locks, foreground service work, and release logging.

**Acceptance criteria:** Record baseline and post-fix measurements; normal mode performs no continuous location tracking; retries use bounded backoff with jitter; remove redundant periodic work where event-driven mechanisms are available.

### F-06: London and San Francisco regions are not provisioned

The repository defines environment variable names, but real endpoint, server public key, confirmed exit IP, and infrastructure access are not available in the current workspace.

Required variables:

- `VPN_SERVER_LONDON_ENDPOINT`
- `VPN_SERVER_LONDON_PUBLIC_KEY`
- `VPN_SERVER_LONDON_EXIT_IP`
- `VPN_SERVER_SF_ENDPOINT`
- `VPN_SERVER_SF_PUBLIC_KEY`
- `VPN_SERVER_SF_EXIT_IP`

DNS variables are also defined in the example environment file.

Do not invent endpoints, keys, exit IPs, SSH targets, cloud credentials, or deployment claims. Server private keys must never be copied into client configuration, committed, or sent to the mobile app.

**Acceptance criteria per region:** Independent node deployed in the intended location; API and node configuration agree; region-specific profile issued; handshake succeeds; traffic works; external IP confirms expected egress; unconfigured/unhealthy regions are disabled without silent fallback.

## Authentication and Backend Security Status

The P0 authentication hardening is now present on `main`: password-based login, password-protected invitation acceptance, removal of the fixed seeded invitation, one-time invitation claiming, owner bootstrap through explicit environment variables, session revocation during password migration, and PostgreSQL-backed authentication rate limiting.

The first CI run for the PostgreSQL-backed rate-limit tests failed before executing assertions because of a syntax error in the test file. The test setup is being corrected. Until a green run is recorded, these tests are not considered passed.

The Prisma migration history still lacks a baseline. CI currently uses `prisma db push` for its disposable schema, so it does not validate a clean `prisma migrate deploy` path. Do not run production migrations until baseline creation and existing-database adoption have been tested.

## Recommended Execution Order

1. Fix the VPN data path and prove working internet traffic on one deployed node.
2. Deploy/configure the API and VPN infrastructure independently of the laptop.
3. Provision London and San Francisco as independent, verifiable exit nodes.
4. Complete authentication test coverage and safe Prisma baseline/adoption strategy.
5. Correct tunnel-state reporting and biometric policy.
6. Profile battery consumption and UI glitching.
7. Audit control-plane authorization, secrets, persistence, and remote command delivery.
8. Run the release playbook and record physical-device evidence.

## Evidence Log Template

For every finding, record:

- Date and build/version:
- Device model and Android version:
- Network type and region selected:
- Reproduction steps:
- Expected result:
- Actual result:
- Logs/metrics captured (redacted):
- Root cause:
- Fix/commit:
- Automated tests:
- Physical-device retest result:
- Remaining limitations:

Never attach access tokens, private keys, full VPN profiles, or unnecessary precise location history to an issue report.
