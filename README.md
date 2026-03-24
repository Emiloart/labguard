# LabGuard

LabGuard is a private Android-first security suite for Emilo Labs. The system combines a WireGuard-based VPN client, trusted-device management, explicit lost-device recovery flows, remote security actions, and a tightly controlled backend/control plane designed for a small high-trust user base.

Brand attribution: Built by Emilo Labs

## Architecture Summary

- `apps/mobile`: Flutter application prepared for Android-first delivery and future iOS support.
- `services/api`: TypeScript Fastify control plane for auth, device lifecycle, VPN provisioning, remote actions, and auditability.
- `packages/labguard_contracts`: shared API contract and OpenAPI placeholder package.
- `docs`: architecture, API, data model, milestones, and security hardening guidance.
- `infra`: local infrastructure support, starting with development PostgreSQL.

## Repository Structure

```text
labguard/
├── apps/
│   └── mobile/
├── docs/
├── infra/
│   └── docker/
├── packages/
│   └── labguard_contracts/
└── services/
    └── api/
```

## Stack Decisions

- Mobile UI: Flutter with Riverpod, go_router, Dio, secure local storage, and native Android integration points for VPN service work.
- Backend: Fastify + TypeScript for a lean but structured control plane with modular route registration and strong request lifecycle control.
- Data layer: PostgreSQL with Prisma schema management for clear relational modeling and migrations.
- VPN: WireGuard as the tunnel foundation, with Android `VpnService` integration isolated behind a Kotlin bridge.

## Current Status

- Phases 1 through 7 are scaffolded across the Flutter app, Android runtime layer, and Fastify control plane.
- The mobile app now covers branding, onboarding, auth restore, VPN control, device registry, lost-device workflows, remote security actions, audit visibility, Android runtime posture checks, and background hardening.
- The Android layer includes WireGuard integration, foreground runtime service handling, WorkManager-based background sync, boot recovery, and explicit permission/system-settings handoff.
- The backend exposes modular auth, devices, VPN, preferences, remote actions, security events, and audit endpoints against a mock control-plane dataset.
- Release polish now includes global motion tuning, accessibility-oriented screen headers, a stronger About surface, and release playbook documentation.

## Release Readiness

- Release playbook: [docs/release-playbook.md](docs/release-playbook.md)
- Current limitation: `services/api/src/common/mock/control-plane-data.ts` is still a development mock. Replace it with persistent production services before any production rollout.

## Next Commands

Backend:

```bash
pnpm install --dir services/api
pnpm --dir services/api dev
```

Mobile:

```bash
flutter pub get
flutter run
```

The Flutter toolchain in this environment did not complete dependency resolution during scaffolding, so mobile dependency installation still needs to be run locally before execution.
