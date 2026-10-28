# Fleet Driver App

A Flutter application for driver sign-in, trip status, delivery checkpoints, receipt capture, background location and dispatch chat.

## Setup

Requires Flutter with a Dart 3.11.1-compatible SDK and the platform toolchains.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Configure the backend through a compile-time setting:

```sh
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/
```

The default URL is `https://example.invalid/`; a backend is not bundled. Use the appropriate host address and network policy for your emulator or device. API paths and DTOs define the expected service contract, including the SignalR chat hub. TLS validation uses platform defaults.

## Development notes

Admin tools provide selected mock trip responses and offline UI controls. They do not replace the authentication, delivery or chat backend. Sample coordinates and images are placeholders.

GPS, camera access, background tracking, notifications and map launching require device permissions and platform testing. Captured locations and photos are stored locally or sent to the configured backend. Supply your own signing configuration and keep credentials and user data out of version control.

Compilation, analysis and device flows have not yet been verified for this version.
