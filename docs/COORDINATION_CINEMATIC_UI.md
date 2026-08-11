# Cinematic Google TV UI — design audit & Movies slice

## HARD RULE (Quasar)

**Do NOT refactor the catalog engine while doing the visual slice.**  
Phase 0/2 already fixed the data side. Movies presentation **consumes** that data.

Do not reopen:

- `_loadMovieRails` / `_loadSeriesRails` independence
- MovieCaty hydration / fallback rails / keep-rows-on-retry
- `CategoryPresentationMapper` year collapse
- LocaleApi warm cache / `StarliteVodM3uSession` split
- SearchIndex / `CATALOG_PERF` / playlist parsing

**Also forbidden on this slice:**

- no new player (`HeroPreviewController` may wrap **existing** `video_player` / VLC tech only; do not replace `StreamPlayerPage` or add a second playback stack)
- no new focus system (evolve visuals on existing `Focus` / `AnimatedScale` only)
- no parser changes
- no replacement caching layer (keep `CachedNetworkImage`; refine `memCacheWidth` only)

If a visual change seems to require catalog surgery, **STOP** and document it instead of changing catalog code.

**Trailers:** `PlayableTrailerUrl` treating YouTube IDs as **not directly playable** is correct. Do **not** embed YouTube extraction / unofficial playback workarounds in the hero. Ken Burns / backdrop is the valid cinematic fallback. A **legitimate** trailer source (provider-hosted file, licensed API, or the existing in-app trailer dialog) may be added later **only if** a motion hero is judged important enough after Movies TV approval. Not a blocker for this slice.

**Approval gate:** Do not start Series / Live / Search / Favorites / Home / card-taxonomy until Movies is visually approved on the actual Chromecast.

---

**Status:** Audit complete (A–M). Movies vertical slice wired (presentation only).  
**Updated:** 2026-08-11  
**Source of truth:** **LOCAL** `C:\Users\Qanva\Desktop\TV Parcer\azul_iptv` — not GitHub `qanvass/tv-parser` master (stale 2025-07-25 / v2.0.3). Do not reset to GitHub. Do not copy GitHub over local.  
**Constraint:** Phase 2 catalog workers own loaders, sessions, locale warm cache. Visual slice does not touch them. No GPL code. No commit.

**Sources (license-first):** NuvioTV / Elefin / Plezy / Jellyfin Android TV READMEs + LICENSE files; Android TV Featured Carousel + Focus System docs.

## ChatGPT GitHub audit vs local (do not use remote master)

ChatGPT read `qanvass/tv-parser` **remote master** (July 25, v2.0.3). That tree is **stale**. Local already has Phase 0 empty-Movies fixes, Phase 2 independent movie/series rails, year-rail mapper, cinematic chrome pass, XMLTV, TMDB worker, and `lib/presentation/tv/cinematic/*`.

| Claim | ChatGPT (stale GitHub) | Local truth |
|---|---|---|
| Catalog coupling | Treat as one Future.wait soup | **Wrong.** Independent `_loadMovieRails` / `_loadSeriesRails`; no Future.wait Live+Movies+Series |
| Year rails | Missing / needs curation | **Already done.** `CategoryPresentationMapper` → Recently Added / Movies / Classics |
| Empty Movies | Broken | **Phase 0 kept.** Hydration + fallback rails + keep-rows-on-retry |
| Image cache | Need a new stack | **Wrong.** `cached_network_image` already (poster 280, logo 320–360, backdrop 1280) |
| Focus | Need a new D-pad framework | **Wrong.** `Focus` + `AnimatedScale` exist — evolve rim/scale only |
| Trailers | No trailer field | **Wrong.** `youtubeTrailer` on ChannelMovie / MovieDetail / SerieDetails; `TrailerLookupService`; shell already sets `trailerUrl` |
| Backdrops | Missing | **Wrong.** `ArtworkUrlResolver` already knows `backdropPath` |
| Player | Invent a preview player | **Wrong.** Wrap existing `video_player` (splash) or VLC tech. Never replace `StreamPlayerPage` |
| Rail collapse | Doesn’t exist | **Partial.** Rail already 236→92; shell only collapsed on Search — now also when focus leaves the rail |
| Movies hero | No hero | **Directionally right.** Local has `_buildVodFocusHeader` → small `TvLiveFocusHero` cyan card. That is **not** an immersive hero. Movies slice adds full-bleed `CinematicHero` |
| Cards | Replace the grid | **Don’t rip.** `TvChannelGrid` stays for Live/Series. Movies consumes the same `TvChannelRow` records via cinematic posters |
| Spotlight | Port now | **Later.** `TvLiveSpotlightCard` is a 280px Live tile with `ChannelMatchService` — not this slice |

ChatGPT was **right** that Movies still looks like title + rows (the 292px cyan panel is not Google TV), that focus chrome is thick cyan, and that Home should wait. ChatGPT was **wrong** to treat GitHub as current code or to imply catalog/player/focus rewrites.

---

## A — Current TV Parser component tree

```
TvDashboardShell                          // lib/presentation/tv/tv_dashboard_shell.dart
├── Shortcuts + Focus (Back: search→Live, content→rail)
├── Scaffold #050A18
│   ├── TvShellBackdrop                   // focused VOD backdrop / Live EPG icon
│   ├── cyan top hairline (4px)
│   └── SafeArea + 48×32 padding
│       ├── TvNavigationRail              // Live, Movies, Series, Search, Favorites, History + Settings
│       └── Column
│           ├── _Header                   // destination title + subtitle + v3002 + TvStatusClock
│           └── _buildContentPane()
│               ├── loading / movies-loading / series-loading
│               ├── _TvRetryEmptyPane     // capability-honest empty
│               ├── TvSearchScreen        // Search tab
│               └── TvChannelGrid         // Live + Movies + Series today
│                   ├── header?
│                   │   ├── Live: TvLiveFocusHero + TvStatsStrip + TvLiveCategoryChips
│                   │   │         + TvHomeRows + spotlight + Premium+ + local
│                   │   └── VOD:  TvLiveCategoryChips (Movies) + TvLiveFocusHero
│                   └── _TvStreamRow × N
│                       ├── TvRailSectionHeader
│                       └── TvChannelCard × N
```

**Supporting widgets:** `tv_channel_grid.dart` (`TvStreamRecord`, `TvChannelRow`, `TvLiveFocusHero`, `TvChannelCard`), `tv_shell_backdrop.dart`, `tv_navigation_rail.dart`, `tv_home_rows.dart`, `tv_live_category_chips.dart`, `tv_epg_peek.dart`, `tv_artwork_shimmer.dart`, `tv_branded_empty.dart`, `smart_channel_logo.dart`.

**Data into the tree:** `_liveRows` / `_movieRows` / `_seriesRows` from independent loaders; `_focusedLiveStream` / `_focusedVodStream`; `WatchingCubit` + `FavoritesCubit` (Live home rows only today); `TmdbEnrichmentWorker` + `XmlTvRepository` listenables; `CategoryPresentationMapper` already collapses year-bucket movie headings.

**This pass adds (Movies pane only):** `lib/presentation/tv/cinematic/*` and swaps the Movies **success** pane to `CinematicMoviesPage`. Loaders, Series, Live, Search, Favorites are untouched.

---

## B — Which widgets produce the old blue panels

| Surface | Widget | Why it reads as “old blue” |
|---|---|---|
| Page ground | `Scaffold` + `TvShellBackdrop` fallback | `#050A18` navy, not near-black cinema |
| Top hairline | shell `LinearGradient` `#00A3FF→#00D2FF` | neon cyan bar |
| Left rail chrome | `TvNavigationRail` | glass navy + cyan border + cyan glow slab |
| Focused nav item | `_TvNavigationButton` | filled cyan gradient, 2.4px `kColorFocus`, 22px cyan shadow |
| Destination header | `_Header` + `v3002` chip | cyan sensor icon + cyan outline badge |
| **Hero (the main offender)** | `TvLiveFocusHero` | **fixed ~286–292px rounded navy card**, cyan top hairline, 5px cyan left bar, 1.6px cyan border, cyan glow — a small blue rectangle, not an immersive hero |
| Live/VOD cards | `TvChannelCard` | `#121C2C` fill, **2.8px cyan focus box**, cyan glow, 36px title slab under art |
| Section chrome | `TvRailSectionHeader` uses `kColorPrimary` | cyan accent bar |
| Stats / chips / clock | Live-only widgets | cyan tokens (`kColorPrimary` / `kColorFocus`) |

**Movies slice target:** stop using `TvLiveFocusHero` + thick-cyan `TvChannelCard` on the Movies pane. Live/Series keep current chrome this pass.

---

## C — Hero today

`TvLiveFocusHero` (`tv_channel_grid.dart`):

- **Not full-bleed.** Clipped 22-radius card, ~292px tall, sits under `_Header` inside padded content.
- **No backdrop image inside the card.** Left/right navy gradient only. Actual backdrop is the separate `TvShellBackdrop` behind the whole scaffold (dim, not a hero stage).
- **VOD right slot** is a 2:3 poster (`_VodHeroPoster`), not a clearLogo.
- **Live right slot** is `_ClearLogo` = channel `imageUrl` via `SmartChannelLogo` (contain). Naming is misleading — it is a channel logo, not a movie clearLogo.
- Metadata: XMLTV now/next for Live; TMDB extra overlays year/rating/runtime/overview/trailer **if** a high-confidence hit exists.
- Trailer CTA is a non-focusable `_GlassPill` shown only when `extra.trailerUrl ?? rec.trailerUrl` is non-empty. It does **not** play a preview.
- Focused poster updates `_focusedVodStream` immediately (no art debounce, no trailer debounce).
- No Ken Burns. No muted preview. No stadium CTAs.

Android TV **immersive featured carousel** (official): full-bleed backdrop + cinematic scrim + content block (overline, title, description, buttons) + rows below. TV Parser Movies should match that anatomy, not the card variant.

---

## D — Player usable for muted preview?

| Player | Where | Usable as hero preview? |
|---|---|---|
| `video_player` ^2.10.1 | Splash asset (`VideoPlayerController.asset`) | **Yes, for direct HTTP(S) video** (`networkUrl` + `setVolume(0)` + loop). Already a dependency. |
| `flutter_vlc_player_16kb` | Full-screen Live/VOD (`StreamPlayerPage`) | **Do not reuse the page.** Wrapping a second VLC session on browse would fight the full player. Preview wraps existing `video_player` only. |
| YouTube ID / `youtu.be` / watch URL | `ChannelMovie.youtubeTrailer`, `TrailerLookupService` | **Not playable** by `video_player` without an extractor. **Do not invent** a YouTube scrape/search (`youtube_trailer_search_service` is mobile-only and out of scope). |

**Rule for this slice:** `HeroPreviewController` (exactly one) plays a muted/sound preview **only** when `PlayableTrailerUrl.resolve` returns a real `http(s)` URL with a video extension (`mp4` / `m3u8` / `webm` / `mov` / `mkv`). YouTube IDs, search URLs, and empty fields → no trailer; Ken Burns on still art instead.

TMDB enrichment today **passes through** `provider.trailerUrl` and does **not** call TMDB `/videos`. So a “TMDB trailer URL” only exists if the provider already supplied a playable URL, or a future enrichment job adds one. Never fabricate.

---

## E — Artwork types supported

| Kind | Source today | Movies slice |
|---|---|---|
| **poster** | M3U `tvg-logo` / `stream_icon` via `ArtworkUrlResolver.resolveVodPoster`; optional TMDB `w500` | First-class. Card + hero fallback. |
| **backdrop** | Resolver prefers explicit backdrop, else poster; TMDB `w1280` when worker hits | First-class. Hero stage. Crossfade. |
| **clearLogo** | **Not in** `UnifiedMediaMetadata` / `TvStreamRecord` / TMDB client | First-class field, almost always null. Hero title = clearLogo **if URL exists**, else text. Never block. |
| **channelLogo** | Live `tvg-logo` + Starlite `{tvg-id}.png` | First-class on the model; unused on Movies cards this pass. |
| **episodeStill** | Not on movie list rows | First-class on the model; unused on Movies. |
| **trailer** | `ChannelMovie.youtubeTrailer` (usually a YouTube id) + pass-through on TMDB extra | First-class. Play only if `PlayableTrailerUrl` accepts it. |

`ArtworkUrlResolver.isUsableImageUrl` = non-empty `http(s)`. Missing art → shimmer / gradient / title text. **Never invent** logos, stills, or trailers. **Never block** first paint on enrichment.

---

## F — Trailer metadata availability

- Xtream / native VOD list: `youtube_trailer` / `youtubeTrailer` / `trailer` / `youtube_id` on `ChannelMovie`.
- Shell copies that onto `TvStreamRecord.trailerUrl`.
- `TmdbClient` search map has **no** `trailer_url` from TMDB videos API.
- `MediaMetadataEnrichmentService` sets `trailerUrl: provider?.trailerUrl` only.
- `TrailerLookupService.getSearchFallbackUrl` builds a YouTube **search** link — **forbidden** for hero preview (invented).
- Honest outcome: most catalog rows will **not** preview. That is correct.

---

## G — Channel-logo availability

- Live: `tvg-logo` / `stream_icon`, else `https://media.starlite.best/{tvg-id}.png`.
- `SmartChannelLogo` + initials fallback (TV cards currently hide initials).
- Movies list rows do **not** carry a separate channel logo. Do not draw Live logo chrome on movie posters.
- Live logo-card redesign is **not** this slice.

---

## H — Focus system

- Shell: `OrderedTraversalPolicy` + per-destination `FocusNode`s (`TvNavPrimary*`, Settings, Retry).
- Back: Search → Live; content → selected rail item; rail + Back → system (leave app).
- Cards: `Focus` + `onKeyEvent` for Select/Enter/A/Space; `Scrollable.ensureVisible(alignment: 0.28)`.
- Rail collapse today: **Search only** (`_railCollapsed = index == search`). Movies/Live/Series stay expanded.
- Official TV focus (Android): default / focused / pressed; indicators via **scale (1.025–1.1)**, border, glow, color. Directional D-pad. Always one obvious focused element.

**Gaps vs Google TV:** rail does not icon-collapse when content is focused; focus chrome is a thick cyan box (not 1.06–1.10 soft scale); no pivot (focused card does not hold a stable X).

**Movies slice:** Movies-only icon-collapse when focus enters content; expand when focus returns to the rail. Soft luminous focus. Pivot row scroll with stable keys. Live/Series follow-up (do not change their focus chrome this pass).

---

## I — Animation system

No shared motion tokens today. Ad-hoc durations:

| Location | Duration |
|---|---|
| Rail width | 220ms |
| Backdrop switch | 420ms (+ image fade 280ms) |
| Card scale / border | 150ms |
| `ensureVisible` | 180ms |
| Nav button | 160ms |
| Hero glass pill | 150ms |

**Motion tokens (this pass — use everywhere in `cinematic/`):**

| Token | Duration | Use |
|---|---|---|
| `focus` | 180ms | scale, border, button fill |
| `backdrop` | 350ms | still-art crossfade |
| `heroText` | 250ms | title / logo / meta |
| `navCollapse` | 220ms | rail width (already matches rail) |
| `previewFade` | 300ms | trailer fade **after first decoded frame** |

Low-power / `MediaQuery.disableAnimations`: skip Ken Burns **and** trailer.

---

## J — Image cache stack

- `cached_network_image` ^3.4.1 + Flutter cache manager (default).
- `memCacheWidth`: backdrop 1280, posters 280, logos 320–360.
- Shimmer: `TvArtworkShimmer`.
- No Coil/Glide (Flutter). Do not add a second image stack.
- Decode at card size; do not decode 4K backdrops into 2:3 posters.

---

## K — Nuvio / Elefin / Plezy patterns worth recreating (**patterns only**)

Clean-room. No source copied.

1. **Immersive hero stage** — backdrop is the page, not a card; L→R + bottom scrim for type (Android TV immersive carousel).
2. **Focus-driven hero** — the focused shelf item is the hero subject; art updates on a short debounce; video preview on a longer dwell.
3. **clearLogo over title** — wordmark when the provider/TMDB actually has a logo asset; otherwise large type. Never block.
4. **2:3 posters, thin focus** — scale ~1.08, hairline / soft glow, not a 3px neon frame.
5. **Continue / My List as first-class actions** — stadium CTAs; list state from real favorites, not a fake button.
6. **Icon rail while browsing** — labels appear when the rail is the focus region.
7. **Pivot shelves** — the focused poster holds a stable X; the row translates under it.
8. **Glass as chrome, not wallpaper** — buttons, chips, focused nav, badges only.
9. **One preview decoder** — cancel on focus change; never a second Exo/VLC instance on the browse surface.
10. **Home is a composition of real rails** (Continue, Favorites, because-you-watched) — **assess only** (section M). Not this slice.

---

## L — License status (verified 2026-08-11)

| Project | License file | Class | Use |
|---|---|---|---|
| [NuvioMedia/NuvioTV](https://github.com/NuvioMedia/NuvioTV) | **GPL-3.0** (README license badge + gnu.org link) | **Red** | Study only. No code, layouts, or assets. |
| [flex36ty/elefin](https://github.com/flex36ty/elefin) | **GPL-3.0** (`LICENSE` header: “Copyright (C) 2025 Elefin”). GitHub UI may show `NOASSERTION`; the file is GPL-3. | **Red** | Study only. Compose-for-TV Jellyfin client, not Flutter. |
| [edde746/plezy](https://github.com/edde746/plezy) | **GPL-3.0** (`LICENSE` = GNU GPL v3) | **Red** | Study only. Flutter Plex/Jellyfin client — closest stack, still copyleft. |
| [jellyfin/jellyfin-androidtv](https://github.com/jellyfin/jellyfin-androidtv) | **GPL-2.0** | **Red** | Study only. Leanback rows / resume / cards. |
| Android TV Featured Carousel + Focus System | Google developer docs | **Green** (docs) | Anatomy + focus numbers. Flutter reimplementation. |

**Rollback:** delete `lib/presentation/tv/cinematic/` and revert the Movies-pane branch in `tv_dashboard_shell.dart` / settings stub / rail `chrome` parameter. Catalog loaders stay intact.

---

## Design tokens (required before more screens)

Single palette for cinematic widgets. Stop mixing `#050A18` / `#050A12` / `#121C2C` / `#00A3FF` / `#00D2FF` inside the new Movies chrome.

| Token | Value | Role |
|---|---|---|
| `background` | `#0B0B0E` | Page / hero fallthrough |
| `surface` | `#16161C` | Unused as a content “panel”; chips unfocused track |
| `focus` | `#F2F2F5` | Luminous focus hairline (not cyan) |
| `textPrimary` | `#F7F7F8` | Titles |
| `textSecondary` | `#B8B8C0` | Meta |
| `accent` | `#E8ECF0` | Quiet highlight (Watch fill) |
| `danger` / live | `#E11D2E` | Live badge only (not Movies) |
| `radius` | 10 / 14 / 999 | poster / chip / stadium |
| `spacing` | 8 / 12 / 16 / 24 / 32 | |
| `focusScale` | **1.08** | Posters (range 1.06–1.10) |
| `animationDuration` | 180ms | Default focus |

Glass fill: `white @ 10–14%` + 1px `white @ 22%` border. **Only** on stadium buttons, chips, focused nav item, badges.

---

## M — Staged plan (Home = assess only)

| Stage | Scope | This pass |
|---|---|---|
| **0. Tokens** | `CinematicTokens` + `CinematicMotion` | **Yes** |
| **1. Movies** | Full-bleed hero, focus-driven art, Ken Burns, optional real trailer, 2:3 posters, Continue Watching, year rails already collapsed by mapper, settings OFF / MUTED / SOUND, Movies-only rail collapse, pivot rows | **Yes** |
| **2. Series** | Reuse cinematic page with series records + episode grouping | No — wait for Series import / Phase 2 |
| **3. Live** | Program backdrop hero, channel-logo cards, now/next — keep `TvLiveFocusHero` until then | No |
| **4. Search** | Same poster language; keep Android TV IME | No |
| **5. Favorites** | Same cards + real cubit | No |
| **6. Details** | Backdrop + Play + Trailer iff real URL | No |
| **Home** | **Assess only.** Today `TvHomeRows` is bolted onto **Live** (Continue mixes movies+series as landscape tiles, Favorites, Recent Live). A real Home would be its own destination: pinned immersive hero, Continue (typed), Because you watched, Favorites, jump tiles — composed from cubits **without** waiting for full catalog. Do **not** implement Home now. Risk: a sixth rail item vs replacing Live-as-home. Decide after Movies + Series cinematic panes exist. |

**Explicitly out of this slice:** Home screen, full Live live-preview, Search/Favorites redesign, Details rebuild, playlist parsing, Phase 2 catalog loaders, year-rail mapper changes, Series UI.

---

## Movies slice — acceptance

- Opening Movies never waits on Series (Phase 2 invariant).
- Hero is full-bleed in the Movies content pane (not a 292px cyan card).
- Focused poster updates hero art **immediately**; preview may start after **1100ms** iff a playable URL exists.
- One `HeroPreviewController`; cancelled on focus change.
- Posters 2:3, scale 1.08, no thick cyan boxes.
- Continue Watching only if `WatchingCubit.state.movies` is non-empty.
- Year rails: consume already-presented `_movieRows`; do not re-curate or block.
- Settings Playback: Hero preview **Off / On (muted) / On with sound** (default muted).
- `disableAnimations` → no Ken Burns, no trailer.
- Missing poster/backdrop/clearLogo never blocks the row.
- Analyzer clean on new cinematic files.

---

## Manual TV check (Movies only)

1. Rail → Movies. Rows appear from existing loader (fallback rails OK).
2. Right into content: rail collapses to icons; hero fills the pane.
3. Move across posters: hero title/meta crossfade; backdrop crossfades; no cyan card.
4. Dwell on a title with a real mp4/m3u8 trailer: muted preview after ~1s; move away → preview stops.
5. YouTube-only trailer field: still art + Ken Burns (unless low-power), never a search URL.
6. Continue Watching appears only with real movie progress.
7. Left / Back: rail expands, focus on Movies.
8. Live and Series still use the previous chrome.

---

## Remaining visual-approval items (not blocking this slice)

- Rail focus chrome on Live/Series is still cyan slabs (Movies inherits the same rail widget; collapse is wired, luminous restyle is follow-up).
- `clearLogo` has no provider/TMDB field yet — hero uses title text. Do not invent logos.
- Most `youtubeTrailer` values are YouTube ids → Ken Burns, not motion preview. Honest.
- Continue Watching cards are still 2:3 (same poster card). A 16:9 CW type on `TvChannelCard` is follow-up — do not rip the grid this pass.
- Series / Live / Search / Favorites / Details / Home: not this slice.
- Device proof (Chromecast): install + sign-in only when an APK is flashed; login from `.secrets/tv_login_runtime.env` (never log URL/password).

---

## Watch My Playlist — audit only (2026-08-11)

**Do not rename this pass.**

| Question | Finding |
|---|---|
| Is there a Dart string `Watch My Playlist`? | **No** — not in `lib/` |
| Is it a Starlite movie `group-title`? | **No.** 109 groups, all `Movies YYYY` year buckets |
| Mapper shelves? | `Recently Added` / `Movies` / `Classics` only (named leftovers if any) |
| What is **All**? | First **chip** on `CinematicMoviesPage` (`null` filter = show every shelf). Not a data row |
| What would a “playlist dump” row be? | The year-collapsed catalog itself (Recently Added = ≥2020, etc.), **not** a user-built playlist |

If a later pass adds a featured dump row and the label is action-like and confusing, prefer **Featured** / **From Your Library** / **Your Movies**. Not this pass.

---

## Artwork investigation (2026-08-11) — placeholders are emergency only

Starlite `/m3u8/movies` sample (40 rows, plus forced Deb Is Boss) and full EXTINF census (18601):

| Field | Present? |
|---|---|
| `tvg-logo` / `stream_icon` / `movie_image` / `cover` / `poster` / `backdrop` | **0 / 18601** |
| `tvg-id` + `tvg-name` | **18601 / 18601** — both are IMDb `tt…` ids, **not** image URLs |
| `tvg-type` | `movies` |
| `group-title` | year buckets only |
| Extra custom art attributes | **none** |
| `media.starlite.best/{tt}.png` HEAD | **12/12 = 404** (not provider poster) |
| Title+year normalizable (`Title (YYYY)`) | **40 / 40** sample |

**Deb Is Boss (2026):** `tvg-id=tt27545912`, no logo/backdrop/trailer fields. Stream path shape `…/movie/<id>` only (no query logged). No playable trailer metadata.

`ArtworkUrlResolver` cannot invent a poster from title. `TmdbEnrichmentWorker` is the existing title+year path — **off on this machine/APK because there is no API key** (see below). TVmaze is flag-off and HTTP-unwired. TrailerLookupService only extracts YouTube ids (not playable in hero).

**This pass (emergency presentation):** title-hashed `CinematicTitlePlaceholder` + Ken Burns so cards/hero are never blank black. **That is not the desired library look.** Real posters require turning on the **existing** TMDB worker later — do not add a second provider, do not scan 18k titles on Movies open.

### Milestone

1. **Functional visual fallback approved** — zero blank cards, zero empty-black hero, selected title always has motion. Emergency title-hashed placeholders **stay** for unmatched.
2. **TMDB structural path ready (2026-08-11)** — IMDb id is preserved on `ChannelMovie.imdbId`; existing `TmdbClient` has `findMovieByImdbId` + IMDb-first match order. Private Chromecast bake may dart-define a key; public APK must not.
3. **Poster UI miss (2026-08-11)** — `/find` works (including Deb Is Boss). Cards looked up `cacheKey(rawNameWithYear)` while enqueue wrote `cacheKey(displayTitle)` without year. Fixed: same title+year on both sides; miss TTL 20m.
3. **After Quasar places a key** — **private Chromecast/dev build only** (see key architecture below). First **8 × 24** hydrate in the background; placeholders remain until a hit. Do **not** change `TmdbClient` / IMDb preserve further until that test.

**Private Chromecast acceptance (next build — do not start without key + Wireless debugging):**

- Movies rows appear immediately, even before enrichment finishes.
- Real posters progressively replace generated placeholders.
- Hero upgrades from fallback to real backdrop/poster as metadata arrives.
- Exact IMDb matches preferred; title/year only as fallback.
- No all-18k scan.
- D-pad stays responsive.
- Re-entering Movies uses cache instead of refetching everything.
- Full movie playback remains unchanged.

If those pass: TMDB is the working **short-term** artwork solution. Fanart.tv stays Plan B / richer-art later — do not wire it for this test.

### Locked sequence (Quasar 2026-08-11 — do not skip)

1. **NOW** — TMDB diagnostic: prove 1 real poster end-to-end → hero upgrades → progressive replacement → first ~192 bounded items. No HotPlayer work.
2. **THEN** — freeze Movies metadata/art path.
3. **NEXT** — HotPlayer Phase 1 only after freeze: appliance Live + sort + incremental search + real parental PIN. **Not started.**
4. **AFTER THAT** — Phase 2: Live cinematic/nav + Guide.
5. **THEN** — Series windowing/performance **before** Series visual work.

---

## TMDB — existing switch (do not invent a provider)

**Why it is off right now:** **no API key.** `ENABLE_TMDB` defaults **true**. There is no in-app settings toggle. Not a network/auth failure (worker never starts without a key). Not a deliberate “architecture off” flag — the client is built and the shell already calls `_enqueueMovieTmdb()`; `TmdbClient.isEnabled` is false until a key exists. Structural IMDb `/find` is wired; it is a no-op without a key.

### Key architecture — public APK must NOT depend on a baked TMDB secret

**Do NOT make the public release APK permanently depend on a TMDB key baked into the client.** Anything in a distributed APK can be extracted.

Goals are **separate**:

| When | What |
|---|---|
| **NOW (this task)** | IMDb preservation + `TmdbClient.findMovieByImdbId` + unit tests. **No key required.** No live TMDB. Enrichment stays off. |
| **NEXT (after Quasar supplies a key)** | Bake `TMDB_API_KEY` into a **PRIVATE Chromecast/dev build only**, to validate ~192 visible/initial items progressively. That bake is a **development test**, not the product architecture. |
| **BEFORE PUBLIC RELEASE** | **Plan B** — TV Parser app → our metadata endpoint → TMDB/Fanart/cache. Upstream credentials stay **server-side**. Clients get normalized metadata, not the provider credential. |

Do **not** implement the cloud metadata service in this pass. Do **not** bake any key in this pass. Do **not** add a production dart-define default that ships a secret. `TMDB_API_KEY` compile-time default remains empty.

**Phase 1 inspect (2026-08-11) — key hunt (presence only, never logged):**

| Source | Result |
|---|---|
| `C:\Users\Qanva\Desktop\TV Parcer\.secrets\tmdb.json` | **MISSING** |
| `azul_iptv/.secrets/tmdb.json` | **MISSING** |
| `.secrets/*.env` `TMDB_API_KEY` | **MISSING** |
| User / Process / Machine env `TMDB_API_KEY` | **MISSING** |

**Quasar must place the key** in gitignored `C:\Users\Qanva\Desktop\TV Parcer\.secrets\tmdb.json` as `{"api_key":"..."}` **or** pass `--dart-define=TMDB_API_KEY=***` at **private/dev build** time. Do not invent a key. Do not enable a public store APK this way.

**A device APK cannot read the desktop `.secrets` file.** A private Chromecast/dev bake must dart-define the key. Desktop `.secrets` is only useful for debug/desktop runs (`TmdbClient` already reads `.secrets/tmdb.json`, `azul_iptv/.secrets/tmdb.json`, `../.secrets/tmdb.json`). Public release waits for Plan B — do not ship that define.

**Gitignore:** already covered — workspace `.secrets/` and `azul_iptv/.secrets/` (plus `*.env`). Never commit the key.

**Private Chromecast/dev bake only (after key exists — not Play/public):**

```
--dart-define=ENABLE_TMDB=true
--dart-define=TMDB_API_KEY=***
flutter build apk --release --target-platform android-arm,android-arm64
```

PowerShell must read `.secrets/tmdb.json` into a variable and pass it — never `echo` / log the define value. Refer to it as `TMDB_API_KEY=***`. This APK is a **dev test device** build. Public store builds wait for Plan B.

| Piece | Where |
|---|---|
| Feature flag | `--dart-define=ENABLE_TMDB=true` (default **true**) in `lib/repository/provider/tmdb_client.dart` |
| Key (pick one) | `--dart-define=TMDB_API_KEY=***` **or** gitignored `.secrets/tmdb.json` with `{"api_key":"..."}` |
| Worker | `TmdbEnrichmentWorker` — `_enqueueMovieTmdb()` first 8 rails × 24 titles, 280ms sequential pump. **No** full-catalog startup job |
| Cache | `m3u_cache/tmdb_enrichment.json` via `TmdbMetadataCache` — positive hits persisted; misses stored (`miss: true`) with **no TTL today** (repeat nav does not refetch) |
| Images | `ArtworkUrlResolver.tmdbPoster` / `tmdbBackdrop` |

### Required match order (wired 2026-08-11 — still no-op without a key)

When a valid IMDb `tt…` is present (`ChannelMovie.imdbId` from `tvg-id` / `tvg-name`):

1. Exact TMDB `/3/find/{imdbId}?external_source=imdb_id&language=en-US` via existing `TmdbClient.findMovieByImdbId` (not a new pipeline)
2. Accept **movie_results** only. Reject `tv_results` / `person_results` / episode results as movie matches
3. Cache TMDB id + poster/backdrop/trailer metadata
4. Only if IMDb lookup fails or returns no movie: normalized title + year (`search/movie`, high-confidence exact title)
5. Only if that fails: keep emergency title-hashed placeholder

Do **not** fuzzy-match if exact IMDb succeeds. Safe log tag `[TMDB_MATCH]` only when a call would happen: `matchMethod=imdb|title_year|none` + `hasPoster` / `hasBackdrop` / `hasTrailer`. No key, no full URLs, no credentials.

### Inspect answers

| # | Finding |
|---|---|
| Matching today | **IMDb `/find` first** (movie only), then title + year. `TmdbMatch.isHighConfidence` still gates title search. No fuzzy after a successful IMDb hit. |
| IMDb `/find` | **YES.** `TmdbClient.findMovieByImdbId` → `/3/find/{id}?external_source=imdb_id`. Movie results only. Still no-op when `isEnabled` is false. |
| Starlite `tt…` reach enqueue? | **YES now.** Parser still reads `tvg-id`; `ChannelMovie.imdbId` keeps a validated `tt…` (malformed → null). `_movieStreamRecord` copies it to `TvStreamRecord.imdbId` / `tvgId`. `_tmdbRequest` sets `TmdbEnqueueRequest.imdbId`. LocaleApi JSON: optional `imdb_id` (old cache without the key still loads). |
| Positive cache | **Yes.** `putHit` → disk `tmdb_enrichment.json`. `enqueue` / `prioritize` skip `has(key)`. |
| Negative cache | **Yes, permanent today** (`{'miss': true}`). Repeat nav does not refetch. No TTL — add a short TTL when enabling so unmatched can retry after IMDb wiring. |
| Priority | `enqueueMany` = row order, first 8 × 24. Focus calls `prioritize()` (hero selected). Initial cinematic hero is **not** auto-prioritized on first frame (only on focus). Adjust presentation hook only when enabling. Near-visible = rest of those 192. No background scan of remaining ~18k. |
| Concurrency | **Bounded to 1.** Sequential pump + 280ms delay. No parallel flood. |
| Full-catalog job | **None.** Movies open is not blocked on TMDB. |
| Trailers | `TrailerLookupService` extracts YouTube ids from provider fields only. TMDB videos endpoint **not** called. |

### Product question

**Can the existing TMDB path turn 18601 text-only records into real artwork progressively via IMDb IDs?**

**Yes — progressively, not all at once.** Gaps (2) and (3) are fixed in code. Remaining: Quasar places `TMDB_API_KEY=***` for a **private Chromecast/dev bake only** (not a public Play APK). Then first rails (~192) hydrate in the background, placeholders remain until a hit, cache prevents refetch, unmatched stay on emergency art. **Do not** scan all 18601 on Movies open. Public store builds wait for Plan B (app → our metadata endpoint → TMDB/Fanart/cache).

**This pass:** structural IMDb preserve + `/find` + mocked unit tests. No key, no live TMDB, no enablement, no public-APK secret, no cloud metadata service, no 3006 build.
