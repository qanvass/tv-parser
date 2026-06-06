# Contributing to TV Parser

Thank you for your interest in contributing to TV Parser! As an open-source player shell, we welcome enhancements to UI, navigation, player integration, and performance.

To maintain a secure and compliant codebase, please follow the guidelines below.

---

## 🚫 Critical Guidelines (No Secrets)

> [!CAUTION]
> **Never commit or submit:**
> - Private API keys, server URLs, or playlist files (`.env`, `key.properties`, `.jks`).
> - Playlists containing copyrighted channels or media streams.
> - Active service account JSON configurations.
>
> Any pull requests containing hardcoded credentials or unauthorized streams will be rejected and deleted immediately.

---

## How to Contribute

### 1. Reporting Bugs

If you find a bug:
- Check if it has already been reported in the **Issues** tab.
- If not, open a new issue using our **Bug Report** template.
- Provide clear reproduction steps, device info (Android version, Mobile or TV), and non-sensitive logs.

### 2. Requesting Features

For new feature proposals:
- Create a new feature request issue.
- Describe the feature's utility and platform applicability (TV, Mobile, or both).
- Ensure the requested feature aligns with legal player guidelines (no pre-packaged playlists or streams).

### 3. Submitting Pull Requests (PR)

- Branch from `master` and keep your changes atomic.
- Run `flutter analyze lib/` to ensure zero compilation or styling warnings.
- Run `flutter test` to verify unit test cases pass.
- Submit a PR utilizing our **Pull Request Template**.
- Check off the template's verification list.

---

## Coding Standards

- Follow the standard Flutter guidelines.
- Use explicit types instead of `var` or `dynamic` where possible.
- Wrap UI elements properly to support thin mobile viewports and large Android TV screens.
- Keep business logic isolated from UI layouts using the configured BLoC patterns.
