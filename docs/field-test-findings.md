# LabGuard Field-Test Findings and Remediation

## Purpose

This document records issues observed while testing LabGuard on a physical Android phone. These findings override any assumption that a polished UI or completed scaffold phase is production-ready. Each issue remains open until the root cause is identified, a fix is tested, and evidence is recorded.

## Current Release-Blocking Findings

### F-01: UI glitching

**Observed:** UI transitions and/or rendering glitch during real-device use.

**Investigation targets:**
- Flutter rebuild frequency and overly broad provider invalidation.
- VPN status streams or platform-channel events emitting duplicate/noisy updates.
- Race conditions between API state, local state, and native tunnel state.
- Animations restarting on every status update.
- Lifecycle transitions when app backgrounds, resumes, or receives a service callback.

**Acceptance criteria:**
- Repeated navigation and connect/disconnect operations do not produce visible flicker, layout jumps, stuck loaders, or duplicate transitions.
- State changes are event-driven and scoped to affected widgets.
- Profiling is performed on a physical device and results are documented.

### F-02: VPN activates but internet access fails

**Observed:** Android shows the VPN as enabled, but internet traffic does not work.

**Treat this as the highest-priority functional defect. Do not mask it with UI changes.**

**Debug in order:**
1. Confirm the selected profile's endpoint and server public key match the deployed node.
2. Confirm the server is reachable from an external network and WireGuard is running.
3. Confirm a recent WireGuard handshake and inspect transfer counters.
4. Verify Android tunnel interface addresses, AllowedIPs/routes, DNS configuration, and MTU.
5. Verify server IP forwarding, NAT/masquerading, firewall forwarding rules, return routing, and outbound access.
6. Test DNS separately from direct-IP connectivity.
7. Test IPv4 and IPv6 independently; prevent IPv6 bypass or blackholing.
8. Verify app state is based on actual native tunnel signals and not merely a successful start request.

**Acceptance criteria:**
- After connecting, multiple external sites load and DNS resolves through the intended tunnel policy.
- Disconnect restores normal network behavior.
- Network changes and reconnects do not leave the device without traffic.
- The UI reports connected only when supported backend signals show the tunnel is operational. If end-to-end traffic verification is not available continuously, the UI must not imply that an end-to-end test was performed.

### F-03: Biometric prompts are too broad

**Observed:** Biometrics are requested during flows that should not require them.

**Required policy:**
- App-open authentication only when the user has enabled app lock and the lock policy requires it.
- Gate configured sensitive actions, including VPN connect/disconnect and high-impact remote security actions, according to the product's explicit policy.
- Do not prompt during routine navigation, harmless settings inspection, or ordinary dashboard rendering.
- Keep policy centralized so individual screens cannot invent inconsistent prompts.
- Handle unavailable biometrics, cancellation, lockout, and fallback policy clearly.

**Acceptance criteria:** A documented test matrix covers app lock on/off, connect/disconnect, remote actions, normal navigation, cancellation, and device biometric unavailability.

### F-04: VPN must not depend on the developer laptop

**Requirement:** The VPN service and API must remain available when the developer laptop is shut down, asleep, disconnected, or away from the user's network.

**Required architecture:**
- Deploy WireGuard exit nodes on always-on remote infrastructure.
- Deploy the API and persistent database independently of the laptop.
- Configure production mobile builds with remotely reachable HTTPS API and WireGuard endpoints.
- Keep local/emulator endpoints limited to development builds.
- Document server operations, updates, key rotation, monitoring, backups, and recovery.

**Acceptance criteria:** With the laptop powered off and USB debugging disconnected, an authorized phone can authenticate, retrieve its valid profile, connect, and pass traffic through the deployed server.

### F-05: Battery consumption is excessive

**Observed:** Battery consumption is too high during testing.

**Measure before optimizing.** Record Android battery usage and app/network activity for comparable time windows.

**Investigation targets:**
- Aggressive API polling or frequent heartbeats.
- WorkManager jobs scheduled too frequently or duplicated.
- Tight reconnect loops on unavailable networks.
- High-frequency location updates outside explicit lost mode.
- Repeated native-to-Flutter events and unnecessary rendering.
- Excessive wake locks, foreground service work, or repeated network requests.
- Logging or telemetry that remains active in release builds.

**Acceptance criteria:**
- Compare 30-minute connected-idle, active-traffic, background, reconnect, and lost-mode scenarios.
- Normal mode performs no continuous location tracking.
- Retries use bounded exponential backoff with jitter where appropriate.
- No redundant periodic work exists when an event-driven mechanism is available.
- Document baseline and post-fix measurements; do not claim battery efficiency without data.

### F-06: London and San Francisco regions are not provisioned

**Observed:** The repository has environment variable names for London and San Francisco, but the real values and infrastructure access are not available in the current workspace.

Required variables:

- `VPN_SERVER_LONDON_ENDPOINT`
- `VPN_SERVER_LONDON_PUBLIC_KEY`
- `VPN_SERVER_LONDON_EXIT_IP`
- `VPN_SERVER_SF_ENDPOINT`
- `VPN_SERVER_SF_PUBLIC_KEY`
- `VPN_SERVER_SF_EXIT_IP`

DNS variables are also defined in the example environment file.

**Do not invent endpoints, keys, exit IPs, SSH targets, cloud credentials, or claims of deployment.** Obtain the values from actual deployed servers. Server private keys must never be copied into client configuration, committed to the repository, or sent to the mobile app.

**Acceptance criteria per region:**
- Independent WireGuard node deployed in the intended location.
- API and server configuration agree on endpoint, public key, and expected exit IP.
- Region-specific profile is issued when selected.
- Real handshake succeeds and internet traffic works.
- External IP check confirms the expected egress IP.
- Unconfigured or unhealthy regions are disabled in the selector; no silent fallback to another region.
- The app reports actual selected/active region, not stale metadata.

## Cross-Cutting Backend Review

The API currently contains a control-plane service with seed/bootstrap behavior. Prisma usage alone does not prove that all production workflows are safe or fully persistent. Review:

- default owner/invitation bootstrap behavior and whether it can run in production;
- any default invite codes or seeded/demo device identities;
- actual database persistence and migration lifecycle;
- refresh token hashing/rotation and session revocation;
- VPN private-material encryption and key custody;
- account-scoped authorization on every device/server/command operation;
- remote command delivery, expiry, replay/idempotency, and result reporting;
- audit record completeness and secret redaction;
- server readiness checks versus merely checking whether environment variables are non-empty.

Remove unsafe development defaults or make them impossible to activate in production through validated configuration and tests.

## Recommended Execution Order

1. Fix the VPN data path and prove working internet traffic on one known-good deployed node.
2. Deploy/configure the real API and VPN infrastructure independently of the laptop.
3. Bring up London and San Francisco as independent, verifiable exit nodes.
4. Correct the app's tunnel state model and biometric policy.
5. Profile battery consumption and UI glitching.
6. Audit control-plane production behavior, secrets, authorization, and persistence.
7. Run the full release playbook and record results.

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
