# LabGuard Build Plan

This plan distinguishes implementation milestones from evidence that a feature works on a real device and deployed infrastructure. A phase marked implemented or polished is not automatically release-ready.

## Phase 1: Foundation

- Establish monorepo structure.
- Bootstrap Flutter mobile app shell.
- Define theme, route skeleton, and auth flow scaffold.
- Bootstrap Fastify backend with modular route domains.
- Create PostgreSQL schema baseline.
- Introduce environment configuration and local infrastructure.
- Prepare CI-friendly repository hygiene.

## Phase 2: Core App Shell

- Native/Flutter splash alignment.
- Onboarding flow.
- Login and invite acceptance.
- Dashboard, settings, and device list UX.
- Verify authentication behavior against the actual persistence layer.

## Phase 3: VPN Core

- Kotlin bridge contract.
- Android `VpnService` and foreground service implementation.
- WireGuard profile installation and secure storage.
- Connect, disconnect, and reconnect flows.
- Tunnel status and heartbeat sync.
- Verify real internet routing, DNS, IPv4/IPv6 behavior, and server forwarding. A UI state or Android VPN indicator alone does not prove usable connectivity.

## Phase 4: Device Security

- Device registration and approval.
- Device metadata sync.
- Device detail timelines.
- Security events feed.
- Remote actions with authenticated authorization and observable results.

## Phase 5: Lost Device

- Lost-mode state transitions.
- Explicit location permission and capture pipeline.
- Last-known versus elevated lost-mode updates.
- Map presentation and recovery controls.
- Validate Android background restrictions and battery impact on real hardware.

## Phase 6: Hardening

- Audit insertion for sensitive actions.
- Token rotation and VPN config rotation.
- Revocation and suspension enforcement.
- Failure-mode handling and retry policies.
- Background reliability and process-death recovery.
- Critical flow tests.

## Phase 7: Polish

- Motion refinement and visual consistency.
- Copy review.
- Branding and About pass.
- Accessibility sweep.
- Release playbook documentation.

## Phase 8: Field Validation and Operational Readiness

This phase is now the active priority. It resolves real-device findings and replaces assumptions with test evidence.

1. **VPN data path:** identify why the tunnel activates without working internet; verify client profile, WireGuard handshake, allowed IPs/routes, DNS, server IP forwarding/NAT, firewall, MTU, and IPv4/IPv6 handling.
2. **Remote infrastructure:** deploy and secure actual London and San Francisco WireGuard exit nodes plus a remotely reachable API. The laptop is a development/admin workstation, not a runtime dependency.
3. **Region correctness:** expose London/San Francisco only when each region has complete valid configuration and passes server health/readiness checks. Confirm observed egress IP for each selection.
4. **Biometric policy:** centralize action-level policy. Prompt only for app unlock when enabled and explicitly configured sensitive operations such as connect/disconnect and remote security actions. Routine navigation must not prompt.
5. **Battery profiling:** measure steady-state VPN, idle/background, sync, reconnect, and lost-mode behavior. Remove aggressive polling, unnecessary location updates, noisy event streams, and retry loops.
6. **UI stability:** profile Flutter rebuilds and animations; inspect native-to-Flutter event frequency, lifecycle transitions, and state races.
7. **Backend correctness:** audit seeded/bootstrap paths, mock data, persistence, token handling, authorization, audit records, and server/profile provisioning before any production distribution.
8. **Release verification:** run automated checks, install a release-like build on physical Android hardware, and record pass/fail evidence for every release gate.

## Milestone Order

1. Foundation and runnable local services.
2. Authentication and dashboard.
3. Android VPN integration.
4. Device security.
5. Lost-device workflow.
6. Hardening.
7. Visual/accessibility polish.
8. Field validation and operational readiness.
9. Trusted-user release candidate only after all blockers pass.

## Definition of Done

A task is complete only when code, tests, documentation, and observable behavior agree. For VPN functionality, “connected” must represent a verified tunnel state, and a region must not be marked ready based solely on environment strings or UI metadata.
