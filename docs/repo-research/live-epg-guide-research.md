# Research — cinematic Live TV + EPG + TV Guide

**Goal:** Give TV Parser Live the cinematic pattern: focus hero with **program** title + art, channel cards with now/next, and a real **TV Guide** screen — without rewriting Flutter or copying Red-license code.

## Capability tier gate (product)
Do **not** treat M3U-only as the final product ceiling. Until detection completes, M3U is the **minimum** tier. Probe XMLTV, Xtream short/full EPG, VOD, series, and artwork endpoints; enrich authorized catalogs via TMDB (+ optional TVmaze) without inventing fields. UI degrades by detected capabilities. Coordination: `docs/COORDINATION_PROVIDER_CAPABILITIES.md`.

| Tier | EPG / VOD expectation |
|------|------------------------|
| M3U minimum | Live playlist; Guide empty until XMLTV/user URL |
| M3U + XMLTV | Programme guide via XMLTV match order below |
| Xtream-compatible | `get_short_epg` (+ full when available); VOD/series APIs |
| Full / hybrid | Short EPG + XMLTV + optional TMDB art for VOD |

## TV Parser baseline
See `docs/tv-parser-baseline.md`. Critical gap: M3U EPG is intentionally empty; no Guide destination; hero is channel-centric. Capability inspector + EPG matcher stubs are in `lib/repository/provider/`.

## Candidates

| Repository | Activity | Stack | License | Strongest relevant feature | Risk into Flutter TV Parser | Rec |
|------------|----------|-------|---------|----------------------------|-----------------------------|-----|
| [ultra-tv](https://github.com/khalilbenaz/ultra-tv) | Active 2026, MIT | Kotlin Compose-TV / also web notes | **Green (MIT)** | Native TV focus, Xtream+M3U+EPG in Room | High if ported wholesale; low if **patterns only** | **Adapt** (primary UX/arch reference) |
| [StreamVault-IPTV](https://github.com/Davidona/StreamVault-IPTV) | Verify each run | Kotlin Compose, Media3 | Often **Red/Yellow** (noncommercial / source-available — re-check) | EPG, catch-up, multiview concepts | License blocks copy | **Study only** until Green |
| [FireVisionIPTV](https://github.com/akshaynikhare/FireVisionIPTV) | Verify | Android TV / Fire TV | Verify | M3U + EPG health / pairing ideas | Stack mismatch | **Study** pairing/sync ideas |
| [NuvioTV](https://github.com/NuvioMedia/NuvioTV) | Verify | Kotlin TV UI | Often **Red (GPL)** | Cinematic browse / detail | GPL → no code copy | **Study only** (UI inspiration) |
| [xtream_code_client](https://pub.dev/packages/xtream_code_client) (pub) | Pub package | Dart | Check package license | XMLTV/`EPG.fromXmlElement` helpers | Medium — may overlap our Dio models | **Adapt** carefully if MIT/BSD |
| [iptv-org/epg](https://github.com/iptv-org/epg) | Active | Node grabbers | Unlicense/MIT family (verify) | XMLTV generation tooling | Not an app; fixture/ops only | **Study** (fixtures, not ship grabber) |
| Startup Show (device) | Closed | Proprietary | N/A | Live tiles with now/next; Guide nav | No code reuse | **Study** UX only |

## Decision (updated after full scout)
**Primary reference:** [clubTivi](https://github.com/clubanderson/clubTivi) (**Adapt**, Apache-2.0) — Flutter XMLTV ingest, 4-tier `tvg-id` matching, timeline guide, D-pad.  
**Secondary UX:** Ultra TV (**Adapt** patterns only, MIT) — cinematic Live 3-pane + 12h guide layout.  
**Implementation:** original Dart (`EpgRepository` + Guide UI) behind a flag.  
**Do not** port Kotlin apps or copy GPL/noncommercial sources (StreamVault, Nuvio, OwnTV, iptvs).

**Also:** `package:xml` for streaming XMLTV; Startup Show screenshots + `iptv idea template2.png` for visual direction (no asset copy).

Scout detail: subagent [Scout Live TV EPG OSS repos](5b6cb4ad-bed9-42ae-a203-f3d27fd10849).

## Patterns to extract (original Dart)

1. **tvg-id ↔ EPG channel id matching** (most common “empty guide” failure mode).
2. **Now/next calculation** from programme start/stop + timezone normalize.
3. **Lazy guide grid** (virtualized rows × time columns) for 2k+ channels.
4. **Hero sync to focus** — programme title/desc/icon when EPG hit; else channel logo fallback.
5. **Provider adapter boundary** — Xtream short EPG vs XMLTV URL vs future authorized livetv info API.

## EPG matching order (implemented stub)

`EpgChannelMatcher` priority:

1. Exact `tvg-id`
2. Normalized channel ID
3. Callsign
4. Channel name + country
5. Manual user mapping (in-memory persist stub)

## Attribution
- Ultra TV: MIT — preserve copyright if any file is adapted; prefer clean-room Dart.
- Do not vendor GPL/noncommercial sources into the APK.

## Acceptance criteria (measurable)
- [ ] Focused Live card shows **now title** when EPG matched (not only channel name).
- [ ] Hero shows program title + optional icon/backdrop; channel name secondary.
- [ ] `TvEpgPeek` works for M3U when XMLTV (or provider EPG) configured.
- [ ] New **TV Guide** rail destination: D-pad navigable channel×time grid for current window.
- [ ] 2800+ channel playlist remains scrollable (lazy load).
- [ ] Feature flag `ENABLE_XMLTV_EPG` (or settings EPG URL) — off = current behavior.
- [ ] No SharedPreferences megabyte dumps; EPG cache on disk.
- [ ] Xtream EPG path unchanged when not M3U.
- [x] Provider capability inspector + tier docs (M3U minimum until probes complete).
- [x] EPG matcher stub + `url-tvg` header extract.
