# Starlite VOD M3U probe (Apollo / Live host suffixes)

**Date:** 2026-08-10  
**Context:** Follow-up from `apollo-group-reddit-notes.md` Path C (community/legacy split M3U catalogs).  
**Credentials:** Live M3U user/pass from parent `.secrets/tv_login_runtime.env` (`APOLLO_M3U_URL` / `APOLLO_*`); also secondary account label `vvknowyourself11` as requested. **No passwords in this file** - URLs use `<user>/<pass>`.

## Verdict (Y/N)

| Path | Works? | Evidence |
|------|--------|----------|
| **movies** | **Y** | HTTP 200 `audio/mpegurl`, **18597** `#EXTINF`, group-titles like `Movies 2026` / year buckets (109 unique groups) |
| **tvshows** | **Y** | HTTP 200 `audio/mpegurl`; base + `/1`...`/3` return series-style lists (**5000** `#EXTINF` each; `/tvshows` == `/tvshows/1`) |
| **epg** | **Y** | `https://epg.starlite.best/utc.xml.gz` HEAD/GET **200**, ~4.8 MB `application/octet-stream`, gzip magic `1F 8B`, decompresses to XMLTV `<tv ...>` |

Official stance remains: third-party = Live-focused; Movies often steered to Startup Show. **Empirically**, starlite still serves full Movies + sharded TV-shows M3U with the same Live list credentials.

## Wiring pattern for TV Parser (next step - not implemented here)

Prefer host **`starlite.best`** (`tvnow.best` returned identical playlists in this probe).

```
Live:    https://starlite.best/api/list/<user>/<pass>/m3u8/livetv
Movies:  https://starlite.best/api/list/<user>/<pass>/m3u8/movies
Series:  https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/<N>   # N=1..; /tvshows == /tvshows/1
EPG:     https://epg.starlite.best/utc.xml.gz
```

**Next wiring step:** Implemented 2026-08-10 in `StarliteVodM3uSession` / `IptvProviderSession` (see `HANDOFF_LIVE.md`). Parallel path to Startup Show REST — does not replace it.

## Primary Live creds - `starlite.best`

| HTTP | Content-Type | #EXTINF | Kind | URL (redacted) | Notes |
|------|--------------|---------|------|----------------|-------|
| 200 | audio/mpegurl | 2746 | live-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/livetv` | unique_groups=43 |
| 200 | audio/mpegurl | 18597 | movies/vod-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/movies` | unique_groups=109 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows` | unique_groups=540; same as `/1` |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/1` | unique_groups=540 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/2` | unique_groups=399 (2024-era show groups) |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/3` | unique_groups=359 (2023-era show groups) |

### Sample group-titles

- **livetv:** US | Canada | US Local | Documentary | Music | News | Sports | ... (43 unique)
- **movies:** Movies 2026 | Movies 2024 | Movies 2025 | Movies 1998 | ... (year buckets; 109 unique)
- **tvshows / tvshows/1:** show-title groups (540 unique on shard 1)
- **tvshows/2:** 2024-era series groups (399 unique)
- **tvshows/3:** 2023-era series groups (359 unique)

Follow-up: GETs of `/tvshows/4+` returned HTTP 200 ~1 MB bodies that a quick PowerShell parse treated as non-text / zero `#EXTINF` without careful decompression - more shards likely exist (legacy docs cite ~14). Re-probe with explicit gzip/UTF-8 before assuming empty. Shards **1-3** are confirmed real series M3U.

## Alias host - `tvnow.best` (primary creds)

Same `#EXTINF` counts and kinds as starlite for livetv / movies / tvshows{,/1,/2,/3}. Treat as CDN alias of the current Live host.

| HTTP | Content-Type | #EXTINF | Kind | URL (redacted) | Notes |
|------|--------------|---------|------|----------------|-------|
| 200 | audio/mpegurl | 2746 | live-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/livetv` | matches starlite |
| 200 | audio/mpegurl | 18597 | movies/vod-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/movies` | matches starlite |
| 200 | audio/mpegurl | 5000 | series-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/tvshows` | matches starlite |
| 200 | audio/mpegurl | 5000 | series-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/tvshows/1` | matches starlite |
| 200 | audio/mpegurl | 5000 | series-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/tvshows/2` | matches starlite |
| 200 | audio/mpegurl | 5000 | series-ish | `https://tvnow.best/api/list/<user>/<pass>/m3u8/tvshows/3` | matches starlite |

## Dead / unusable hosts

### `laon.live`

HTTP 200 but **`text/html`** landing page (~980 B), not M3U - list API dead for all probed suffixes (`livetv`, `movies`, `tvshows`, `tvshows/1..3`).

### `con.me`

DNS failure (remote name could not be resolved) for all suffixes.

## Secondary creds - account `vvknowyourself11` on `starlite.best`

Same successful shapes as primary (livetv 2746, movies 18597, tvshows shards 5000). Confirms path shapes are not a single-account quirk. Password omitted everywhere.

| HTTP | Content-Type | #EXTINF | Kind | URL (redacted) | Notes |
|------|--------------|---------|------|----------------|-------|
| 200 | audio/mpegurl | 2746 | live-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/livetv` | unique_groups=43 |
| 200 | audio/mpegurl | 18597 | movies/vod-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/movies` | unique_groups=109 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows` | unique_groups=540 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/1` | unique_groups=540 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/2` | unique_groups=399 |
| 200 | audio/mpegurl | 5000 | series-ish | `https://starlite.best/api/list/<user>/<pass>/m3u8/tvshows/3` | unique_groups=359 |

## EPG - XMLTV tier

| Field | Value |
|-------|-------|
| URL | `https://epg.starlite.best/utc.xml.gz` |
| HEAD/GET status | **200** |
| Content-Type | `application/octet-stream` |
| Size | ~4,792,338 bytes |
| Format | gzip (`1F 8B`) -> XMLTV root `<tv generator-info-name=...>` with `<channel>` entries |
| Usable for XMLTV tier? | **Yes** - download, gunzip, parse as XMLTV for Live EPG |

## Method notes

- Probes used HEAD where possible plus GET body parse for `#EXTINF` / `group-title`.
- Classification: movie/year groups -> movies/vod-ish; show-title groups -> series-ish; US/Sports/News -> live-ish.
- No passwords stored; restore zip untouched; no commit.

## Compliance

TV Parser remains a neutral player. This doc records **URL path reachability** for an account the workspace already uses for Live - not a redistributed catalog product.