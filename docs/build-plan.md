# LabGuard Build Plan

## Phase 1: Foundation

- Establish monorepo structure
- Bootstrap Flutter mobile app shell
- Define theme, route skeleton, and auth flow scaffold
- Bootstrap Fastify backend with modular route domains
- Create PostgreSQL schema baseline
- Introduce environment configuration and local infrastructure
- Prepare CI-friendly repo hygiene

## Phase 2: Core App Shell

- Native/Flutter splash alignment
- Onboarding flow
- Login and invite acceptance scaffolds
- Dashboard, settings, and device list UX
- Basic backend-backed authentication wiring

## Phase 3: VPN Core

- Kotlin bridge contract
- Android `VpnService` and foreground service implementation
- WireGuard profile install and secure storage
- Connect / disconnect / reconnect flows
- Tunnel status and heartbeat sync

## Phase 4: Device Security

- Device registration and approval
- Device metadata sync
- Device detail timelines
- Security events feed
- Remote actions scaffolding end-to-end

## Phase 5: Lost Device

- Lost mode state transitions
- Explicit location permission and capture pipeline
- Last-known vs elevated lost-mode updates
- Map presentation and recovery controls

## Phase 6: Hardening

- Audit log insertion everywhere sensitive
- Token rotation and VPN config rotation
- Revocation and suspension enforcement
- Failure-mode handling and retry policies
- Background reliability and process death recovery
- Critical flow tests

## Phase 7: Polish

- Motion refinement and visual consistency
- Copy review
- Branding and About pass
- Accessibility sweep
- Release readiness and playbook documentation

## Milestone Order

1. Foundation merge with docs, schema, and runnable shells
2. Auth and dashboard milestone
3. Android VPN alpha milestone
4. Device security milestone
5. Lost-device milestone
6. Hardening milestone
7. Release candidate
