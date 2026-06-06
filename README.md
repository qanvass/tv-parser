# TV Parser

A compliant, secure, and modern Flutter application for Android and Android TV, built as a customizable player shell.

---

## Security Notice

This repository does not include private API keys, signing keys, provider credentials, service account files, or production environment variables.

Create your own `.env` file from `.env.example` and configure private deployment credentials through GitHub Actions Secrets or your own secure CI/CD environment.

**Do not commit:**
- `.env` files
- Android keystores (`*.jks`, `*.keystore`)
- `key.properties`
- Google Play service account JSON files
- Firebase admin credentials
- Private provider URLs or credentials

---

## Getting Started

This project is a Flutter application supporting both mobile and Android TV form factors.

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (matching the constraints in `pubspec.yaml`)
- Android SDK and build tools

### Setup

1. Copy `.env.example` to `.env` and configure your local placeholders:
   ```bash
   cp .env.example .env
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```
