# CompleteBytePOS Mobile (Flutter)

Android-first native client for CompleteBytePOS. Sprint docs live in  
[`../CompleteBytePOS/docs/mobile/`](../CompleteBytePOS/docs/mobile/).

## Prerequisites

- Flutter 3.24+ (`flutter doctor`)
- Android emulator or device

## Run

```bash
cd mobile
flutter pub get
flutter run
# Debug APK (default APP_ENV=dev → https://api.uat.omuwenga.com/api)
flutter build apk --debug
# Optional local backend override:
# flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
# Release against production:
# flutter build apk --release --dart-define=APP_ENV=prod
```

| Flavor (`APP_ENV`) | Default `API_BASE_URL` |
|--------------------|------------------------|
| `dev` / `staging` / `uat` | `https://api.uat.omuwenga.com/api` |
| `prod` | `https://shop.omuwenga.com/api` |

UAT API: [https://api.uat.omuwenga.com/](https://api.uat.omuwenga.com/)  
Shop host: [https://shop.omuwenga.com/](https://shop.omuwenga.com/)

## Test & coverage gate

```bash
flutter analyze
flutter test --coverage
# S01 foundation packages
dart run tools/check_coverage.dart --min=98 \
  --paths=lib/core,lib/design_system,lib/features,lib/app \
  --exclude=lib/main.dart
# S02 auth packages
dart run tools/check_coverage.dart --min=98 \
  --paths=lib/features/auth,lib/core/secure,lib/core/network,lib/app \
  --exclude=lib/main.dart,lib/core/secure/secure_token_store.dart
```

See [`../CompleteBytePOS/docs/mobile/COVERAGE_POLICY.md`](../CompleteBytePOS/docs/mobile/COVERAGE_POLICY.md).

## Architecture

```
lib/
  app/            # bootstrap, router, providers
  core/           # env, theme, network, Result, secure storage
  design_system/  # buttons, empty/error/loading
  features/       # health (S01), auth (S02), pos (S04)
  sync/           # Drift DB, outbox, sync chip (S03)
```

State: **Riverpod** · Nav: **GoRouter** · Auth: JWT · Offline: **Drift + outbox** · POS: search→cart→pay→receipt · Decisions: `DECISIONS.md`.
