# LabGuard Release Playbook

## Scope

LabGuard is an internal, Android-first private security suite for Emilo Labs and a small invited user base. Do not treat the current repository as a public consumer rollout candidate.

The project has completed a Phase 7 polish pass, but physical-device testing has identified functional and operational blockers. Visual polish is not release readiness. Track remediation in [field-test findings](field-test-findings.md) and use [Phase 7 polish notes](phase-7-polish.md) for UI/accessibility conventions.

## Release Gates

Every gate below must pass before a production-tagged build is distributed.

### Infrastructure and VPN correctness

- [ ] Replace development/bootstrap control-plane behavior with reviewed persistent production services for authentication, device state, VPN provisioning, remote command status, and audit storage.
- [ ] Keep refresh tokens hashed at rest and encrypt VPN private material in the production control plane.
- [ ] Provision actual WireGuard exit nodes in **London, United Kingdom** and **San Francisco, United States**.
- [ ] Configure `VPN_SERVER_LONDON_ENDPOINT`, `VPN_SERVER_LONDON_PUBLIC_KEY`, `VPN_SERVER_LONDON_EXIT_IP` and their `VPN_SERVER_SF_*` equivalents using verified infrastructure values.
- [ ] Never commit actual secrets, private keys, access tokens, or server credentials. Server private keys must remain on their respective hosts.
- [ ] Confirm the API and both VPN endpoints are remotely reachable and continue working with the operator laptop powered off.
- [ ] Confirm each region has a real independent endpoint and server-specific profile; no mock labels, silent fallback, or Casablanca placeholder route.
- [ ] Confirm real WireGuard handshake, DNS resolution, internet traffic, IPv4/IPv6 behavior, forwarding/NAT, firewall, and MTU behavior.
- [ ] Verify observed public egress IP matches the selected region's confirmed exit IP.
- [ ] Only expose a region as ready when its configuration is valid and its health/readiness checks pass.

### Mobile behavior

- [ ] Fix UI glitching and state-transition races on a physical Android device.
- [ ] Fix the failure where enabling the VPN leaves internet traffic unavailable.
- [ ] Do not report `Connected` until the tunnel is established and its operational state is verified.
- [ ] Apply biometric prompts only to app unlock when enabled and explicitly configured sensitive operations. Routine navigation must not trigger biometrics.
- [ ] Profile and reduce battery use from polling, reconnect loops, location updates, background sync, and unnecessary UI/native-channel events.
- [ ] Confirm VPN foreground notification and Android system VPN settings behavior.
- [ ] Validate process death, reboot, Wi-Fi/mobile-data transitions, airplane mode, and manual disconnect behavior.
- [ ] Confirm location collection is explicit, visible, and limited to the intended lost-device policy.

### Build and release hygiene

- [ ] Sign the Android app with the production keystore and verify package identity `com.emilolabs.labguard`.
- [ ] Confirm production configuration contains no emulator, localhost, or laptop-only endpoints.
- [ ] Review privacy/location retention, permissions, remote action authorization, and audit behavior.
- [ ] Run automated checks and preserve their output in the release record.

## Required Verification

Run from the repository root (adjust toolchain paths to the machine executing the build):

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter test

cd ..\..\services\api
pnpm install
pnpm typecheck
pnpm build
pnpm exec prisma generate --schema prisma/schema.prisma
pnpm exec prisma validate --schema prisma/schema.prisma

cd ..\..\apps\mobile\android
.\gradlew.bat :app:compileDebugKotlin
```

Run API tests and migration checks against a disposable test database configured through environment variables. Do not paste production secrets into command history or logs.

## Manual Validation Matrix

Use at least one physical Android device. Include a second OEM/device model when available.

1. First launch, splash, onboarding, login/invitation, session restore, and secure logout.
2. Device approval, device list refresh, device detail history, and audit visibility.
3. VPN permission request, profile installation, connect/disconnect, and status accuracy.
4. London selection: inspect the active profile endpoint, establish a handshake, resolve DNS, load external sites, and verify observed public exit IP.
5. Repeat the same independent checks for San Francisco.
6. Confirm a missing or unhealthy region is unavailable and does not silently route through a different region.
7. Turn off the operator laptop and disconnect USB debugging; verify the deployed API and VPN remain usable.
8. Switch Wi-Fi to mobile data, toggle airplane mode, lock/unlock the phone, background/foreground the app, and test recovery after process death/reboot.
9. Test manual disconnect and confirm the app does not unexpectedly reconnect against the user's explicit choice.
10. Verify Android Always-on VPN and Block connections without VPN guidance opens the appropriate system settings where supported.
11. Lost mode: location permission handling, timestamp/accuracy, unavailable GPS/network states, recovery message, and recovered-state cleanup.
12. Remote actions: sign out, revoke VPN, rotate session/profile, wipe app-sensitive data, ring alarm, and disable access. Verify server authorization and audit outcomes.
13. Biometrics: app unlock only when enabled; connect/disconnect and sensitive actions according to policy; ordinary navigation without prompts.
14. Battery: compare 30-minute connected-idle, active-traffic, background, reconnect, and lost-mode behavior. Record baseline and observed measurements.
15. UI stability: navigate repeatedly, change VPN state, receive status events, and inspect for jank, duplicate animations, stuck loading, and incorrect state.
16. Accessibility: TalkBack, icon-only labels, status announcements, dialogs, and larger text sizes.
17. Empty/loading/error states: dashboard, devices, events, audit, and find-device flows must give actionable guidance without raw exceptions or clipped layouts.

## Release Steps

1. Freeze and review the release environment configuration.
2. Verify server deployment, key custody, health, region egress, firewall, forwarding, and DNS.
3. Run the full automated verification suite.
4. Run and record the manual validation matrix.
5. Build and sign the Android artifact.
6. Record artifact hash, version, environment, selected server targets, verification results, and approver.
7. Distribute only to approved trusted users.

## Rollback

If a release regresses VPN safety, device trust enforcement, or remote command handling:

1. Revoke affected device sessions and VPN profiles from the control plane.
2. Halt further distribution.
3. Restore the previous signed build or disable the affected region.
4. Record the incident in audit and operations logs.
5. Re-run the relevant validation matrix before reissuing a fixed build.

## Current Repository Status

The repository contains region configuration fields and readiness logic, but **real London and San Francisco infrastructure values have not been supplied in this workspace**. No real server deployment, endpoint, public key, or exit IP should be assumed. The repo also retains development/bootstrap behavior that needs a production review.

Until the above gates pass, LabGuard remains an internal engineering/field-test build. Do not describe it as production-ready or advertise unprovisioned regions as available.
