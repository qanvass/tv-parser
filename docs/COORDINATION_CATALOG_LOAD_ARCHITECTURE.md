# Catalog load architecture (Flutter, not Room)

**Official spec moved to:** [`COORDINATION_CATALOG_ENGINE.md`](COORDINATION_CATALOG_ENGINE.md) (A–H + 18-point engine). This file is historical recommendation notes.

**Status:** Recommendation only — do **not** implement a DB rewrite in this pass  
**Updated:** 2026-08-11  
**Constraint:** Neutral media player. Do not invent titles/art. Live-first login. Do not fight the in-flight Movies empty-rail fix.

---

## Verdict

**Need AI to filter/load ~18.6k movies / ~100k series? NO.**

AI on the login/import path would **slow IPTV login**, burn quota, and invent metadata we are not allowed to ship. TV Parser already has the right stance in code comments and flags. Keep it.

**Best faster/smarter load:** three-tier progressive publish, already half-built.

```text
LOGIN → download Live M3U + auth → parse once (deterministic)
      → immediately publish Live + first movie rows + first series rows
      → BACKGROUND: remaining shards / group / normalize / art / search / enrich / cache
AI    → unmatched leftovers only, permanently cached, ENABLE_GEMINI off by default
```

**Priority:** `PLAYBACK DATA > UI DATA > ENRICHMENT > AI`

Agree with the proposed architecture. Refine only where this Flutter tree already differs from a Kotlin/Room/Paging sketch.

---

## Evidence from this tree (not Kotlin)

| Claim | Actual code |
|-------|-------------|
| Catalog is **JSON file cache**, not SharedPreferences | `LocaleApi` writes `getApplicationSupportDirectory()/m3u_cache/{m3u_movies,m3u_series,...}.json`. Comments explicitly avoid the SP ~1MB binder cap. GetStorage keeps only user + count markers. |
| Login does **not** wait for VOD | `IptvProviderSession.commitM3u` persists Live, then `// ignore: unawaited_futures _syncVodAfterLive(...)`. Hydrate path: `warmM3uCache()` Live-only; `warmM3uVodCache()` after first frame. |
| Movies ~18.6k already land | `[VOD_M3U] movies stored=18601` on Chromecast (2026-08-11). `StarliteVodM3uSession` fetches `/m3u8/movies` first and persists before series shards. |
| Movies UI bug is **empty categories / full-list rails**, not “need AI” | Splash/login fires `GetMovieCategories` before VOD sync → `MovieCatySuccess([])`. Live list API is live-only. Rails are category-keyed. In-flight FIX 2 in `tv_dashboard_shell` groups by `categoryId` when cats are empty — **do not rewrite that fallback**. |
| Series shards can be huge | `StarliteVodM3uUrls.maxTvShowShards = 20`, tip `typicalShardExtinf = 5000` → up to ~100k. `_fetchAndPersistSeries` concatenates **all** shards into one `StringBuffer`, then `M3uParser.parseCatalog` **once**, then one `m3u_series.json` write. |
| Gemini is optional leftover enrichment | `ENABLE_GEMINI` default **false**. `GeminiChannelIntelligenceService` returns null unless flagged + keyed. Used for plot/logo-domain/trailer query after paint. Cached (GetStorage TTL 30d). |
| TMDB is queued, not login | `TmdbEnrichmentWorker`: “Never blocks splash / Live first frame.” 280ms pump. Shell enqueues first 8 rails × 24 titles only. No-ops without `TMDB_API_KEY`. Disk cache `m3u_cache/tmdb_enrichment.json`. |
| Search is already a local token index | `SearchIndexService.buildIndex` via `compute()`. `AiIntentMapper` is regex/keyword expansion, **not** an LLM. |
| Title cleanup is deterministic | `TitleNormalizer` strips quality/year/episode tokens. Does not invent titles. `SeriesRailGrouper` collapses same-show episode rows. |
| UI lists are already lazy **widgets** | `ListView.builder` in `tv_channel_grid.dart` / `tv_home_rows.dart`. The cost is **materializing all `TvStreamRecord`s** before first Movies `setState`. |
| Live preview ≠ catalog | Splash uses `video_player` (Android → ExoPlayer/Media3). Live hero is XMLTV + ClearLogo, **no second decoder**. Playback is independent of catalog size. |
| No Room / sqflite / Drift today | Xtream JSON parse uses `compute()`; M3U parse does **not**. Do not add a database in this increment. |

---

## Current vs target

### Current (what actually happens)

```text
registerM3u
  → download Live playlist (main isolate)
  → M3uParser.parseCatalog(Live)          // sync, caller isolate — OK for ~2.7k live
  → LocaleApi file persist Live (+ empty VOD if live-only)
  → return user → splash GetMovieCategories() → often []
  → shell paints Live
  → unawaited StarliteVodM3uSession.syncFromLivePlaylist
        1) fetch+parse+persist ALL movies (~18.6k)     // still caller isolate
        2) fetch shards 1..N, concat, parse ALL series // can be 100k + tens of MB
        3) THEN onVodCatalogReady()
  → _loadVodRailsInBackground
        Future.wait([getMovieChannels(""), getSeriesChannels("")])  // waits for BOTH
        → build SearchIndex on full lists (isolate — good, but late)
        → build EVERY movie TvStreamRecord, then setState
        → build EVERY series record + SeriesRailGrouper, then setState
        → enqueue TMDB for visible-ish window
```

Gaps vs the proposed three-tier:

1. **Movies first-paint waits on series.** `onVodCatalogReady` and `Future.wait` both wait for the huge series blob even though movies are already on disk.
2. **M3U VOD parse is not isolated.** `compute()` exists for Xtream + search + XMLTV gzip — not for `M3uParser.parseCatalog` of 18k/100k.
3. **Series is all-or-nothing.** No publish after shard 1. One giant string + one giant JSON file.
4. **Rails materialize the full catalog** into `TvStreamRecord` lists before first Movies frame. Widgets are lazy; **data is not**.
5. **Gemini cache is GetStorage** (fine while off). If AI is ever enabled, leftovers must use the same file-cache pattern as TMDB — never SharedPreferences for 18k payloads.

### Target (Flutter three-tier — same idea, native types)

| Tier | What | When | Flutter mechanism |
|------|------|------|-------------------|
| **0. Playback data** | `directSource`, id, raw name, `group-title` → `categoryId` | As soon as a row parses | `M3uParser` (deterministic). Persist incrementally. |
| **1. UI data** | Live rows now; first movie rail window; first series rail window; category chips | Before remaining shards / search / art | `setState` / `HydrateMovieCategories` on **movies-ready**, not series-complete. `ListView.builder` already. Cap records per rail on first paint. |
| **2. Enrichment** | `TitleNormalizer`, `SeriesRailGrouper`, posters, XMLTV, TMDB queue, search token index | After first paint | Existing workers + `compute()` for parse/index. |
| **3. AI (optional)** | Plot/logo/trailer query for **unmatched leftovers only** | Idle, never login | `ENABLE_GEMINI` + file cache. Permanent hit, no re-call. |

Login critical path stays: **auth + Live download + Live parse + Live persist + navigate**. Everything else is background.

---

## Kotlin / Room / Paging → Flutter we can actually use

Do **not** port Room. Map the *intent*:

| Android sketch | Flutter equivalent **now** | Later (only if file+RAM hurts Chromecast) |
|----------------|----------------------------|-------------------------------------------|
| Room entities | `ChannelMovie` / `ChannelSerie` + `m3u_cache/*.json` | Drift or sqflite tables keyed by `streamId` |
| Paging 3 `PagingSource` | Slice first N per category into rails; `ListView.builder` already virtualizes cards | `ScrollablePositionedList` / custom window if a single row is 5k+ |
| `Dispatchers.Default` | `compute()` / `Isolate.run` for `parseCatalog` + JSON decode | Same |
| WorkManager | Unawaited `Future`s already used for VOD/XMLTV/capabilities | Keep |
| `RemoteMediator` | Shard loop in `StarliteVodM3uSession` — persist **per shard**, notify UI | Optional |

**Not now:** full Drift schema, Paging library, Room rewrite, SharedPreferences catalog, Gemini-on-every-title.

---

## What NOT to do

- **Gemini / any LLM on login, import, or every title.** Would stall splash and invent synopses.
- **Wait for 100k series before Movies first paint.** Movies persist first today; the UI hook and `Future.wait` throw that away.
- **Build 18k movie widgets or 100k series widgets before first paint.** Also do not build 18k `TvStreamRecord`s before first paint — same OOM/jank class on Sabrina.
- **Search via LLM.** Keep `SearchIndexService` tokens. `AiIntentMapper` stays local keywords.
- **Rewrite the dashboard Movies empty-rail fallback** currently landing (FIX 2 / hydrate-after-VOD). That worker owns empty-cats → group-by-`categoryId`. This doc does not change that code.
- **Put the catalog in SharedPreferences / GetStorage.** Already fixed once.
- **Touch `tvparser_restore_point_overnight.zip`, commit, or change the playlist.**
- **Second decoder / catalog-wide preview.** Live preview (when added) = focused stream only via `video_player`/ExoPlayer. Independent of catalog size.

---

## Flutter-specific tiers (concrete files)

```text
Auth.registerM3u
  lib/repository/api/auth.dart
    → IptvProviderSession.commitM3u
         lib/repository/api/iptv_provider_session.dart
         lib/repository/api/m3u_parser.dart          // deterministic classify
         LocaleApi.saveM3uChannels                   // file cache
         unawaited _syncVodAfterLive
              StarliteVodM3uSession                  // movies then shards
              ApolloNativeCatalogSession             // fallback only if movies empty

Splash / login
  GetLiveCategories + GetMovieCategories             // movie cats often [] — expected
  warmM3uCache() live-only

TV shell
  _loadRealPlaylistContent                           // Live first, _loading=false
  _loadVodRailsInBackground                          // must not Future.wait series
  onVodCatalogReady                                  // today: after movies+series
  SearchIndexService.buildIndex                      // isolate, after first VOD paint
  TitleNormalizer / SeriesRailGrouper                // UI data, not AI
  TmdbEnrichmentWorker                               // enrichment
  GeminiChannelIntelligenceService                   // leftovers only, flag off
```

---

## Next incremental steps (AFTER Movies empty-rail fix lands)

Do not start these until the other worker’s Movies fallback/hydrate is in and rails show the 18.6k catalog without empty-category death. Then, in order:

1. **Decouple Movies first-paint from series shards.**  
   Fire a movies-ready signal when `saveM3uMovies` returns (session already persists movies before `_fetchAndPersistSeries`). Split `_loadVodRailsInBackground` so `getMovieChannels` is not `Future.wait`’d with `getSeriesChannels("")`. Keep the existing empty-rail fallback; only stop waiting on series.

2. **Isolate VOD parse + persist series per shard.**  
   `compute(M3uParser.parseCatalog, body)` for `/m3u8/movies` and each tvshows shard. Persist/merge after shard 1 so Series can show a first window. Stop concatenating 20 shards into one string before any UI publish. Still one file cache — no Drift.

3. **Window rails + defer search.**  
   First paint: first ~24–48 `TvStreamRecord`s per visible rail (widgets are already lazy). Build `SearchIndexService` after that paint, still via `compute()`, still local tokens. TMDB/Gemini stay behind first paint; Gemini remains leftovers-only.

Optional later (only if Chromecast still janks on `jsonDecode` of `m3u_series.json`): Drift/sqflite + windowed reads. Not a login blocker and not this week’s rewrite.

---

## Acceptance

- Login/splash time does not include Gemini, TMDB, series-shard completion, or search-index build.
- Movies rails can appear from file cache / movies persist **while** tvshows shards continue.
- No invented titles. Playback URLs come only from the playlist.
- `ENABLE_GEMINI` default false. Search remains `SearchIndexService`.
- Movies empty-rail fix remains owned by the other worker.
