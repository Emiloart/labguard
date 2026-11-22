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

### F-07: WireGuard peer provisioning is incomplete

**Code-audit finding (2026-11-22):** The API's `createVpnProfile` currently calls `randomWireGuardKey()` separately for the client private key and client public key. These are two independent random values; a valid WireGuard public key must be derived from its corresponding private key using Curve25519. The resulting profile is not a valid client keypair.

The control plane also persists the generated client public key in PostgreSQL but has no implemented server-side peer-registration/reconciliation path to install that public key (and assigned address) on the selected WireGuard node. Profile creation therefore does not make the node aware of the client.

**Impact:** Even with a real VPS and correct endpoint/server public key environment variables, the current profile issuance path cannot be assumed to establish a working tunnel. Do not deploy a node and treat environment configuration as sufficient.

**Required remediation:**
1. Generate a valid client keypair using a maintained WireGuard-compatible implementation; derive and verify the public key from the private key. Prefer generating the client private key on-device so it never leaves Android. If server-side generation is temporarily retained, encrypt it at rest and strictly constrain profile delivery.
2. Add authenticated, idempotent peer provisioning and revocation between the control plane and the node. Use a narrow node agent or a hardened server-side provisioning channel; do not expose an unauthenticated `wg` management endpoint.
3. Make peer provisioning transactional in behavior: a profile is not reported ready until the node confirms the peer and address are installed. Handle retries, rotation, revocation, node unavailability, and reconciliation after restarts.
4. Add tests proving public-key derivation, profile-to-peer correspondence, idempotent registration, removal/revocation, and recovery after node restart.
5. Verify the peer handshake and actual traffic from the physical Android device.

**Acceptance criteria:** The client private key matches the derived public key registered on the selected node; the node has the expected peer and allowed address; handshake and traffic work; revocation removes or disables the peer.

## Authentication and Backend Security Status

The P0 authentication hardening is now present on `main`: password-based login, password-protected invitation acceptance, removal of the fixed seeded invitation, one-time invitation claiming, owner bootstrap through explicit environment variables, session revocation during password migration, and PostgreSQL-backed authentication rate limiting.

The PostgreSQL-backed authentication rate-limit tests, API typecheck, and API build passed in GitHub Actions run [45075713706](https://github.com/Emiloart/labguard/actions/runs/45075713706) for commit `4fd3685`. Coverage currently checks per-identity login throttling and per-invitation-code throttling; it is not comprehensive authentication coverage.

The Prisma migration history still lacks a baseline. CI currently uses `prisma db push` for its disposable schema, so it does not validate a clean `prisma migrate deploy` path. Do not run production migrations until baseline creation and existing-database adoption have been tested.

## Recommended Execution Order

1. Correct client WireGuard keypair generation and implement authenticated server peer provisioning/reconciliation.
2. Deploy one real exit node and a remotely reachable API on always-on infrastructure; validate a single region end-to-end before adding a second.
3. Fix the VPN data path and prove handshake, DNS, internet traffic, and matching exit IP on the physical Android device.
4. Provision London and San Francisco as independent, verifiable exit nodes.
5. Complete authentication test coverage and safe Prisma baseline/adoption strategy.
6. Correct tunnel-state reporting and biometric policy.
7. Profile battery consumption and UI glitching.
8. Audit control-plane authorization, secrets, persistence, and remote command delivery.
9. Run the release playbook and record physical-device evidence.

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
