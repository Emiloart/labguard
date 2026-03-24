# LabGuard Release Playbook

## Scope

LabGuard is an internal, Android-first private security suite for Emilo Labs. Releases are for a small trusted user base only. Do not treat the current repository as a public consumer rollout candidate.

## Release Gates

The following conditions must be true before a production-tagged build is distributed:

- Replace `services/api/src/common/mock/control-plane-data.ts` with persistent production services for auth, device state, VPN provisioning, remote command status, and audit storage.
- Keep refresh tokens hashed at rest and encrypt VPN private material in the production control plane.
- Provision at least one production WireGuard server with documented rotation and revocation procedures.
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
4. Manual disconnect behavior: the tunnel must stay down until the operator reconnects or explicitly re-enables keep-connected intent.
5. Kill-switch guidance: Android VPN settings must open correctly and the operator must be able to enable Always-on VPN and block-without-VPN from system settings.
6. Lost-mode enablement, location permission handling, last-known location rendering, recovery message delivery, and recovered flow cleanup.
7. Remote actions: sign out, revoke VPN, rotate session, wipe local data, ring alarm, and disable device access.
8. Background runtime recovery: WorkManager sync, session refresh, remote command execution, and notification surfacing while the app is backgrounded.

## Release Steps

1. Freeze environment configuration for the target API and VPN server set.
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

The UI, Android runtime, and control-plane contracts are shaped for production use, but the repository still contains mock backend state for development. Treat current builds as internal engineering or operator preview builds until the mock services are removed.
