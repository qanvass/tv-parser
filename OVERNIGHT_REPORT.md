# Overnight report — Movies TMDB artwork

**Date:** 2026-08-11  
**Mode:** autonomous finish-until-done + stable checkpoint for ChatGPT audit push  
**No commit of secrets. No GitHub reset.**

## Root cause(s)

1. **Cache key mismatch (primary, class J/L).**  
   Rail records keyed TMDB cache with `ch.name` (e.g. `Deb Is Boss (2026)` → year `2026`).  
   Enqueue keyed with `stream.title` (`Deb Is Boss` after year strip → year empty).  
   Worker wrote hits under `movie|{id}|deb is boss|`.  
   Cards looked up `movie|{id}|deb is boss|2026`.  
   Lookup always missed → colored placeholders forever even when `/find` succeeded.

2. **Permanent negative cache (amplifier).**  
   First failed/empty jobs stored `{miss:true}` with no TTL. Later visits skipped those keys forever.  
   Exceptions also called `putMiss`.

3. **Release `debugPrint` stripped.**  
   Zero `[TMDB_MATCH]` lines on 3006 did **not** prove TMDB failed.

## TMDB auth / IMDb samples (host)

| Check | Result |
|---|---|
| tmdbAuth | **PASS** HTTP 200 |
| tt1375666 Inception | movieCount=1 tmdbId=27205 poster=Y backdrop=Y |
| tt0111161 Shawshank | movieCount=1 tmdbId=278 poster=Y backdrop=Y |
| tt27545912 Deb Is Boss | movieCount=1 tmdbId=1634159 poster=Y backdrop=Y |

API and `/find` are fine. Deb Is Boss is **not** unmatched at TMDB.

## Exact files changed this checkpoint

- `lib/repository/provider/tmdb_enrichment_worker.dart` — cache key includes explicit year; no miss-on-exception
- `lib/repository/provider/tmdb_metadata_cache.dart` — 20-minute miss TTL; legacy misses without `missAt` expire immediately
- `lib/presentation/tv/tv_dashboard_shell.dart` — movie/series keys use display title + record year (same as enqueue)
- `lib/repository/provider/media_metadata_enrichment_service.dart` — `[TMDB_MATCH]` via `print` (survives release)
- `test/tmdb_imdb_lookup_test.dart` — key-alignment tests
- `pubspec.yaml` — `2.0.3+3007`

Prior local work (catalog Phase 0/2, cinematic Movies, IMDb preserve, `/find`) remains in the tree and is part of the audit push.

## Tests

`flutter test` (temp copy; workspace `build/` locked): **30 passed**  
(`tmdb_imdb_lookup`, `cinematic_artwork_fallback`, `playable_trailer_url`, `category_presentation_mapper`)

## Builds

- Private **3006** was previously installed (pre-fix). Posters not proven.
- **3007** private bake: started after this checkpoint (dart-define key, never logged).

## Device (3006, pre-fix)

- Movies opens immediately: **Y**
- Real posters: **N** (lookup miss)
- Hero real art: **N**
- Progressive replace: **N**
- No 18k scan: **Y**
- D-pad: **Y**
- Playback: not re-tested this pass

## Progressive UI / hero / cache

**Expected after 3007:** same card/hero upgrade when worker `notifyListeners` + aligned keys.  
**Not yet visually proven on Chromecast** until 3007 is installed.

## Live / HotPlayer Phase 1

Not started (sequence lock: Movies art first).

## Unresolved

- Chromecast visual proof of real posters still pending 3007 install.
- ADB wireless drops are operational, not an app-architecture issue.
- Public APK must not bake TMDB key (Plan B server-side later).

## Severity of remaining

**High until 3007 is seen on TV.** Code-level root cause is identified and fixed; visual DoD not complete without device.

## Next safest action

Install private 3007 on `10.0.0.27`, open Movies, confirm posters replace placeholders and hero upgrades. Then freeze Movies art path.
