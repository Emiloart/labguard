# LabGuard Release Playbook

## Scope

LabGuard is an internal, Android-first private security suite for Emilo Labs. Releases are for a small trusted user base only. Do not treat the current repository as a public consumer rollout candidate.

Reference the UI polish and accessibility conventions in `docs/phase-7-polish.md` during final release review.

## Release Gates

The following conditions must be true before a production-tagged build is distributed:

- Replace the remaining seeded development control-plane behavior with persistent production services for auth, device state, VPN provisioning, remote command status, and audit storage.
- Keep refresh tokens hashed at rest and encrypt VPN private material in the production control plane.
- Provision every advertised WireGuard region with real endpoint metadata, exit-IP verification, and documented rotation and revocation procedures.
- Configure `VPN_SERVER_LONDON_*` and `VPN_SERVER_SF_*` with deployed remote infrastructure before enabling region switching in release builds.
- Remove emulator-only or laptop-only API/VPN endpoints from the release environment. A release candidate must function when the operator laptop is offline.
- Sign the Android app with the production keystore and verify package identity `com.emilolabs.labguard`.
- Confirm Android notification, location, and battery-optimization flows on current target devices.
- Validate the Always-on VPN and Block connections without VPN system path on supported Android builds.

## Required Verification

Run these checks before every release candidate:

```powershell
cd apps/mobile
flutter analyze
flutter test

cd ..\..\services\api
pnpm typecheck
pnpm build
pnpm exec prisma generate --schema prisma/schema.prisma
$env:DATABASE_URL='postgresql://labguard:labguard@localhost:5432/labguard'
pnpm exec prisma validate --schema prisma/schema.prisma

cd ..\..\apps\mobile\android
$env:JAVA_HOME='C:\Program Files\Android\Android Studio1\jbr'
.\gradlew.bat :app:compileDebugKotlin
```

## Manual Validation Matrix

Validate these flows on at least one clean Android device and one previously approved device:

1. First launch, splash, onboarding, login, session restore, and secure logout.
2. Device approval, device list refresh, device detail history, and audit trail visibility.
3. VPN permission request, profile install, connect, disconnect, reconnect after process death, and boot restore.
4. Region switching: select London, confirm the issued profile endpoint and observed exit IP are London-specific, then repeat for San Francisco.
5. Tunnel truth: the app must not show `Connected` until a real handshake is recorded and the observed exit IP matches the selected region.
6. Deployment independence: with USB disconnected and the operator laptop offline, confirm the VPN can still connect through the deployed server set.
7. Manual disconnect behavior: the tunnel must stay down until the operator reconnects or explicitly re-enables keep-connected intent.
8. Kill-switch guidance: Android VPN settings must open correctly and the operator must be able to enable Always-on VPN and block-without-VPN from system settings.
9. Lost-mode enablement, location permission handling, last-known location rendering, recovery message delivery, and recovered flow cleanup.
10. Remote actions: sign out, revoke VPN, rotate session, wipe local data, ring alarm, and disable device access.
11. Background runtime recovery: WorkManager sync, session refresh, remote command execution, and notification surfacing while the app is backgrounded.
12. Empty, loading, and error states: dashboard, devices, events, audit, and find-device flows must all explain next steps without raw exception text or clipped layouts.
13. Accessibility review: confirm TalkBack reads screen titles, icon-only controls, state chips, loading panels, and confirmation dialogs clearly.
14. Text scale review: check common screens at larger font settings to confirm no critical action is clipped or pushed off-screen.
15. Motion review: confirm shell navigation, splash entry, lock overlay, and action feedback feel stable and restrained without abrupt jumps.
16. Battery review: confirm steady-state drain after 30 minutes with the app open, backgrounded, and in lost mode; normal mode must stay lower-noise than lost mode.

## Release Steps

1. Freeze environment configuration for the target API and each release region endpoint.
2. Run the full automated verification suite.
3. Run the manual validation matrix on release devices.
4. Build the signed Android artifact.
5. Record artifact hash, version, environment, server target, and operator approver in the release log.
6. Distribute only to approved trusted users.

## Rollback

If a release regresses VPN safety, device trust enforcement, or remote command handling:

1. Revoke affected device sessions and VPN profiles from the control plane.
2. Halt further distribution of the current artifact.
3. Restore the previous signed build.
4. Record the incident in audit and operations logs.
5. Re-run the full validation matrix before reissuing a fixed build.

## Current Repository Note

The UI, Android runtime, and control-plane contracts are shaped for production use, but the repository still contains seeded development behavior for account bootstrap and environment-gated VPN provisioning. Treat current builds as internal engineering or operator preview builds until persistent production services fully replace the remaining development scaffolding. Region switching is gated by real endpoint metadata, but persistent provisioning and audit storage still remain a production blocker.
