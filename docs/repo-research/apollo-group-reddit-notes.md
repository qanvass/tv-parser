# Apollo Group Reddit / support notes — Movies in 3rd-party players

**Date:** 2026-08-10  
**Target subreddit:** https://www.reddit.com/r/ApolloGroup_TV/  
**Access note:** Direct Reddit fetches returned **403**. Findings below come from a Redlib mirror of the subreddit, Apollo-affiliated support/FAQ pages, community TroyPoint thread, and prior TV Parser workspace probes. No passwords stored in this file.

---

## Verdict for TV Parser

Apollo customers are **not** told a single “Xtream Codes Movies login” that magically unlocks VOD in every player. Official guidance splits:

| Surface | What you get | Where |
|--------|--------------|--------|
| Live | M3U playlist (often **live-only** path) | `…/m3u8/livetv` on current CDN host |
| Movies / Series (VOD) | Native **Startup Show** (ex–Apollo Group TV) UI | Official app; separate backend from Live M3U |
| Optional 3rd-party Live | Same live M3U + EPG | Sparkle / TiviMate etc. — **VOD stays in Startup Show** |

This matches the workspace fact pattern: **starlite Live M3U works**; **Movies need Startup Show / testbyte session**, not the portal/M3U password reused against `/api/login`.

---

## What Reddit / community users actually discuss

### Subreddit snapshot (Redlib mirror)

- Heavy traffic is **outages**, buffering, VIP/Premium Club popups, VPN/ISP throttle, and “Live works / Movies broken” (or the reverse).
- TiviMate users commonly paste a **live-only** M3U ending in `/m3u8/livetv` (host family: `starlite.best` in recent posts).
- Support-style tips repeated when Movies/VOD fail: clear cache, switch player (EXO ↔ VLC / AVPLAYER), re-enter M3U, try VPN, reinstall Startup Show.
- No sticky/wiki content was reachable via Redlib wiki (Cloudflare challenge). No public “here is your XC Movies password” sticky found.

### Official / affiliate support (stronger signal than random Reddit posts)

1. **Startup Show replaced Apollo Group TV app**  
   - Install via Downloader code **`257276`** (Firestick guides).  
   - Sign-in: full **M3U link** (or QR); Firestick native path historically user/pass.  
   - Documented M3U *format* (marketing DNS): `https://con.me/api/list/USERNAME/PASSWORD` — **often dead/NXDOMAIN**; live CDN in practice is **`starlite.best`**.

2. **Third-party Live + native VOD (explicit)** — PVR / Sparkle guides  
   - Use Sparkle (or similar) with:  
     - Live M3U: `https://starlite.best/api/list/USERNAME/PASSWORD/m3u8/livetv`  
     - EPG: `https://epg.starlite.best/utc.xml.gz`  
   - Quote (paraphrased from support pages): use a **separate app for Live**, and **Apollo / Startup Show for Video On-Demand**.  
   - Sparkle Plus notes **VOD not available with an Apollo account** in that player — reinforces Live-only M3U for 3rd-party.

3. **M3U = credentials for 3rd-party Live**  
   FAQ: copy the **entire** M3U from account info / welcome email / client area. That link is how non-Firestick devices and external players authenticate to the **platform playlist**, not a separate “Movies API password” field.

4. **Premium Club**  
   Support FAQ: on-screen **“Premium Club TV”** popup = **ongoing server migration**, “no difference in the underlying service” — **not** a separate Movies subscription product with unique XC docs in public FAQs.

5. **VPN / DNS / throttling**  
   - ISP blocking → VPN (SCRAMBLE / recommended VPN guides).  
   - In-app Detailed Speed Test lists **Live TV Server** and **VOD Server** separately — Movies can fail while Live is fine.  
   - Reddit users also mention changing DNS (Google/Cloudflare) when playlists won’t load.

---

## Practical steps Apollo users are told (Movies in other apps)

### Path A — Official recommendation (Movies that “just work”)

1. Install **Startup Show** (Downloader `257276` on Firestick; Google/Apple per install guides).  
2. Sign in with account **M3U** (or QR / user+pass on Firestick).  
3. Use **Movies / TV on demand** inside Startup Show.  
4. If VOD fails but Live works: VPN, clear cache, switch EXO/VLC, confirm VOD speed test ≠ 0.

### Path B — Third-party Live only (what support documents)

1. Open account portal / welcome email → copy **current** M3U (hosts rotate; do not keep dead `con.me` / old `tvnow.best` blindly).  
2. In TiviMate / Sparkle / etc.: add playlist URL ending in **`/m3u8/livetv`**.  
3. Add EPG `https://epg.starlite.best/utc.xml.gz` if offered.  
4. Expect **Live channels only**; keep Movies in Startup Show.

### Path C — Community / historical “VOD as extra M3U lists” (unofficial for current CDN)

Older Apollo tooling and third-party setup pages document **split M3U catalogs** (host was often `tvnow.best`):

- Movies: `…/api/list/USER/PASS/m3u8/movies`  
- Series shards: `…/api/list/USER/PASS/m3u8/tvshows/1` … `/14` (or more)  
- Live: `…/m3u8/livetv`

**Implication for TV Parser:** if `starlite.best` still serves those path suffixes with the same Live user/pass, Movies might load as **additional M3U imports** (poor posters; large lists). This is **community/legacy**, not what current Sparkle PVR docs recommend. Workspace XC `player_api` probes on starlite/testbyte previously returned **no** `user_info` — do not assume classic Xtream VOD API.

### Path D — Native REST (TV Parser internal; not Reddit FAQ)

Startup Show Movies catalog is a separate REST host (`dev.testbyte.top/api/` etc.). Portal/M3U passwords have **failed** `POST /api/login` (HTTP 400) in this workspace. Reddit does not publish that API; unlocking it needs the **real app login password** or a captured bearer — not the Live M3U pass alone.

---

## Official app / DNS / portal notes (redacted)

| Item | Value / note |
|------|----------------|
| Subreddit | https://www.reddit.com/r/ApolloGroup_TV/ |
| Startup Show install code | `257276` |
| Sparkle (Amazon) Downloader (PVR) | `376012` |
| Live M3U pattern | `https://starlite.best/api/list/<user>/<pass>/m3u8/livetv` |
| EPG | `https://epg.starlite.best/utc.xml.gz` |
| Marketing M3U DNS | `con.me` — frequently unreachable; treat as alias/legacy |
| Legacy VOD M3U host (docs/tools) | `tvnow.best` — may be superseded by starlite |
| Account / packages site (FAQ) | `apollogroup.tv` (verify current official domain; scam alerts common) |
| Support FAQ mirrors | https://apollotvsupport.com/faq-2/ , https://apollotvcanada.com/techfaq/ |
| Startup Show migration pages | https://apollotvsupport.com/newapp/ , https://apollotvcanada.com/startupisapollo/ |
| 3rd-party Live PVR | https://apollotvcanada.com/pvr/ , https://apollotvsupport.com/pvr/ |
| TroyPoint (community M3U+EPG) | https://troypointinsider.com/t/apollo-group-iptv/125557 |
| Devices (FAQ) | Fire TV / Google TV / Apple / Android-iOS phones; **not** Roku / PlayStation / Xbox / non-Google smart OS |
| Connections | Up to **5** devices (VIP popup controversy on Reddit) |

Do **not** store usernames/passwords here.

---

## Secrets / email-search status (workspace)

- `.secrets/tv_login_runtime.env` has `STARTUP_SHOW_USERNAME` / `STARTUP_SHOW_PASSWORD` filled from prior portal material.  
- **STARTUP_SHOW does NOT work** for Movies API: prior probes → `POST …/api/login` **HTTP 400** Wrong username or password; no `apollo_native_session.json`.  
- Email-search agent (2026-08-10): no welcome `.eml` found; portal photo / env only; **need Premium Club welcome email** (or on-device Account screen password) for real Movies API login.  
- On-device Startup Show Movies UI can work while API login still fails — session is inside the official app, not reusable yet.

---

## Actionable checklist for unlocking Movies in TV Parser

1. Ask brother / portal for **full current M3U** list variants — especially whether `…/m3u8/movies` and `…/m3u8/tvshows/N` still 200 on **starlite.best** with Live creds.  
2. Do **not** expect XC `player_api` unless a portal field explicitly shows an Xtream host (probes already negative).  
3. Prefer Startup Show session capture (bearer) or true app password for testbyte — portal pass ≠ API.  
4. Treat Premium Club as **same service migration**, not a new Movies credential product, unless welcome email proves otherwise.  
5. Keep Live on M3U; wire Movies only after a working catalog auth path (M3U movies lists **or** native REST).

---

## Links collected

- https://www.reddit.com/r/ApolloGroup_TV/  
- https://redlib.vanillax.me/r/ApolloGroup_TV (mirror used when reddit.com 403)  
- https://apollotvsupport.com/faq-2/  
- https://apollotvsupport.com/newapp/  
- https://apollotvsupport.com/pvr/  
- https://apollotvcanada.com/techfaq/  
- https://apollotvcanada.com/startupisapollo/  
- https://apollotvcanada.com/pvr/  
- https://troypointinsider.com/t/apollo-group-iptv/125557  
- https://github.com/bruor/Apollo_m3u_to_strm (legacy multi-M3U VOD pattern)  
