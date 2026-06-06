# Security Policy

## Supported Versions

We actively maintain and support security patches for the latest release branch of TV Parser:

| Version | Supported |
| ------- | --------- |
| 2.0.x   | ✅ Yes    |
| < 2.0   | ❌ No     |

---

## Reporting a Vulnerability

> [!WARNING]
> **Do not open public GitHub issues for security vulnerabilities or credential exposures.**

If you discover a security vulnerability or think a secret has been exposed:
1. Email a report privately to the maintainers at `security@qanvass.com` (or contact the repository owner directly).
2. Include description details, potential impact, and steps to reproduce.
3. We will acknowledge receipt of your report within 48 hours and coordinate a patch branch before publishing the details.

---

## Credentials Safety

TV Parser operates strictly as a local media player shell. All credentials (usernames, passwords, and portal servers) entered by users inside the app are stored locally on their device using secure storage systems (`GetStorage`). No credentials or personal streaming metadata are collected or sent to external servers by this codebase.
