# TV Parser Catalog Engine (official spec)

**Status:** Official ingest architecture. Phase 0 owned elsewhere. Phase 1 telemetry only — **do not start Phase 2** until Phase 0 is verified on TV **and** a `[CATALOG_PERF]` timing table exists.  
**Updated:** 2026-08-11  
**Supersedes (as the living spec):** `docs/COORDINATION_CATALOG_LOAD_ARCHITECTURE.md` (keep as historical notes).  
**Constraints:** Neutral media player. No invented titles/art. No playlist rewrite. No TMDB/Gemini on login. Do not fight Phase 0 Movies empty-rail work in `tv_dashboard_shell.dart`. File JSON stays until F is proven insufficient after Phases 2–7.

Ultra TV / Room / Paging 3 are **patterns**, not ports. Flutter mapping: isolates/`compute()`, existing `ListView.builder`, `m3u_cache/*.json` now, Drift/sqflite **only** if Section F still fails after windowed reads.

---

## Performance budgets (measure; do not claim)

| Budget | Target | Measured yet? |
|--------|--------|----------------|
| Login → usable Live | **2s** | No — Phase 1 logs `firstLiveMs` |
| First Movies row | **3s** | No — Phase 1 north star `movie_first_row_ms` (rail start → first `_movieRows` setState, **not** full VOD) |
| First Series row | **4s** | No — Phase 1 logs `series_first_row_ms` |
| Search first result | **300ms** | No — index build logs `searchIndexReadyMs`; query already logs ms |
| Refresh | **no UI blank** | Partial — FIX 3 keeps `_movieRows` (Phase 0 worker) |
| Memory | Never hold **100k Dart models + 100k widgets** together | Not measured — see E |
| AI on login | **0ms** | Yes by construction — `ENABLE_GEMINI` default false; TMDB after first paint |

Logcat contract (no passwords, no full URLs):

```text
[CATALOG_PERF] stage=<name> reason=… isolate=<Isolate.debugName>
  app_shell_ms=… login_validation_ms=… live_parse_ms=…
  movie_cache_read_ms=… movie_json_decode_ms=… movie_group_ms=… movie_first_row_ms=…
  series_cache_read_ms=… series_json_decode_ms=… series_group_ms=… series_first_row_ms=…
  search_index_ms=… movieJsonBytes=… seriesJsonBytes=…
  liveCount=… movieCount=… seriesCount=…
  movieCategoryCount=… seriesCategoryCount=… movieRowCount=… seriesRowCount=…
```

`movie_first_row_ms` = ms from movie-rail start (`_moviesRailStartedAt` / `anchor(movie_rail)`) until the first usable `_movieRows` `setState`. It is **not** `vodCatalogReadyMs`. Optional `movie_first_row_from_tab_ms` starts when the user opens the Movies tab.

---

## 18-point spec (Flutter-mapped)

| # | Rule | Flutter mapping (now → target) |
|---|------|--------------------------------|
| 1 | **Two-phase login** | Enter app in seconds: Live download + parse + persist + navigate. VOD is unawaited today (`_syncVodAfterLive`). Target: Live usable ≤2s; Movies/Series never on the login await chain. |
| 2 | **Streaming / chunked M3U ingest** | Batch 250–1000 EXTINF, release temps. Today: full-string `M3uParser.parseCatalog` on caller isolate; series shards concatenated into one `StringBuffer` then one parse. Target: `compute()` per chunk/shard; drop raw string after persist. |
| 3 | **Independent Live / Movie / Series pipelines** | Series must never hostage Movies. Today: `syncFromLivePlaylist` awaits movies **then** all series shards; `onVodCatalogReady` and dashboard `Future.wait([getMovieChannels, getSeriesChannels])` wait for both. Target: persist movies → publish → series continues alone. |
| 4 | **Local source of truth** | Conceptual schema (not a new DB this pass): `content(id, type, name, group_id, url, logo, tvg_id, generation_id)`, `groups(id, name, type)`, `hidden_groups(user pref)`, `playlist_fingerprint`. Today: `ChannelLive` / `ChannelMovie` / `ChannelSerie` + `CategoryModel` in `m3u_cache/*.json`. |
| 5 | **Paging / virtualization** | Query window (~LIMIT 40), not 18,601 cards. Widgets: `ListView.builder` already. Data: dashboard still materializes **every** `TvStreamRecord` before first Movies `setState`. Target: first-paint slice 24–48 per visible rail. |
| 6 | **Non-destructive refresh** | Never `_movieRows = []` then rebuild. Phase 0 FIX 3 already keeps movie rows on reload. Target: `generation_id` swap when new snapshot is ready. |
| 7 | **Diff playlist by fingerprint** | Today: shard duplicate detect via `StarliteVodM3uUrls.bodyFingerprint` only. Target: playlist-level fingerprint; skip rewrite when unchanged. |
| 8 | **CONTENT PRIMARY, category secondary** | `18601 movies + 0 cats ≠ empty`. Phase 0 FIX 2 groups by `categoryId` when cats/rails are empty. Engine rule: empty UI only if **raw content count == 0**. |
| 9 | **Search index in the data layer** | Do not rebuild on Search open. Today: `SearchIndexService.buildIndex` via `compute()` from dashboard after `Future.wait` both catalogs; Search screen may rebuild if not ready. Target: incremental upsert (live, then movies, then series) after each persist. |
| 10 | **Enrichment last; placeholder cards** | Playback URL + raw name first. `TitleNormalizer` / posters / TMDB / Gemini after paint. Gemini leftovers-only, flag off. |
| 11 | **Smart group hide** | Hide is a **user preference**, never delete provider records. Today: adult filter drops rows from rails/index; no `hidden_groups` table. Target: filter at query time. |
| 12 | **Explicit performance budgets** | Table above. Phase 1 emits `[CATALOG_PERF]`. Do not ship “faster” without numbers. |
| 13 | **Incremental search** | Merge tokens when a pipeline finishes; do not wait for 100k series to search movies. |
| 14 | **Async metadata** | XMLTV / TMDB / capabilities stay unawaited. Never block Live or first movie row. |
| 15 | **Artwork priority** | Provider `streamIcon` / cover first; TMDB fill-in later; never invent art. Card without poster still playable. |
| 16 | **Cancellation** | New login / logout / playlist change must cancel in-flight VOD fetch/parse. Today: no cancel token on Starlite Dio loop. |
| 17 | **Live preview separate** | Splash/`video_player` and Live hero XMLTV+ClearLogo are **not** catalog. No second decoder over the catalog. Independent of catalog size. |
| 18 | **Telemetry** | Structured `[CATALOG_PERF]` only. Host ok; never user/pass/full playlist URL. |

Priority forever: **PLAYBACK DATA > UI DATA > ENRICHMENT > AI**. AI = 0ms on login.

---

## A. Current architecture map

Evidence from this tree (2026-08-11). Thread = Dart isolate. “UI waits” = user cannot use that surface yet.

```text
AuthLoadM3u / AuthApi.registerM3u          [main isolate, UI WAITS]
  └─ Dio GET playlist                      [IO, awaited]  downloadMs
       └─ IptvProviderSession.commitM3u    [main, awaited]
            ├─ M3uParser.parseCatalog      [main, SYNC]   parseMs
            │    classify live/movie/series (deterministic)
            ├─ LocaleApi.saveM3u* Live     [IO, awaited]  file + mem
            ├─ LocaleApi.saveM3u* VOD      [IO, awaited]  only if Live M3U contained VOD
            ├─ LocaleApi.saveUser          [GetStorage]
            ├─ unawaited _syncVodAfterLive
            │    └─ StarliteVodM3uSession.syncFromLivePlaylist
            │         ├─ GET /m3u8/movies + parse + saveM3uMovies     [main]
            │         ├─ GET tvshows shards 1..N, concat, ONE parse   [main]
            │         ├─ saveM3uSeries
            │         └─ THEN onVodCatalogReady()                     [too late]
            ├─ unawaited ProviderCapabilityInspector
            └─ unawaited XmlTvRepository.ensureLoaded
       return UserModel → AuthSuccess

Splash (AuthSuccess)                       [main]
  ├─ GetLiveCategories / GetMovieCategories / GetSeriesCategories
  │    M3U path: sync read LocaleApi (movie cats often [] — Live list is live-only)
  └─ navigate Welcome → TvDashboardShell   [does NOT wait for VOD sync]

TvDashboardShell._loadRealPlaylistContent  [main]
  ├─ await getLiveChannels("")             [mem/file copy]
  ├─ build ALL live TvStreamRecord         [main, SYNC]
  ├─ setState Live + _loading=false        firstLiveMs  ← UI usable
  └─ unawaited _loadVodRailsInBackground
       ├─ await warmM3uVodCache()          [main jsonDecode of movies+series files]
       ├─ Future.wait(getMovieChannels(""), getSeriesChannels(""))  ← COUPLED
       ├─ SearchIndexService.buildIndex(live+movies+series)         [compute isolate]
       ├─ build ALL movie TvStreamRecord → setState _movieRows      firstMovieMs
       ├─ build ALL series TvStreamRecord + SeriesRailGrouper       firstSeriesMs
       └─ _enqueueVodForTmdb()             [after rails; not required to render]

SearchIndexService                         [compute isolate for build]
  └─ in-memory List<SearchIndexEntry> holding the same Channel* objects

Enrichment (never login-critical)
  TitleNormalizer per card (main, cheap per title, expensive × N)
  TmdbEnrichmentWorker (280ms pump, first 8×24, needs key)
  GeminiChannelIntelligenceService (ENABLE_GEMINI default false)
```

| Stage | File | Isolate | UI waits? |
|-------|------|---------|-----------|
| Auth + Live download | `auth.dart` `registerM3u` | main + IO | **Yes** — login spinner |
| Live parse/classify | `m3u_parser.dart` | **main, sync** | **Yes** |
| Live persist | `locale.dart` `saveM3uChannels` | main + IO | **Yes** |
| Starlite movies M3U | `starlite_vod_m3u_session.dart` | main + IO | No (unawaited after login) |
| Starlite series shards | same, `_fetchAndPersistSeries` | main + IO | No for login; **Yes for Movies UI** via `Future.wait` |
| Category blocs | `*_caty_bloc.dart` | main | Splash fires early; movie cats often `[]` |
| Movie rails | `tv_dashboard_shell.dart` | main | Movies tab until `setState(_movieRows)` |
| Series rails | same | main | Series tab; also blocks Movies today |
| Search index | `search_index_service.dart` | `compute()` | Search if opened before ready |
| UI virtualization | `tv_home_rows.dart` `ListView.builder` | main | Widgets lazy; **lists are not** |
| Enrichment | TMDB / XMLTV / Gemini | IO / isolate | No (after paint) |

---

## B. Current first-run timeline (best-effort from code)

Cold login, empty `m3u_cache`, Starlite `/api/list/{user}/{pass}` (Chromecast 2026-08-11: live≈2726, movies≈18601, series shards up to ~100k).

| T | What | Awaited on login? |
|---|------|-------------------|
| 0 | `AuthLoadM3u` → `registerM3u` Dio GET Live M3U | **Yes** |
| 1 | `commitM3u` `parseCatalog(Live)` ~2.7k EXTINF, caller isolate | **Yes** |
| 2 | Persist live (+ empty/partial VOD if present in Live body) | **Yes** |
| 3 | Return user → `AuthSuccess` → splash starts category fetches | Login done |
| 4 | `// ignore: unawaited_futures _syncVodAfterLive` | **No** |
| 5 | Splash `GetMovieCategories` → often `MovieCatySuccess([])` | N/A (wrong moment) |
| 6 | Navigate to Live shell; `_loadRealPlaylistContent` awaits Live only; `_loading=false` | Live usable |
| 7 | Background: fetch+parse+persist **all** movies | No |
| 8 | Background: fetch shards, concat, parse **all** series, persist | No |
| 9 | `onVodCatalogReady` (movies+series both done) | — |
| 10 | `_loadVodRailsInBackground` `Future.wait` movies **and** series | Movies UI waits here |
| 11 | `buildIndex` full live+movies+series via `compute()` | Search waits if open |
| 12 | Materialize all movie records → `setState` | First Movies row |
| 13 | Materialize all series records → `setState` | First Series row |
| 14 | TMDB enqueue / XMLTV already running | After paint |

**AI: 0ms on this path.** Gemini not called. TMDB not required to render (`_movieStreamRecord` always builds a playable row).

---

## C. Current warm-start timeline

App restart with existing user + `m3u_cache` files.

| T | What | Blocks first frame? |
|---|------|---------------------|
| 0 | `main()` GetStorage + `runApp` — **does not** await M3U warm | No |
| 1 | First frame callback: `warmM3uCache()` Live JSON only (`m3u_categories.json`, `m3u_channels.json`) | Can stall splash if Live JSON is huge; typically ~2.7k OK |
| 2 | `hydrateFromLocale()` sets `kind`, restores capabilities, unawaited XMLTV | Live-only reads; comments forbid `getM3uMovies` here |
| 3 | unawaited `warmM3uVodCache()` — `jsonDecode` movies + series files on **main** | Can jank after first frame; does not hold `runApp` |
| 4 | If movies mem empty: unawaited `_syncVodAfterLive` (network) | No |
| 5 | Splash `AuthGetUser` → `AuthSuccess` → same category race as first-run | Movie cats may still be `[]` if VOD file not warm yet |
| 6 | Shell: same Live-first then `_loadVodRailsInBackground` including `await warmM3uVodCache()` + `Future.wait` both catalogs | Movies still wait on series JSON decode |

Warm start is **faster only if files exist**; it is **not** windowed. `getM3uMovies()` / `getM3uSeries()` still return **entire** lists (and `List.from` copies).

---

## D. Main-thread / isolate blockers

| Blocker | Evidence | Isolate | Severity |
|---------|----------|---------|----------|
| `Future.wait([getMovieChannels(""), getSeriesChannels("")])` | `tv_dashboard_shell.dart` `_loadVodRailsInBackground` | main | **P0 for Movies** — series JSON/list holds movie rails |
| `onVodCatalogReady` after movies **and** series | `iptv_provider_session.dart` `syncStarliteVodM3uIfNeeded` | main | Couples hydrate to series |
| Series shard concat + one `parseCatalog` | `starlite_vod_m3u_session.dart` `_fetchAndPersistSeries` | **main, sync** | 20×~5k EXTINF → one giant string |
| Movies `parseCatalog` | same `syncFromLivePlaylist` | **main, sync** | ~18.6k on caller isolate |
| Live `parseCatalog` | `commitM3u` | **main, sync** | Login-critical; OK at ~2.7k |
| `warmM3uVodCache` / `_getM3uList` `jsonDecode` + `fromJson` | `locale.dart` | **main, sync** | Multi-MB `m3u_series.json` froze Chromecast when done on splash; deferred, still on main |
| `SearchIndexService.buildIndex` | `compute(buildSearchIndexInBackground)` | **isolate** (good) | Transfer of 18k+100k models to isolate can still be long. **54s not found in this repo** — service logs `durationMs=`. 54s is plausible on Sabrina if series is included; treat as unverified until Phase 1. |
| Full `TvStreamRecord` materialization | dashboard movie/series loops + `TitleNormalizer.parse` per row | **main** | Widgets lazy; **N models built before first Movies frame** |
| `TitleNormalizer` | cheap per title (`title_normalizer.dart`); called once per catalog row at rail build | main | Problem is ×18601 / ×100k, not the regex |
| Xtream JSON parse | `iptv.dart` uses `compute(_parseMovieChannels)` | isolate | M3U path does **not** use this |
| XMLTV gzip | `XmlTvRepository` isolate | isolate | After first frame |

---

## E. Duplicate full-catalog representations

Same titles can exist in all of these at once (this is the memory budget risk):

| Copy | Where | Lifetime |
|------|-------|----------|
| 1. Raw M3U string | `registerM3u` `response.data`; movies body; series `StringBuffer` of all shards | Until parse returns |
| 2. `M3uParseResult` typed lists | `M3uParser.parseCatalog` | Until persist |
| 3. File JSON | `m3u_cache/m3u_{channels,movies,series}.json` | Durable |
| 4. `LocaleApi` `_*Mem` | in-process source of truth | Until logout |
| 5. Session getter copies | `List.from` in `getM3u*` / `movieChannels()` | Per call |
| 6. Dashboard `allMovies` / `allSeries` | `_loadVodRailsInBackground` | Until method ends |
| 7. `_liveRows` / `_movieRows` / `_seriesRows` | `List<TvChannelRow>` of **all** `TvStreamRecord`s | Until next successful build |
| 8. `SearchIndexEntry.item` | holds the same `Channel*` instances again | Until `clearIndex` |
| 9. GetStorage count markers | `m3u_movies_count` etc. | Tiny |
| 10. TMDB / XMLTV caches | separate files under `m3u_cache/` | Enrichment only |

Widgets are virtualized (`ListView.builder` itemCount = **full** `streams.length`). Data layer is **not**. 18k movie records + 100k series records + index + JSON decode buffers can coexist.

---

## F. Persistence technology (inspect; do not add Drift this pass)

**What exists**

- Directory: `getApplicationSupportDirectory()/m3u_cache/`
- Files: `m3u_categories.json`, `m3u_channels.json`, `m3u_movie_categories.json`, `m3u_movies.json`, `m3u_series_categories.json`, `m3u_series.json` (+ capabilities, XMLTV, TMDB)
- API: `LocaleApi.saveM3u*` / `getM3u*` / `warmM3uCache` (Live) / `warmM3uVodCache` (VOD)
- Memory: six static lists; getters copy with `List.from`
- GetStorage: user session + **count markers only** (catalog was removed from SharedPreferences after the ~1MB binder cap)
- Write: full `jsonEncode` of the entire list, `flush: true`
- Read: full `jsonDecode` + `fromJson` map; **no LIMIT, no offset, no generation_id**

**Why this is enough for Phases 0–2**

- Movies already land (`[VOD_M3U] movies stored=18601`).
- Live-first login already works.
- Empty Movies rail is a **category/UI** bug (Phase 0), not a missing database.

**Why it may become insufficient later (document only — do not switch now)**

- Cannot serve “first 40 movies in group X” without decoding the whole file.
- Every refresh rewrites the entire JSON (blank-risk if a writer clears mem first).
- Series file is the Chromecast stall class (already proven when decoded on splash).
- No fingerprint / generation to skip no-op syncs.

**Drift/sqflite gate:** only after Phase 2 (independent jobs) + Phase 4 (windowed rails) + Phase 5–6 (non-destructive + fingerprint). If `warmM3uVodCache` / first movie row still miss the 3s budget **because of JSON**, then add Drift keyed by `streamId`. Not this turn.

### JSON cache measurement (Phase 1 — inspect only, no replace)

| Question | Finding |
|----------|---------|
| Files on this Windows dev machine? | **No.** Checked `%APPDATA%` / `%LOCALAPPDATA%` `com.quasar.tvparser`, `mbark_iptv`. Catalog lives on the Chromecast app-private dir. |
| On-device size via `adb run-as`? | **Blocked.** Installed APK is release (`run-as: package not debuggable: com.quasar.tvparser`). |
| How to read sizes on device | Debug/profile APK: `adb shell run-as com.quasar.tvparser ls -l files/m3u_cache`. Or read logcat `[CATALOG_PERF] movieJsonBytes=… seriesJsonBytes=…` (logged from `warmM3uVodCache` on every warm). |
| Chromecast count evidence (2026-08-11) | `[VOD_M3U] movies stored=18601`. Series shards up to 20 × ~5k EXTINF (~100k). File bytes unknown until next run prints `movieJsonBytes` / `seriesJsonBytes`. |
| `getM3uMovies` / `getM3uSeries` decode entire file every navigation? | **Cold yes, warm no.** `_getM3uList`: if `_*Mem` is non-null, `List.from` copy only. If mem is null, **sync** `readAsStringSync` + `jsonDecode` of the **entire** file on the caller isolate. `IpTvApi.getMovieChannels("")` for M3U always returns the full list (no LIMIT). Opening Movies tab calls `getM3uMovies().length` for FIX 4 empty-pane — mem hit after warm. |
| Fully rewritten on refresh? | **Yes.** `saveM3uMovies` / `saveM3uSeries` → `_writeM3uJson` → `jsonEncode(entire list)` + `writeAsString(..., flush: true)`. No patch, no generation swap. |
| Raw + decoded coexist? | **Yes.** During Starlite sync: raw M3U body / series `StringBuffer` + `M3uParseResult` + file JSON + `_*Mem` + dashboard `allMovies`/`allSeries` + `_movieRows` `TvStreamRecord`s + `SearchIndexEntry.item`. See E. |

---

## Phase 2 barrier actions (2026-08-11)

| # | Barrier | Action | What we do |
|---|---------|--------|------------|
| 1 | Shell `Future.wait` movies+series | **REMOVE** | Split into `_loadMovieRails` / `_loadSeriesRails` |
| 2 | `warmM3uVodCache` both files | **SPLIT** | `warmM3uMovieCache` / `warmM3uSeriesCache`; Movies path never decodes series JSON |
| 3 | SearchIndex before movie rails | **SPLIT** | Domain upsert; Movies UI never awaits index |
| 4 | One `_loadVodRailsInBackground` | **SPLIT** | Independent loaders + TMDB after each first row |
| 5 | Shared `_isMoviesRefreshing` | **SPLIT** | `_isMoviesRefreshing` vs `_isSeriesRefreshing` |
| 6 | `onVodCatalogReady` | **SPLIT** | `onMoviesCatalogReady` / `onSeriesCatalogReady` (legacy hook kept, unused by Movies UI) |
| 7 | Global `lastSyncOk` | **SPLIT** | `lastMoviesSyncOk` / `lastSeriesSyncOk` |
| 8 | Session awaits full Starlite sync | **SPLIT** | `syncMovies` + `movieFuture.then(publishMoviesReady)` |
| 9 | Sequential ingest + global ok | **SPLIT** | Independent movie/series sync + flags |
| 10 | Series all-or-nothing shards | **DEFER** | Phase 3 (chunked ingest). Series job no longer blocks Movies. |
| 11 | Apollo persist movies then series | **KEEP** | Fallback only; Movies ready already published on Starlite path |
| 12 | Search `_inFlight` / `_isReady` | **SPLIT** | `liveIndexReady` / `moviesIndexReady` / `seriesIndexReady` |
| 13–17 | Search screens `Future.wait` all types | **SPLIT** | Live+movies first; series after; search can use movies index |
| 18 | `_syncVodAfterLive` one job | **SPLIT** | Start both; return after movies; series continues |
| 19 | Splash movie+series cat fetch | **SPLIT** | Independent bloc events (series on next microtask) |
| 20 | Shared warm | **SPLIT** | Same as #2 |

**KEEP (do not touch):** Phase 0 FIX 2/3/4 movie rails; Live-first login; file JSON; no Drift; no playlist rewrite; TMDB/Gemini off login.

**DEFER (Phase 3+):** shard-1 series publish, `compute(parseCatalog)`, windowed rails, fingerprint, Drift.

---

## Coupling barriers (file:line — Phase 1 inventory; Phase 2 actions above)

| # | File:line | Kind | What Movies waits on / what is shared |
|---|-----------|------|----------------------------------------|
| 1 | `tv_dashboard_shell.dart:463–466` | `Future.wait([getMovieChannels(""), getSeriesChannels("")])` | Movies rails cannot group until **series list** returns. |
| 2 | `tv_dashboard_shell.dart:435` | Sequential `await warmM3uVodCache()` | Movies wait for **series JSON decode** (same function decodes both files). |
| 3 | `tv_dashboard_shell.dart:482–492` then `:496+` | SearchIndex then movie rails | `buildIndex` is called with **live+movies+series** before movie grouping. Call is unawaited (does not block `setState`), but Movies **cannot start indexing** until series fetch (barrier 1). |
| 4 | `tv_dashboard_shell.dart:496–726` | Common method / common setState path | One `_loadVodRailsInBackground`: movie group + movie `setState`, **then** series group + series `setState`, **then** `_enqueueVodForTmdb()` for **both**. No separate loading/ready/error/last-known-good. |
| 5 | `tv_dashboard_shell.dart:134` / `:601` | Shared `_isMoviesRefreshing` | Spinner stays true across series fetch (barrier 1). FIX 3 does **not** clear `_movieRows`. |
| 6 | `tv_dashboard_shell.dart:126`, `:729` | `onVodCatalogReady` | Hook only fires after **full** Starlite sync (barrier 8). Hydrates movie cats; may re-enter the same coupled loader. |
| 7 | `tv_dashboard_shell.dart:1117` | Global VOD boolean | Empty pane uses `vodM3u.lastSyncOk` (movies **or** series). One flag for both surfaces. |
| 8 | `iptv_provider_session.dart:168` + `:187` | Completer-like ready flag | `syncStarliteVodM3uIfNeeded` awaits `syncFromLivePlaylist` (movies **then** all series shards) then `onVodCatalogReady?.call()`. |
| 9 | `starlite_vod_m3u_session.dart:152–160` | Sequential ingest + global `lastSyncOk` | After movies persist, **awaits** `_fetchAndPersistSeries`. `lastSyncOk = lastMovieCount > 0 \|\| lastSeriesCount > 0`. |
| 10 | `starlite_vod_m3u_session.dart:181–244` | Series all-or-nothing | Concat all shards → one parse → one persist. No series-ready-after-shard-1. Holds Movies UI via 8+1. |
| 11 | `apollo_native_catalog_session.dart:266–267` | Sequential persist | `_persistMovies` then `_persistSeries` before return. Fallback path only. |
| 12 | `search_index_service.dart:48–81` | Shared `_inFlight` Completer + `_isReady` | One index for all types. `buildIndex` sets `_isReady = false`. Search will not publish Movies-only while a full (movies+series) build is in flight. Skip logic uses **combined** `incoming` count. |
| 13 | `tv_search_screen.dart:112–116` + `:154` | `Future.wait` live+movies+series, then `await buildIndex` | Search open waits on **series** catalog + full index. |
| 14 | `mobile_search_screen.dart:66–85` | same | Mobile search waits on all three + index. |
| 15 | `live_categories.dart:83–92` | same | Live search index waits on movies **and** series. |
| 16 | `mobile_watch_screen.dart:622–664` | `Future.wait` then `buildIndex` | Curation/search prefetch waits on all three. |
| 17 | `all_content_screen.dart:77–86` | same | All-content search waits on all three. |
| 18 | `iptv_provider_session.dart:192–203` `_syncVodAfterLive` | Single VOD job | Starlite movies+series, then maybe Apollo. No movies-ready mid-job. |
| 19 | `splash.dart:109–110` | Shared splash fan-out | `GetMovieCategories` + `GetSeriesCategories` together; movie cats often `[]` before VOD persist. |
| 20 | `locale.dart:129–168` `warmM3uVodCache` | Shared warm | Decodes movie JSON **then** series JSON on main before returning. |

**Not a Movies↔Series catalog barrier**

| File:line | Why excluded |
|-----------|----------------|
| `hero_content_service.dart:180` `Future.wait(futures)` | Parallel **movie detail** fetches for a hero carousel, not Movies waiting on Series ingest. |
| `channels_bloc.dart:19–28` | if/else per type — independent. |

**No** `Future.wait([rails, index])` and **no** `Future.wait([artwork, grouping])` exist. Grouping is sync on main; TMDB is after both rails (`_enqueueVodForTmdb` `:815`).

---

## Phase 2 requirement (implemented this pass — no Phase 3)

**Removing `Future.wait` is not enough.**

Movies and Series need **separate**:

- loading
- refreshing
- ready
- error
- last-known-good rows

**No global VOD boolean** (`lastSyncOk`, single `onVodCatalogReady`).

Movies must **not** wait for:

- series grouping
- series `TitleNormalizer` / `SeriesRailGrouper`
- series artwork
- series metadata
- `SearchIndexService` full rebuild
- TMDB enqueue
- “VOD complete”

Gate: Phase 0 verified on TV **and** a filled `[CATALOG_PERF]` table (`movie_first_row_ms` is the north star).

---

## G. Safe migration plan (phases 0–9)

Do **not** skip Phase 0. Do **not** start 3–9 until 0–2 are in and measured.

| Phase | Goal | Owner / status |
|-------|------|----------------|
| **0** | Movies zero-row: category fallback, do not clear `_movieRows`, empty only if raw count==0, `HydrateMovieCategories` after VOD | **Other worker** on `tv_dashboard_shell.dart`. Partial evidence already in tree (FIX 2 / FIX 3). **Do not revert.** |
| **1** | `[CATALOG_PERF]` timings/counts (this document + `CatalogPerf`) | This pass |
| **2** | Independent Movies vs Series **pipelines** (not just drop `Future.wait`) | **Done this pass.** Series shards still all-or-nothing (Phase 3). |
| **3** | Chunked ingest: `compute(parseCatalog)` per movies body / per shard; persist shard 1 series early; release `StringBuffer` | After Phase 2 |
| **4** | Paging: first-paint 24–48 `TvStreamRecord`s per visible rail; rest on scroll / isolate | After 2–3 |
| **5** | Non-destructive refresh + `generation_id` (keep showing old rows until new snapshot swaps) | After 4 |
| **6** | Playlist fingerprint diff — skip parse/persist when unchanged | After 5 |
| **7** | Incremental search in data layer (upsert by type; Search screen never full-rebuilds) | After 2 |
| **8** | Enrichment last + placeholder cards + artwork priority (already mostly true; stop normalizing 100k titles before first row) | After 4 |
| **9** | Group-hide prefs (don’t delete rows) + cancel in-flight sync + Drift **only if F still fails** | Last |

Out of scope every phase: playlist rewrite, credentials in logs, Gemini/TMDB on login, restore zip, commit unless asked.

---

## H. Estimated blast radius by phase

| Phase | Files likely touched | Risk |
|-------|----------------------|------|
| 0 | `tv_dashboard_shell.dart`, maybe `movie_caty_bloc.dart` | **High merge** — one owner |
| 1 | `catalog_perf.dart` + thin hooks in auth/session/starlite/locale/search/shell logs only | Low |
| 2 | `starlite_vod_m3u_session.dart`, `iptv_provider_session.dart`, `search_index_service.dart`, **surgical** shell wait-split (keep Phase 0 rail builders) | Medium — merge around Phase 0 |
| 3 | `m3u_parser.dart`, Starlite shard loop | Medium — parse correctness |
| 4 | shell rail builders, maybe `tv_home_rows.dart` | Medium — D-pad / “View All” counts |
| 5–6 | LocaleApi save/get, session sync | Medium — must not wipe mem |
| 7 | `search_index_service.dart`, search screens | Medium — don’t break existing tests |
| 8 | shell record builders, TMDB enqueue | Low if placeholders keep URLs |
| 9 | new Drift module + hide prefs | **High** — only with F proof |

---

## Conceptual local schema (not implemented)

```text
content            id TEXT PK, type live|movie|series, name, group_id,
                   url, logo, tvg_id, generation_id, fingerprint
groups             id TEXT PK, name, type
hidden_groups      group_id PK   -- user pref; provider row stays
playlist_meta      url_host, fingerprint, generation_id, fetched_at
search_tokens      content_id, token   -- Phase 7
```

Flutter now: the same fields live on `Channel*` + `CategoryModel` + files. Drift later copies these columns — do not invent Room entities.

---

## Phase 1 `[CATALOG_PERF]` keys live in code

| Key | Where set | Meaning |
|-----|-----------|---------|
| `app_shell_ms` | `tv_dashboard_shell.dart` Live `_loading=false` | Session → usable Live shell |
| `login_validation_ms` | `auth.dart` after `commitM3u` | Session → login user returned |
| `live_parse_ms` | `iptv_provider_session.dart` `parseCatalog` | Live M3U parse span |
| `downloadMs` / `authMs` / `parseMs` | auth + commit | Legacy aliases |
| `movie_cache_read_ms` | `locale.dart` `warmM3uVodCache` | Movie JSON+cats read |
| `movie_json_decode_ms` | warm + cold `_getM3uList` | Movie file decode |
| `movie_group_ms` | shell movie rail builder | Group/normalize/materialize span |
| **`movie_first_row_ms`** | shell first `_movieRows` setState | **North star:** `_moviesRailStartedAt` → first usable row. **Not** VOD-complete |
| `movie_first_row_from_tab_ms` | same, if Movies tab opened | Tab-open → first row |
| `series_cache_read_ms` | `warmM3uVodCache` | Series JSON+cats read |
| `series_json_decode_ms` | warm + cold `_getM3uList` | Series file decode |
| `series_group_ms` | shell series rail builder | Group/normalize/`SeriesRailGrouper` |
| `series_first_row_ms` | shell first `_seriesRows` setState | Rail start → first series row |
| `search_index_ms` | `search_index_service.dart` | `compute()` build span |
| `firstMoviePersistMs` / `firstSeriesPersistMs` | Starlite session | Persist complete (not UI) |
| `vodCatalogReadyMs` | session after **both** | Coupled — do not treat as Movies ready |
| `liveCount` `movieCount` `seriesCount` | persist / warm / UI | Raw content counts |
| `movieCategoryCount` `seriesCategoryCount` | persist / warm | Category counts |
| `movieRowCount` `seriesRowCount` | shell publish | Rails published |
| `movieJsonBytes` `seriesJsonBytes` | `warmM3uVodCache` | On-device file sizes |
| `isolate=` | every flush | `Isolate.current.debugName` (UI hooks = `main`; search build logged after `compute` returns on main) |

Disable: `--dart-define=ENABLE_CATALOG_PERF=false`. Never logs passwords or full URLs.

---

## What this pass implements vs waits

| Done here | Waits |
|-----------|--------|
| Phase 2 independent Movies/Series pipelines (A–L) | Phase 3 chunked shard ingest |
| Barrier REMOVE/SPLIT/KEEP/DEFER table | Device `movie_first_row_ms` vs `SERIES_FIRST_ROW` (needs new APK) |
| Timeline events MOVIES_* / SERIES_* | |

Related: `docs/COORDINATION_CATALOG_LOAD_ARCHITECTURE.md` (earlier recommendation). Prefer this file going forward.
