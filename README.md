# LabGuard

LabGuard is a private Android-first security suite from Emilo Labs. It combines a WireGuard-based VPN client, trusted-device management, explicit lost-device recovery flows, remote security actions, and a controlled backend for a small invited user base.

**Brand attribution:** Built by Emilo Labs.

## Architecture

- `apps/mobile`: Flutter application, Android-first, with future iOS portability as a design goal.
- `services/api`: Fastify + TypeScript control plane for authentication, device lifecycle, VPN region readiness/provisioning, remote actions, and auditability.
- `packages/labguard_contracts`: shared API contracts and OpenAPI definitions.
- `infra`: local development infrastructure, including PostgreSQL.
- `docs`: architecture, API/data model, security guidance, release gates, and field-test findings.

## Stack

- **Mobile UI:** Flutter + Dart, Riverpod, go_router, Dio, secure storage.
- **Android system integration:** Kotlin (and Java only where required by Android dependencies), including `VpnService` and the WireGuard integration boundary.
- **Backend:** Node.js + TypeScript + Fastify.
- **Persistence:** PostgreSQL + Prisma.
- **VPN protocol/engine:** WireGuard. LabGuard does not implement custom cryptography or a custom tunnel protocol.

## Current Status

LabGuard has a substantial application and API foundation, and Phase 7 polish work is documented. **Phase completion and UI polish do not establish operational or production readiness.** Real-device testing has identified release-blocking issues:

- UI glitching during use.
- VPN can appear enabled while internet traffic does not work.
- Biometric prompts are too broad; they should gate configured sensitive actions rather than routine navigation.
- VPN service availability must not depend on the developer laptop or a local development process.
- Battery consumption is excessive and needs measurement and profiling.
- Real exit-node switching is required for **UK — London** and **US — San Francisco**. Those regions are not ready until real server infrastructure is deployed and validated.

The API configuration currently defines region variables, but the repository does not contain the real endpoint, server public key, or confirmed exit IP values. No values should be fabricated. The control plane also retains development/bootstrap behavior that must be reviewed and replaced or explicitly hardened before production use.

See:
- [Field-test findings and remediation plan](docs/field-test-findings.md)
- [System architecture](docs/architecture.md)
- [Build plan](docs/build-plan.md)
- [Security checklist](docs/security-checklist.md)
- [Release playbook](docs/release-playbook.md)
- [Phase 7 polish notes](docs/phase-7-polish.md)

## Repository Layout

```text
labguard/
├── apps/mobile/
├── docs/
├── infra/docker/
├── packages/labguard_contracts/
└── services/api/
```

## Local Development

Backend:

```bash
pnpm install --dir services/api
pnpm --dir services/api dev
```

Mobile:

```bash
cd apps/mobile
flutter pub get
flutter run
```

Use local development endpoints only for local testing. A release build must use remotely reachable, deployed API and VPN infrastructure and must continue working when the developer laptop is offline.

## Release Position

Treat current builds as **internal engineering / field-test builds**, not production-ready releases, until the release gates in `docs/release-playbook.md` pass. In particular, do not advertise a region as available unless its real endpoint is configured, its server is healthy, the tunnel handshake succeeds, and observed egress matches the region.
