# Fleet Driver App

Sanitized Flutter source demonstration for driver sign-in, trip status, delivery checkpoints, receipt capture, background location and chat. Original API captures, credentials, endpoint and client branding are removed. Images are synthetic placeholders; sample trip locations are fictional coordinates near 0,0.

## Setup

Requires Flutter with Dart 3.11.1-compatible SDK and the platform toolchains.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The API defaults to `https://example.invalid/`, a reserved non-operational domain. There is no backend bundled in this repository. To connect to a backend you control, explicitly set the compile-time configuration:

```sh
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/
```

Use the appropriate host address for your emulator or physical device and configure its local HTTP policy if needed. API paths and DTOs describe the expected service contract, including the SignalR chat hub. TLS certificate validation uses the platform defaults. Supply only synthetic credentials and records.

The existing admin tools expose offline UI test toggles and synthetic trip responses. Those responses cover only selected flows; local mock receipt/location storage does not replace the full authentication, delivery or chat backend. Device permissions, background tracking, camera, notifications and map launching require platform testing. Location and photos you create during a run are stored on your device or sent to the backend you explicitly configure.

## Validation limits

Flutter was unavailable in the sanitization environment, so compilation, analysis, tests and device flows have not been executed for this export. Review platform signing and network policy for your own installation. No release signing keys or production service configuration are supplied. No additional license grant is provided here.
