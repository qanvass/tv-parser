# TV UI richness plan

**Status:** Phase 1 in progress (XMLTV + hero/now-next + portrait VOD)  
**Updated:** 2026-08-11  
**Sources:** UI stack audit + Android TV / IPTV patterns scout  
**Constraint:** Never invent titles, artwork, schedules, or trailers. Live-first startup (no splash block on VOD/EPG). Neutral media player language only.

## Verdict

TV Parser already has the right **shell** (left nav, Live hero, rails, Movies/Series from Starlite VOD M3U). Do **not** port foreign apps. Fill data pipes and upgrade chrome in place.

**Ease × impact order:** XMLTV → Live hero/now-next → Guide + portrait VOD → optional TMDB trailers.

## What we already have

- TV shell: Live / Movies / Series / Search / Favorites / History + D-pad rail (`tv_dashboard_shell.dart`)
- Live logos: M3U `tvg-logo` + `media.starlite.best/{tvg-id}.png`
- Starlite VOD M3U catalogs (~18k movies + series shards); capability tiers; honest empty states
- Stubs: `EpgChannelMatcher`, TMDB, TVmaze; `TvEpgPeek` (Xtream only today)
- XMLTV URL known: `https://epg.starlite.best/utc.xml.gz` (stored on capabilities)
- Freeze fix path: Live warm first; VOD deferred (install verify when ADB up)
- Study assets (do not ship): `IPTV UI UX TEMPLATES/`, `store_release_package/qa_startupshow_ux/`

## Gaps vs Startup Show / TiViMate-class UI

| Pattern | Today |
|---------|--------|
| Program/backdrop Live hero | Channel name + logo only |
| Now/next on M3U | Empty (`getEPGbyStreamId` returns `[]`) |
| Guide rail | Missing |
| Portrait VOD posters + Movies hero | Landscape Live tiles for everything |
| Trailer on TV browse | Only if provider field exists on non-TV detail paths |
| Rich VOD art | Weak until TMDB (flag) or native Startup Show session |

## Adapt vs study-only

| Project | License | Use |
|---------|---------|-----|
| clubTivi (Flutter) | Apache-2.0 | **Adapt** XMLTV matching + guide concepts (clean-room) |
| Ultra TV (Compose) | MIT | **Patterns only** — Live panes, guide window, focus scale |
| fluttercandies/dpad | MIT | Optional Phase 3 focus memory |
| StreamVault / Nuvio / GPLv3 IPTV apps | Red | Study only — no code |

## Metadata priority

**Live:** provider logos → XMLTV → never invent  
**VOD:** provider poster/plot → TMDB (flag + attribution) → TVmaze (flag) → title-only  

Hide Trailer / synopsis chrome when empty. No scraping of TMDB/IMDb/YouTube HTML.

## Phases

### Phase 1 — Easiest wins (do first)
1. XMLTV download/gunzip → disk cache; flag `ENABLE_XMLTV_EPG`
2. Wire `EpgChannelMatcher` (tvg-id → normalized → callsign → name+country → manual)
3. Fill `TvEpgPeek` + Live card secondary line for M3U
4. Upgrade `TvLiveFocusHero`: programme title when matched; channel name secondary
5. Portrait `TvChannelCard` for Movies/Series; provider-art Movies/Series focus hero

**Accept:** Focused Live shows real now-title when XMLTV matches; splash still Live-first.

### Phase 2 — Structure
1. Guide left-nav: channel × time (~6–12h), virtualized, D-pad safe
2. TV-safe movie/series detail: backdrop, Play, Trailer **iff** real URL
3. Continue Watching / Favorites fed by real progress only

**Accept:** Guide usable with Starlite XMLTV; Back doesn’t kill Live.

### Phase 3 — Polish (later)
1. Wire TMDB/TVmaze HTTP behind flags + About attribution (legal OK first)
2. Optional MIT `dpad` focus regions
3. Subtle focus scale; overscan-safe; no glow spam

## Injection map

| Goal | Files |
|------|--------|
| Live hero | `tv_channel_grid.dart` (`TvLiveFocusHero`) + shell focus |
| Now/next | `tv_epg_peek.dart`, `iptv.dart` M3U EPG path, `epg_channel_matcher.dart` |
| Guide | `tv_dashboard_shell.dart`, `tv_navigation_rail.dart` + new EPG repo |
| Portrait VOD | `TvChannelCard` + `_loadVodRailsInBackground` |
| Trailers | provider `youtubeTrailer` / flagged TMDB after first paint |

## Pending

- [x] Phase 1 implementation started 2026-08-11 (XMLTV ingest + hero/now-next + portrait VOD)
- [x] User reference pack / mockup style tokens applied (cyan glass, no invented catalog)
- [ ] Chromecast install of cinematic APK (pair/connect refused 2026-08-11 02:35)

## Do not

- Copy Startup Show / template PNGs into the APK
- Block splash on full catalog or XMLTV parse
- Invent metadata on low-confidence matches
- Bundle third-party channel lists or “free TV” framing
