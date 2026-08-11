# TV Parser baseline — Live TV / EPG / Guide (2026-07-25)

## Stack
- Flutter (Dart SDK `>=3.10.3`), package `com.quasar.tvparser`, version `2.0.3+3001`
- State: GetX + flutter_bloc; storage: GetStorage + path_provider file cache
- Playback: `flutter_vlc_player_16kb` (+ video_player / pod_player)
- TV shell: `lib/presentation/tv/` (Material + Focus, not Compose)
- Images: cached_network_image + SmartChannelLogo

## Provider capability tiers (do not skip)
Until probes finish, **plain M3U = minimum tier**. Actively test XMLTV, Xtream Live EPG, VOD, series, artwork before concluding only skinning is possible. See `docs/COORDINATION_PROVIDER_CAPABILITIES.md`.

| Tier | What it means |
|------|----------------|
| M3U minimum | Live from playlist; no assumed VOD/EPG |
| M3U + XMLTV | Header / settings EPG URL present |
| Xtream-compatible | Working `player_api` live/EPG/VOD/series |
| Full / hybrid | Xtream + XMLTV + optional TMDB enrichment |

`ProviderCapabilityInspector` runs after M3U commit / Xtream login → `m3u_cache/provider_capabilities.json`.

## Live / catalog path (working)
```
M3U login → IptvProviderSession.commitM3u → LocaleApi m3u_cache/*.json
→ (async) ProviderCapabilityInspector → provider_capabilities.json
→ IpTvApi live reads → tv_dashboard_shell Live rails (~2800 channels / ~43 groups)
```
Starlite-family hosts: Live M3U often works; classic `player_api` may 404; Movies/Series need a separate authorized VOD API when present.

## EPG today
| Piece | Status |
|-------|--------|
| `IpTvApi.getEPGbyStreamId` | Xtream `get_short_epg` only |
| M3U / starlite sessions | **Hard-returns `[]`** |
| `TvEpgPeek` | UI exists; empty without provider EPG / XMLTV |
| TV Guide screen / rail item | **Missing** |
| XMLTV ingest | **Missing** (header detect + matcher stub landed) |
| Channel↔programme match | Xtream stream_id today; `EpgChannelMatcher` stub for XMLTV |

## Live UI today
- Left rail: Live / Movies / Series / Favorites / History / Search / Settings
- Live: `TvLiveFocusHero` (channel name + logo) + category rails (`TvChannelGrid`)
- Not yet: program title/backdrop hero, now/next on cards, full Guide grid
- Empty Movies/Series: capability-honest copy when no VOD API detected

## Constraints
- Neutral player; no bundled channel catalogs
- Do not put large catalogs back in SharedPreferences
- Keep dual-ABI Chromecast installs; Cast gated off on TV
- Prefer adapters + feature flags; no Kotlin rewrite of Flutter app
- Never invent metadata; TMDB only behind `ENABLE_TMDB` + key
