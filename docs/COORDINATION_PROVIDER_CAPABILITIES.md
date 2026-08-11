# Provider capability tiers & metadata enrichment

**Status:** VOD M3U path wired 2026-08-10 (list-API hosts)  
**Stance:** Neutral media player. Detect what the **authorized** provider actually exposes; never invent titles, art, or trailers.

## Product conclusion (replacement)

Until capability detection completes, treat **plain M3U as the minimum tier**. Do **not** conclude “skinning only” before actively testing:

1. XMLTV (`url-tvg` / `x-tvg-url` / host default EPG / user EPG URL)
2. Xtream-compatible Live EPG (`get_short_epg` / full EPG when available)
3. VOD + series via **split M3U** (`/m3u8/movies`, `/m3u8/tvshows[/N]` on `/api/list/{user}/{pass}` hosts), `player_api`, or other authorized catalog APIs
4. Artwork / trailer endpoints when the provider supplies them

Enrich authorized VOD/series via **TMDB** (+ optional **TVmaze**) only behind flags and keys. UI degrades by **detected** capabilities.

## Tier model

| Tier | Signal | Live | EPG | Movies/Series | Metadata |
|------|--------|------|-----|---------------|----------|
| **M3U minimum** | `#EXTM3U` playlist | Yes (playlist) | Only if `url-tvg` present | Only if playlist rows classified as movie/series | Provider logos only |
| **M3U + VOD M3U** | Live `/api/list/u/p` + `/m3u8/movies` + `/m3u8/tvshows[/N]` | Yes | Optional host XMLTV gzip | File-cached VOD catalogs | Provider logos / tvg-logo |
| **M3U + XMLTV** | Header or settings EPG URL | Yes | XMLTV ingest (next) | Same as M3U | Programme titles from XMLTV |
| **Xtream-compatible** | Working `player_api.php` | Categories/streams | `get_short_epg` (± full) | `get_vod_*` / `get_series*` | Provider fields → optional TMDB |
| **Full / hybrid** | Xtream + XMLTV + posters | Yes | Short + XMLTV full | VOD + series | Provider → TMDB → TVmaze → title-only |

## Inspector trigger

`ProviderCapabilityInspector` runs **async after**:

- `IptvProviderSession.commitM3u` (playlist body + optional `/api/list/{user}/{pass}` creds)
- `AuthApi.registerUser` Xtream success

`StarliteVodM3uSession` (behind `ENABLE_STARLITE_VOD_M3U`, default **true**) runs **awaited** after Live commit for list-API hosts, writes movie/series into `m3u_cache/`, and sets `supportsVod` / `supportsSeries` / `xmlTvUrl` when entries return. Inspector merge preserves those flags if the async XC probe finishes later.

Persists to `m3u_cache/provider_capabilities.json` (not SharedPreferences). Logs:

`[CAPABILITIES] live=… xmltv=… shortEpg=… vod=… series=…` — **never** passwords.

## Enrichment priority

1. Provider payload (plot/poster/trailer if present and non-spam)
2. TMDB — only if `ENABLE_TMDB=true` **and** key (`TMDB_API_KEY` or `.secrets/tmdb.json`)
3. TVmaze — only if `ENABLE_TVMAZE=true`
4. Title-only (`TitleNormalizer`)

HTTP for TMDB/TVmaze is stubbed; production path does not call them until flags+key.

## EPG matching order

1. Exact `tvg-id`
2. Normalized channel ID
3. Callsign
4. Channel name + country
5. Manual user mapping (persist stub in `EpgChannelMatcher`)

## UI honesty

Empty Movies/Series panes distinguish:

- “Provider has no VOD API detected”
- “Playlist has no movies”
- VOD playlist fetch failed (Retry re-fetches `/m3u8/movies` + tvshows shards)
- Provider-specific VOD session pending (Startup Show REST fallback only)

## Observed: list-API Live hosts (starlite family)

Probe notes:

- Live: `docs/repo-research/provider-capability-probe-notes.md` (2026-07-25) — plain Live M3U; same-host XC/`xmltv.php` = 404
- VOD M3U: `docs/repo-research/starlite-vod-m3u-probe.md` (2026-08-10) — **`/m3u8/movies`** (~18k EXTINF) and **`/m3u8/tvshows[/N]`** (5k/shard) work with **same Live list credentials**; EPG `https://epg.starlite.best/utc.xml.gz` is usable XMLTV gzip

Wiring (2026-08-10): after Live `commitM3u`, fetch VOD M3Us → `m3u_cache` movie/series files. Startup Show REST remains fallback if VOD M3U fails. Feature flag: `ENABLE_STARLITE_VOD_M3U` (default true). Guide UI for XMLTV still later.

Inspector already maps `player_api` HTTP 404 → unsupported (`player_api_404` note, no `playerApiBase`); treat that as **capability missing**, not auth failure.

## Next steps

1. XMLTV download + disk cache + `ENABLE_XMLTV_EPG` (URL already in capabilities for family hosts)
2. Wire `EpgChannelMatcher` into Live hero / `TvEpgPeek`
3. TV Guide rail (channel × time)
4. Complete TMDB HTTP when product enables enrichment
