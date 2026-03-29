# LabGuard Phase 7 Polish Notes

## Scope

This document tracks the release-oriented polish pass for LabGuard. It does not change the core product scope, architecture, or backend persistence model. The goal is to make the Android-first client feel cohesive, premium, quiet, and operationally reliable for serious internal use.

## Release Polish Summary

- Unified the mobile design surface around shared spacing, radius, motion, panel, and feedback tokens.
- Normalized loading, empty, and error states so screen transitions read as deliberate instead of scaffolded.
- Refined operator-facing copy to stay calm, precise, and security-aware.
- Separated routine recovery work from high-impact destructive actions on sensitive screens.
- Strengthened the About and build-identity surface with clearer internal-release wording.
- Added accessibility-oriented labels, clearer button language, and better screen-reader context for status and loading states.

## UX Consistency Conventions

### Layout

- Standard page padding: `24 / 18 / 24 / 120`.
- Standard wide onboarding/auth padding: `24 / 28 / 24 / 32`.
- Primary panel radius: `24`.
- Secondary tile radius: `20`.
- Status chip radius: pill.
- Use `PanelHeader` for section titles and supporting copy instead of ad hoc title/body pairs.

### Components

- `AppPanel` is the default elevated surface for operational content.
- `LoadingPanel`, `ErrorPanel`, and `EmptyPanel` are the standard user-facing state surfaces.
- `StatusBadge` must always include clear text, not color-only meaning.
- High-impact actions belong in their own section and must be confirmed with action-specific language.

### Motion

- Quick motion: `180ms`.
- Standard motion: `260ms`.
- Emphasized motion: `420ms`.
- Preferred curves: `easeOutCubic` for entry and surface changes.
- Avoid bounce, overshoot, or flashy transitions.
- Navigation and lock overlays should fade/slide subtly, not snap or scale dramatically.

### Copy

- Keep action labels short and explicit.
- Prefer operator language over implementation language.
- Avoid marketing phrases, excessive warnings, and generic “tap here” copy.
- Permission guidance must describe the security workflow it unlocks.

## Accessibility Checklist

- Major screen titles use a semantic header hierarchy through `ScreenIntro`.
- Icon-only buttons must expose tooltips or semantic labels.
- Loading panels announce live progress context.
- Empty and error states explain what happened and what the next safe action is.
- Status chips include readable labels and are not color-dependent.
- Primary actions retain large touch targets through themed button sizing.
- Dialogs use clear action labels instead of generic confirmations when the action is destructive.
- Destructive and non-destructive actions are visually separated on device control surfaces.

## Manual QA Checklist

### Entry and navigation

- Verify splash copy, brand lockup, and version/build metadata.
- Confirm onboarding panels read cleanly at default and larger text sizes.
- Confirm login remains readable with the keyboard visible and that errors surface as actionable feedback.
- Confirm bottom navigation transitions remain stable and do not jitter between top-level tabs.

### Core operational screens

- Dashboard: recovery banner, critical alert banner, VPN card, metric tiles, and quick actions all align cleanly on common Android phone widths.
- VPN: permission-missing, profile-missing, connected, disconnected, and runtime-guidance states all remain readable and correctly prioritized.
- Devices: empty state, multi-device list, lost device badges, and dense metadata chips remain readable without crowding.
- Device detail: routine recovery actions and high-impact actions are clearly separated and all confirmations match the action being executed.
- Find device: map unavailable, no location samples, fresh location success, lost-mode enabled, and recovered transitions all read clearly.
- Events and audit: empty states, unread/read state, and retry actions are obvious and screen-reader friendly.
- Settings and About: build metadata, posture review, PIN flow, and sign-out wording feel deliberate and complete.

### Edge cases

- Expired session handling returns the operator to a clear access flow without ambiguous state.
- Permission-denied location state explains why recovery cannot refresh location.
- Notification-disabled posture clearly explains missed alert risk.
- Battery optimization restrictions explain the impact on background recovery and command delivery.
- Remote command queue, failure, retry, and success states stay readable and consistent.

## Android Device Validation Checklist

- Validate on at least one current Pixel-class device and one OEM-skinned Android build.
- Check default text scale and enlarged text scale.
- Validate TalkBack announcements on splash, login, dashboard, device detail, and settings.
- Confirm the lock overlay, biometric unlock, and PIN unlock do not trap focus.
- Confirm Android VPN settings deep link opens correctly when the OS supports it.
- Confirm location and notification permission guidance stays accurate across Android versions that differ in runtime permission behavior.
- Confirm background recovery guidance still reads correctly when battery optimization remains enabled.

## Known Remaining Non-Phase-7 Blockers

- `services/api/src/common/mock/control-plane-data.ts` still exists and blocks a true production rollout.
- Production keystore signing, production WireGuard server provisioning, and environment hardening are still external release gates.
- The repository should still be treated as an internal trusted-user build until persistent production services replace the remaining mock data path.
