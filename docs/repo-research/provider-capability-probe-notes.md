# Provider capability probe notes (PC-only)

**Date:** 2026-07-25  
**Scope:** Design input for a provider capability inspector (no Chromecast / ADB).  
**Secrets:** Loaded from workspace `.secrets/tv_login_runtime.env` for probes only. Credentials and full stream URLs are redacted below.

---

## 1. Working M3U source

| Candidate key | Host (redacted path) | Result |
|---|---|---|
| `APOLLO_M3U_URL` / `M3U_URL` | `https://starlite.best/api/list/***/***` | **Working** — HTTP 200, `#EXTM3U`, ~741 KB |
| `M3U_URL_PRIOR` / `M3U_URL_ALT` | `https://laon.live/api/list/***/***` | Not M3U — HTTP 200 HTML (~980 B, parked/portal) |
| `REVIEW_M3U` | `https://tvparser.com/sample.m3u` | Working review sample (legal CC demos); not used as primary |

**Selected for analysis:** active Apollo / M3U URL on host `starlite.best`.

### First ~30 lines (structure, redacted)

```
 1| #EXTM3U
 2| #EXTINF:-1 tvg-id="<slug>" tvg-name="<slug>" tvg-type="live" group-title="US" tvg-logo="https://media.starlite.best/<slug>.png",<display>
 3| https://starlite.best/***/***/***/***/livetv.epg/<slug>.m3u8
 … (same pattern through line ~30)
```

Observations from header / early rows:

| Signal | Present? | Notes |
|---|---|---|
| `#EXTM3U` | Yes | Bare header — **no** attrs on line 1 |
| `url-tvg` | **No** | Not on `#EXTM3U`, not elsewhere as a playlist EPG pointer |
| `x-tvg-url` | **No** | Same |
| `tvg-logo` | Yes | Per-entry; host `media.starlite.best` |
| Sample `tvg-id` | Yes | Dotted slug style, e.g. `*.us` / regional suffixes (stable string IDs) |

---

## 2. `tvg-id` coverage

| Metric | Count |
|---|---|
| `#EXTINF` rows | **2806** |
| `#EXTINF` with **non-empty** `tvg-id="…"` | **2806** (100%) |
| Empty / missing `tvg-id` | **0** |

Additional attrs (same playlist):

- `tvg-logo` non-empty: **2806 / 2806**
- `tvg-type`: **2806 / 2806**, value always `live`
- `group-title`: present on all rows (multi-region buckets; top buckets include US Local, US, Latino, Canada, Sports, UK, etc.)

**Inspector implication:** treat this provider as **strong M3U identity** (`tvg-id` + logos). Do not infer EPG availability from `tvg-id` alone.

---

## 3. Xtream-style `player_api.php` probes (same host)

Base: `https://starlite.best/player_api.php` with active XC/Apollo credentials (redacted).  
Report: **HTTP status + whether body looks like classic XC JSON** (category/series arrays or `user_info`/`server_info`).

| Action | HTTP | Looks JSON? | Looks classic XC? | Shape |
|---|---|---|---|---|
| `get_live_categories` | **404** | Yes | **No** | `{"success":false,"message":"Resource not found"}` |
| `get_vod_categories` | **404** | Yes | **No** | same |
| `get_series` | **404** | Yes | **No** | same |

Extra status-only checks (same host, same creds where applicable):

| Probe | HTTP | Kind |
|---|---|---|
| `player_api.php` (auth only) | 404 | JSON `{success,message}` |
| `player_api.php&action=get_live_streams` | 404 | same |
| `xmltv.php` | 404 | same |
| `/epg`, `/xmltv.xml` guesses | 404 | same |

**Inspector implication:** this host is **M3U-list capable**, **not** a classic Xtream Codes `player_api` surface. Capability flags should be independent: `m3u_ok` ≠ `xc_api_ok`.

---

## 4. EPG-looking URLs in M3U body

| Finding | Detail |
|---|---|
| Header EPG pointers (`url-tvg` / `x-tvg-url`) | **Absent** |
| Standalone XMLTV / `.xml` / `.xml.gz` playlist URLs | **None** found |
| Stream URL path token `livetv.epg` | **All 2806** media URLs use path segment `…/livetv.epg/<slug>.m3u8` on `starlite.best` |
| Unique hosts touching “epg”-like strings | `starlite.best` (streams); logos on `media.starlite.best` (not EPG) |

**Note:** `livetv.epg` is a **playback path convention**, not an XMLTV guide URL. Capability inspector should classify:

1. Explicit playlist EPG attrs (`url-tvg`, `x-tvg-url`)
2. Separate XMLTV endpoint probes (`xmltv.php`, etc.)
3. Path tokens that merely contain `epg` (do **not** mark as guide-capable)

---

## 5. Capability inspector design takeaways

Suggested probe outputs / flags for this provider shape:

```
m3u.fetch            = ok (200, #EXTM3U)
m3u.extinf_count     = 2806
m3u.tvg_id_coverage  = 1.0
m3u.tvg_logo_coverage= 1.0
m3u.header_url_tvg   = false
m3u.header_x_tvg_url = false
m3u.epg_xml_urls     = []
m3u.stream_path_hint = livetv.epg   # informational only
xc.player_api        = missing/404 (non-XC JSON error envelope)
xc.get_live_categories / get_vod_categories / get_series = unavailable
epg.xmltv_php        = unavailable (404)
```

UI / product framing:

- Neutral player: report **capabilities** (M3U parse, logos, guide pointers, XC API), not marketing claims.
- Prefer review/`REVIEW_M3U` for store demos; this probe used authorized runtime secrets offline.
- Do not hard-code hostnames in app shipping paths; keep host/path detection generic.

---

## 6. Redaction & method

- PC-only: `Invoke-WebRequest` / `curl.exe` against env-configured URLs.
- Usernames/passwords never written to this doc; URL path credential segments replaced with `***`.
- Display/channel brand names omitted from samples; structure preserved via placeholders.
- Temp probe artifacts under `%TEMP%\tvparser_capability_probe\` (local only; do not commit).
