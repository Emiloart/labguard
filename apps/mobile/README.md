# LabGuard Mobile

Android-first Flutter application for LabGuard.

Brand attribution: Built by Emilo Labs

## Foundation in This Phase

- premium dark-first application shell
- Riverpod-based domain state scaffolding
- `go_router` navigation with auth-aware redirects
- Dio API client setup
- secure storage abstraction
- Android method-channel placeholder for future VPN integration

## Run

```bash
flutter pub get
flutter run
```

Optional compile-time configuration:

```bash
flutter run --dart-define=LABGUARD_ENV=development --dart-define=LABGUARD_API_BASE_URL=http://10.0.2.2:8080
```
