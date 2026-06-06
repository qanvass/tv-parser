# TV Parser

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)](https://www.android.com)
[![Android TV](https://img.shields.io/badge/Android%20TV-80C040?style=flat&logo=android&logoColor=white)](https://www.android.com/tv/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Open Source](https://img.shields.io/badge/Open%20Source-%E2%9D%A4-red)](https://github.com/qanvass/tv-parser)

## TV Parser - Flutter IPTV / M3U / Xtream Media Player for Android TV and Mobile

TV Parser is a highly customizable, legal, and open-source media player app shell built with Flutter. It is designed to run seamlessly on both Android Mobile devices and Android TV / Fire TV platforms, offering a premium and responsive user experience for streaming M3U playlists and interacting with Xtream Codes portals.

---

> [!IMPORTANT]
> **Legal Disclaimer & Store Compliance**
> TV Parser is a pure media player shell. It does **not** provide, host, or link to any media streams, television channels, playlists, or IPTV subscriptions. Users must bring their own authorized M3U playlists or login credentials from their chosen provider. TV Parser does not endorse or facilitate the viewing of copyrighted content without proper authorization.

---

## Key Features

- **Android TV / Fire TV Native UX:** Fully optimized for D-pad navigation, focus animations, and 10-foot UI layouts.
- **Android Mobile Native UX:** Beautiful, touch-first responsive design matching the mobile watch screen dashboard guidelines.
- **Xtream Codes API Integration:** Built-in portal connection support for retrieving live, movie, and series catalogs.
- **M3U Playlist Parsing:** Robust offline parsing and caching of local or remote playlists.
- **Compliance-Safe Client Caching:** YouTube trailer preview integrations with `GetStorage` caching, operating within YouTube compliance boundaries (no stream preloading or file rehosting).
- **VLC-Based Playback Engine:** Powered by high-performance VLC media player wrappers for maximum codec compatibility.
- **Public/Private Configuration Split:** Safe and clean architectural separation of the open-source client codebase and private environment parameters.

---

## Screenshots

*(Place screenshots demonstrating Mobile and Android TV UI here)*

---

## Installation & Build Instructions

### Prerequisites

- Flutter SDK (>= 3.10.3)
- Android SDK & Gradle configured

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/qanvass/tv-parser.git
   cd tv-parser
   ```
2. Copy the environment template:
   ```bash
   cp .env.example .env
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Build the release APK:
   ```bash
   flutter build apk --release
   ```
5. Build the release Android App Bundle (AAB) using Gradle:
   ```bash
   cd android
   .\gradlew.bat :app:bundleRelease
   ```

---

## Security & Exclusion Notice

To comply with play store guidelines and prevent token misuse, this public repository does **not** contain:
- Environment secrets or private key parameters (`.env`, `key.properties`, `upload-keystore.jks`).
- Production Google Play Console service account credentials.
- Hardcoded stream URLs or private API configurations.

Please refer to [SECURITY.md](SECURITY.md) for more details on how to configure your own deployment credentials.

---

## Project Roadmap

See [ROADMAP.md](docs/ROADMAP.md) for planned future features, including:
- Polish of Android TV banner scaling and navigation focuses.
- Advanced stream diagnostics panel.
- Buffer configuration for VLC playback profiles.
- Localization (i18n) and accessibility improvements.

---

## Contributing

We welcome contributions to the TV Parser player shell! Please review [CONTRIBUTING.md](CONTRIBUTING.md) to understand our coding standards and submission guidelines.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Keywords

Flutter IPTV player shell, Android TV M3U player, Xtream Codes media player template, open source Fire TV player, VLC media player Flutter.
