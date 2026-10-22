# LabGuard System Architecture

## Product Positioning

LabGuard is a private infrastructure security product from Emilo Labs for an owner and a small invited user base. It combines a WireGuard-based VPN client with trusted-device management and explicit lost-device recovery. It is not a mass-market VPN at this stage.

**Brand attribution:** Built by Emilo Labs.

## Technology Stack

### Mobile

- Flutter + Dart for UI and shared application features.
- Kotlin for Android-specific integrations: `VpnService`, WireGuard backend bridge, foreground service lifecycle, and background execution hooks.
- Java may appear where required by Android libraries or compatibility code; Kotlin is the primary native integration language.
- Riverpod for state management and dependency injection.
- `go_router` for navigation.
- Dio for API transport.
- `flutter_secure_storage` and platform-backed mechanisms for sensitive local material.
- `local_auth` for biometric prompts governed by explicit action-level policy.

### Backend

- Node.js + TypeScript.
- Fastify for the API/control plane.
- Zod for environment validation and request schemas.
- Prisma for relational schema management and PostgreSQL access.
- Pino-backed structured logging, with secret redaction.

### Data and infrastructure

- PostgreSQL is the intended persistent system of record.
- WireGuard is the tunnel protocol/engine; LabGuard must not invent custom cryptography or a custom VPN protocol.
- London and San Francisco are the target exit regions. They are not operational until independently deployed and validated.
- Docker Compose provides local development infrastructure only; local PostgreSQL is not production persistence.
- The developer laptop is used for development and administration, never as a required runtime VPN endpoint.

## High-Level Architecture

```text
Android device
  Flutter/Dart UI
    ├─ Authentication and account
    ├─ VPN and region selection
    ├─ Device registry / lost-device UX
    ├─ Security events and settings
    └─ narrow platform bridge
         Kotlin / Android VpnService
           WireGuard tunnel backend
                 |
                 | encrypted tunnel
                 v
        Deployed WireGuard exit node
          London OR San Francisco
                 |
                 v
              Internet

Flutter client
    | HTTPS API
    v
Deployed Fastify API
    |
    v
PostgreSQL
```

## Trust and Runtime Boundaries

- **Client UI is not proof of tunnel health.** The app must distinguish requested, starting, handshaking, connected/verified, disconnected, and failed states according to signals available from the VPN backend.
- **VPN traffic does not pass through the API.** The control plane authenticates users/devices and provisions profiles; the deployed WireGuard node carries tunneled traffic.
- **Region selection must be real.** London and San Francisco need independent deployed endpoints and server-specific WireGuard profiles. A display label or environment variable alone does not make a region ready.
- **Secrets stay on the right side of the boundary.** Server private keys stay on the server. Client private keys must not be exposed in logs or sent to unrelated API clients. The client receives only the server public key and its own authorized client configuration.
- **Development is not production.** Seed/bootstrap behavior and local endpoints must not be enabled as production authentication or provisioning paths.
- **Device location is explicit.** Location collection is permissioned and tied to the documented lost-device policy, with limited retention and access.

## Domain Modules

1. App Shell / Branding: theme, navigation, launch experience, and Emilo Labs identity.
2. Authentication & Account Access: invitations, sessions, device approval, and action-level app lock policy.
3. VPN Connection Core: region selection, profile retrieval, tunnel lifecycle, DNS/routing configuration, and verified status.
4. Device Registry: device inventory, trust state, approval, revoke, suspend, and rotation.
5. Lost Device / Find My Device: explicit lost mode, last-known location, permitted update cadence, and recovery.
6. Remote Security Actions: authenticated commands, delivery status, execution result, and audit trail.
7. Settings & Security Controls: biometrics, PIN, auto-connect, system kill-switch guidance, permissions, and notifications.
8. Control Plane: account, device, server readiness, profile issuance, events, and audit.
9. Observability: redacted structured logs, health/readiness signals, and operational diagnostics.

## Server Readiness Model

A region should be offered only when all required endpoint values are valid and the deployment's health checks pass. At minimum, readiness must validate:

- endpoint host and port;
- server public key format;
- confirmed expected public exit IP;
- region-specific DNS policy;
- server health and WireGuard service state;
- profile generation using the selected region;
- successful tunnel handshake and matching observed exit IP during release validation.

Missing configuration must produce an unavailable/not-configured state. It must never silently route the user to a different region or report a mock region as ready.

## Current Implementation and Known Gaps

Real-device testing has identified UI glitching, loss of internet traffic after VPN activation, overly frequent biometric prompts, and excessive battery consumption. The real London and San Francisco server values and deployment access are not present in the workspace. These are active remediation items, not resolved architecture details.

The control plane includes development/bootstrap behavior and must be reviewed for persistent production operation before release. Consult [field-test findings](field-test-findings.md) and [release playbook](release-playbook.md).
