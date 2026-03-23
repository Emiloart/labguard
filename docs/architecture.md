# LabGuard System Architecture

## Product Positioning

LabGuard is a private infrastructure security product, not a mass-market VPN. The system is optimized for one owner account, a very small invited user base, per-device trust, explicit recovery operations, and auditable remote security control.

Brand attribution: Built by Emilo Labs

## Final Stack

### Mobile

- Flutter for the application shell, shared feature modules, and future iOS portability
- Kotlin for Android-specific integrations:
  - `VpnService`
  - WireGuard backend bridge
  - foreground service lifecycle
  - background-safe command execution hooks
- Riverpod for explicit dependency injection and testable state management
- `go_router` for structured navigation and auth-aware route redirection
- Dio for API transport, token injection, retry policies, and telemetry-safe logging
- `flutter_secure_storage` for tokens, VPN profile secrets, and app-lock material
- `local_auth` for biometric unlock

Why this stack:

- Flutter gives Android-first velocity while preserving a clean path to iOS.
- Riverpod avoids implicit global state and scales well across security-sensitive modules.
- A Kotlin bridge keeps the VPN implementation isolated from the Flutter UI layer.

### Backend

- Node.js + TypeScript
- Fastify for a smaller, faster, highly controllable control plane
- Zod for environment validation and request schema definition
- Prisma for relational schema modeling and migrations against PostgreSQL
- Pino-backed Fastify logging

Why Fastify instead of a heavier framework:

- The product is operationally serious but still small-scope.
- Fastify gives strict modularity without NestJS ceremony.
- Security-sensitive request handling stays explicit: plugins, hooks, auth guards, audit insertion, and domain modules remain easy to trace.

### Data / Infra

- PostgreSQL as the system of record
- One primary VPN server now, modeled as a registry for future multi-region expansion
- FCM-ready notification architecture for Android security and command updates
- Docker Compose development baseline for local PostgreSQL

## High-Level Architecture

```text
Flutter App
  ├─ Auth / Session Layer
  ├─ Dashboard / Devices / Events / Settings
  ├─ VPN Control UI
  ├─ Lost Device UX
  └─ Native Bridge (Kotlin)
       ├─ WireGuard tunnel lifecycle
       ├─ Android VpnService
       ├─ foreground notifications
       └─ background-safe command hooks

Fastify API
  ├─ Auth & Invitation Domain
  ├─ Device Registry Domain
  ├─ VPN Provisioning Domain
  ├─ Remote Actions Domain
  ├─ Security Events Domain
  ├─ Admin Domain
  └─ Audit / Observability Layer

PostgreSQL
  ├─ users / invitations / sessions
  ├─ devices / device_sessions / locations
  ├─ vpn_servers / vpn_profiles
  ├─ remote_commands / results
  ├─ security_events
  └─ audit_logs / preferences
```

## Main Domain Modules

1. App Shell / Branding
   Responsible for theme, navigation shell, launch experience, and Emilo Labs identity.
2. Authentication & Account Access
   Invitation acceptance, login, token lifecycle, device approval, app lock entry points.
3. VPN Connection Core
   Server selection, WireGuard profile delivery, tunnel status, reconnect policy, kill switch, DNS.
4. Device Registry
   Device inventory, trust state, metadata, approval, revoke, suspend, and rotation workflows.
5. Lost Device / Find My Device
   Explicit lost-mode state, last known location, elevated location cadence while lost, and recovery UX.
6. Remote Security Actions
   Signed-out, revoke VPN, rotate token/config, wipe app data, alarm, recovery message, disable access.
7. Settings & Security Controls
   Biometrics, PIN, auto-connect, kill switch, privacy controls, permissions, notification preferences.
8. Admin / Control Plane
   User invitations, device oversight, server assignment, event review, audit visibility.
9. Notifications
   Device events, unexpected disconnects, command status, trust changes, lost mode updates.
10. Logging / Observability / Audit
    Structured logs, event streams, command outcomes, security trail, and failure diagnostics.

## Repository Layout

```text
labguard/
├── apps/
│   └── mobile/
│       ├── android/
│       ├── lib/
│       │   └── src/
│       │       ├── app/
│       │       ├── core/
│       │       ├── features/
│       │       │   ├── auth/
│       │       │   ├── dashboard/
│       │       │   ├── devices/
│       │       │   ├── events/
│       │       │   ├── find_device/
│       │       │   ├── onboarding/
│       │       │   ├── settings/
│       │       │   ├── splash/
│       │       │   └── vpn/
│       │       └── mock/
│       └── test/
├── docs/
│   ├── api-design.md
│   ├── architecture.md
│   ├── build-plan.md
│   ├── data-model.md
│   └── security-checklist.md
├── infra/
│   └── docker/
│       └── docker-compose.dev.yml
├── packages/
│   └── labguard_contracts/
│       ├── README.md
│       └── openapi/
│           └── labguard.openapi.yaml
└── services/
    └── api/
        ├── prisma/
        │   └── schema.prisma
        └── src/
            ├── common/
            ├── config/
            └── modules/
```

## Android VPN Integration Plan

The Flutter layer must not implement the tunnel itself. The plan is:

1. Keep the VPN control UI, profile state, and policy configuration in Flutter.
2. Expose a narrow Kotlin bridge for:
   - tunnel start
   - tunnel stop
   - status polling/subscription
   - profile install / rotate / revoke
   - command-safe background wakeups
3. Implement the actual Android tunnel lifecycle with:
   - `VpnService`
   - a dedicated foreground service notification
   - WireGuard Android-compatible backend
   - network callback handling for reconnect behavior
4. Store private keys and session secrets only in secure local storage plus Android keystore-backed mechanisms where appropriate.
5. Keep all telemetry explicit and minimized. Lost-mode location escalation is opt-in and auditable.

## State Management Setup

- One provider layer per domain
- Repository interfaces isolate API/storage dependencies from UI
- Controllers own transient UI behavior and policy toggles
- Secure material never lives in plain logs or serializable debug dumps
- Future native VPN status streams can be bridged into Riverpod providers without leaking Android details across the app
