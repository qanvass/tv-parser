# WORKER HISTORY-BACK QA

**Date:** 2026-07-24 23:24 -04:00  
**Worker:** PARALLEL History/Back device QA (no Flutter rebuild)  
**Verdict:** **PASS**

## Scope

Android TV only: History → Back and Favorites → Back must return to the in-app TV dashboard rail, **not** Google TV Home / launcher.

## Device / build under test

| Item | Value |
|------|--------|
| AVD / serial | Android_TV_1080p / `emulator-5554` (`sdk_google_atv64_x86_64`, 1920x1080) |
| Package | `com.quasar.tvparser` `2.0.3` (versionCode `3001`) |
| APK | `store_release_package/app-release.apk` |
| APK mtime | 2026-07-24 23:21:46 |
| APK size | 232189030 bytes |
| SHA256 | `721B90B4E6CE77C0EA41E75C2741379B53EC8E5B13673DE737BD6C012B4647F9` |
| Install | `adb -s emulator-5554 install -r` → **Success** |
| Playlist | Existing review/demo CC feeds already loaded (Big Buck Bunny / Sintel Demo Streams) — no new M3U needed |

Polled sibling rebuild up to ~15 min; newest APK settled at **22:58:06** (flutter-apk + store copy identical) before install. Did **not** run `flutter build`.

## Results

### History → Back — PASS

1. Opened rail **History** → Catch Up screen (`CATCH UP` / `No movies in progress`).
2. Pressed `KEYCODE_BACK` (4).
3. Focus remained `com.quasar.tvparser/.MainActivity`.
4. UI again showed TV dashboard markers: Live TV, Movies, Series, Search, Favorites, History, Settings + Demo Streams.

### Favorites → Back — PASS

1. Opened rail **Favorites** → Favourites screen (`FAVOURITES` / `No favourite channels yet`).
2. Pressed `KEYCODE_BACK` (4).
3. Focus remained `com.quasar.tvparser/.MainActivity`.
4. UI again showed full TV dashboard rail + Demo Streams (not Google TV Home).

| Case | Open focus | After Back focus | Destination | Pass |
|------|------------|------------------|-------------|------|
| History | `MainActivity` | `MainActivity` | TV dashboard | YES |
| Favorites | `MainActivity` | `MainActivity` | TV dashboard | YES |

**Not observed:** `com.google.android.tvlauncher` / Google TV Home after Back from either screen.

## Evidence

Canonical copies in `store_release_package/`:

- `qa_hb_01_dashboard.png` — baseline TV dashboard (demo CC)
- `qa_hb_02_history_open.png` — History / Catch Up open
- `qa_hb_03_history_after_back.png` — after Back (still dashboard)
- `qa_hb_04_favorites_open.png` — Favorites open
- `qa_hb_05_favorites_after_back.png` — after Back (still dashboard)

Full set + machine JSON: `store_release_package/qa_history_back/` (`10_`…`14_` PNGs, `result.json`).

## Safety / coexistence

- Did **not** touch `tvparser_restore_point_overnight.zip`
- Did **not** fight Play Console worker / upload
- Did **not** rebuild AAB/APK
- Neutral player framing; CC demo streams only

## Note

An accidental earlier probe pressed Back while still on the home rail (false `Categories` nested heuristic) and exited to launcher — that was **test harness error**, not the History/Favorites flows. Controlled History/Favorites cases above are the QA verdict.
