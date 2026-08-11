# TV Parser — Movie discovery / category curation

**Date:** 2026-08-11  
**Status:** A–I reported from code + probe docs. Section 16 (immediate UI) implemented this pass. Full Featured/Popular/TMDB shelves **not** built.  
**Constraints:** No playlist rewrite. Do not delete provider category metadata. No commit. No AI/LLM. Cards must render without TMDB. Cooperate with Phase 0 FIX 2/3/4 in `tv_dashboard_shell.dart` — do not revert.

Provider taxonomy and UI taxonomy are separate. Raw buckets such as `Movies 1915` stay on `CategoryModel` / `ChannelMovie.categoryId`. The Movies tab shows presentation shelves only.

---

## A. Where “Movies 1915” originates

**Source: M3U `group-title`, not a UI invention.**

Starlite `/m3u8/movies` rows look like:

```text
#EXTINF:-1 tvg-logo="…" group-title="Movies 2026",Film One
```

Pipeline:

1. `M3uParser.parseCatalog` reads `group-title` (`lib/repository/api/m3u_parser.dart`). Empty → `Uncategorized`.
2. `_ensureCategory` creates one `CategoryModel` per unique group-title (`categoryName = groupTitle`, `categoryId = m3u_movie_cat_N`).
3. Each `ChannelMovie` stores that `categoryId` only. The parser does **not** copy the year onto the movie row.
4. Categories persist as `m3u_cache/m3u_movie_categories.json` (`LocaleApi.saveM3uMovieCategories`).
5. `tv_dashboard_shell._loadVodRailsInBackground` groups movies by `categoryId` and sets **`TvChannelRow.title = cat.categoryName`**.
6. `ProviderCurationRules.sortCategoriesForNormalDashboard` scores all `Movies YYYY` groups equally (100), then sorts **alphabetically** → `Movies 1915` before `Movies 2026`.

So “Movies 1915” is provider encoding. The UI currently promotes it to a top-level rail heading. The parser does not invent years; it does not hide them either.

---

## B. Category names vs derived labels

| Layer | What it is today |
|-------|------------------|
| Provider category name | Exact `group-title` / Xtream `category_name` on `CategoryModel.categoryName` |
| Provider category id | `m3u_movie_cat_*` or Xtream id on `CategoryModel.categoryId` + `ChannelMovie.categoryId` |
| Rail heading | **Same string** as provider name (until section 16) |
| Card title | `TitleNormalizer.parse(name).displayTitle` (strips `(YYYY)` / quality tags; does not invent titles) |
| Card year badge | `TitleNormalizer` year from the **title**, not from the category |
| Display / genre / decade / language | **Not stored.** No `displayCategory` field yet |

There is no `CategoryPresentationMapper` in tree before this pass. No derived “Classics” / “2020s” labels existed.

---

## C. Unique year categories

From `docs/repo-research/starlite-vod-m3u-probe.md` (2026-08-10):

| Signal | Value |
|--------|--------|
| Movies `#EXTINF` | **18,597** (probe) / **18,601** stored after login (`[VOD_M3U]`) |
| Unique movie `group-title`s | **109** |
| Sample names | `Movies 2026`, `Movies 2024`, `Movies 2025`, `Movies 1998`, … |

No dumped list of all 109 names is in the repo. Samples and the on-device “Movies 1915 / 1916 / 1920” headings are year buckets. 1915–2026 inclusive is 112 years; **109 unique groups ≈ nearly every year with a few gaps**. Treat **~109 year-bucket categories** as the working count until a cache dump is enumerated.

Device cache file (not in git): `m3u_movie_categories.json`.

---

## D. Movies with a usable year

| Source | On Starlite M3U list rows? | Notes |
|--------|----------------------------|--------|
| Provider category name (`Movies 1915`) | **Yes, ~all** | Year is on the **group**, not a movie field |
| `ChannelMovie` year column | **No** | Model has `added`, not `releaseYear` |
| Title `(YYYY)` / bare year | **Opportunistic** | `TitleNormalizer.extractYear` — no corpus % in repo |
| `ChannelMovie.added` | **Not set** by `M3uParser` | XC list may have unix `added`; unused for M3U |
| TMDB `release_date` | **After** background match only | Must not be required to render |

**Usable year for presentation without TMDB:** derive from provider category name (primary for this catalog) and fall back to title parse. That covers essentially the full 18.6k Starlite movie list for Classics / Recent splits. Title-only year is a subset and is already used for the card badge.

---

## E. Existing language info

**Almost none on movie catalog rows.**

- `ChannelMovie` has no language field.
- `MovieDetail.Info.Video.Tags.language` exists only on Xtream `get_vod_info` payloads — not ingested for M3U list rails.
- `UnifiedMediaMetadata` has no `originalLanguage`.
- `TmdbClient._mapMovie` does not keep `original_language`.
- `UserPreferenceProfile.language` is a **user preference**, not item metadata.
- `ContentIntelligenceService.scoreMovie` boosts if the **title or category string contains** the profile language token (substring). That is not a trusted language tag.
- Do not treat Latin-script titles as English.

Trusted language for English-language shelves is **not available** until TMDB (or provider) fields are cached. Do not build an English shelf this pass.

---

## F. Existing country / region info

**Not on movies.**

- Movie `group-title`s are years, not `USA Movies` / `UK`.
- Live groups **are** regions (`US`, `Canada`, `UK`, …) — live-only.
- `XmlTvRepository.countryFromTvgId` is live EPG matching.
- `UserPreferenceProfile.country` / `region` are user prefs.
- TMDB `origin_country` / production countries are **not mapped**.

American Movies / region shelves need later enrichment. Do not invent them from title guesses.

---

## G. Existing TMDB integration

Present, **optional, background, high-confidence, not required to paint cards.**

| Piece | Role |
|-------|------|
| `TmdbClient` | Search movie/TV. Off unless `ENABLE_TMDB` (default true) **and** `TMDB_API_KEY` or `.secrets/tmdb.json` |
| `TmdbMatch` | Exact sanitized title; years must agree when both exist |
| `TmdbEnrichmentWorker` | Queued after Live/Movies first paint (`_enqueueVodForTmdb`) |
| Mapped fields today | title, year, overview, poster, backdrop, rating, `tmdb_id` |
| **Not mapped** | original_language, origin_country, genres, popularity, vote_count |
| Settings copy | Honest TMDB credit when a key exists |

Overnight cinematic pass: TMDB worker is **off** on device (no key). Cards already use playlist `tvg-logo` / title. **Do not gate Movies UI on TMDB.**

---

## H. Safest minimal UI cleanup (this pass = section 16)

**Do**

- Keep `CategoryModel` / `m3u_movie_categories.json` / `ChannelMovie.categoryId` unchanged.
- After Phase 0 builds provider-keyed rails (FIX 2 included), map headings through `CategoryPresentationMapper`.
- Detect year-bucket names (`Movies 1915`, `Movie 2024`, `Films 2023`, `2022 Movies`, trailing `Movies 2025`).
- Collapse those headings. Do **not** show `Movies 1915` as a top-level rail or chip.
- If the catalog is only year buckets: shelves **Recently Added** (year ≥ 2020), **Movies** (1980–2019 + unknown), **Classics** (year < 1980). Omit a shelf when empty.
- If named (non-year) categories exist, keep those labels; still collapse year buckets.
- Stamp `providerCategoryId` / `providerCategoryName` on `TvStreamRecord`. One catalog row; shelves hold references.
- If movies exist and presentation would be empty → single **Movies** shelf (Phase 0 contract).
- Leave FIX 2 (group by `categoryId` when cats/rails empty), FIX 3 (do not clear `_movieRows` on refresh), FIX 4 (empty pane only when raw count == 0) untouched.

**Do not this pass**

- Featured / Popular / Trending / genre / English / American shelves
- Netflix / Prime / Disney+ rows
- Playlist rewrite, deleting categories, TMDB-required render, AI
- Browse-by-year / decade chips (optional later)
- Removing any playable title

---

## I. Long-term curation plan (17 points → Flutter)

Implementation later. Data layer stays provider-faithful; UI uses presentation indexes.

| # | Brief | Flutter mapping | When |
|---|--------|-----------------|------|
| 1 | Preserve provider id/name; add display fields | Keep `CategoryModel` + `ChannelMovie.categoryId`. Add presentation fields on a **view model** or later Drift columns (`displayCategory`, `releaseYear`, `decade`, `language`, `country`, `genre`, `popularityScore`, `metadataConfidence`). Do not overwrite JSON category names. | 16 stamps provider fields on `TvStreamRecord` only |
| 2 | Normalize year categories | `CategoryPresentationMapper.yearFromCategoryName` + decade helper. Cache `releaseYear` at ingest (`StarliteVodM3uSession` persist) so Movies open does not rescan 18k strings. | 16: detect + collapse only |
| 3 | User-facing shelves | Ordered `List<TvChannelRow>` from mapper. Only emit non-empty shelves. Full list: Featured, Continue Watching, Popular, New & Recent, English, American, genres, Classics, decade, All Movies. | Later |
| 4 | English priority | Order: TMDB `original_language` → provider lang → group marker → deterministic title tags → unknown. Rank in discovery; never drop. No LLM. | After G fields cached |
| 5 | US / American priority | TMDB origin/production + provider region markers. Rank only. Never delete non-US. Featured/Popular stay above “American Movies”. | After F fields cached |
| 6 | TMDB background only | Keep `TmdbEnrichmentWorker`. Extend `_mapMovie` for language/country/genres/popularity. Cache in `tmdb_enrichment.json`. Cards paint first. | Existing path; extend map later |
| 7 | Match confidence | Keep `TmdbMatch` exact-title + year. Later: numeric score (≥0.90 auto; 0.75–0.89 need year; else skip). Wrong art worse than placeholder. | Existing gate stays |
| 8 | Popular / Trending | Do **not** treat M3U order as popularity. Score = TMDB popularity + vote count + recency + local watch/favorites. New user: metadata only. | Needs G popularity |
| 9 | Platform labels | Never create Netflix/Prime/Disney+/Max/Hulu from title or `group-title` guesses. Platform shelf only with trustworthy watch-provider metadata (and legally appropriate). | Never invent |
| 10 | `CategoryPresentationMapper` | `Movies 1921` → year 1921 / decade 1920s / Classics. `USA Movies` → American. `VOD Action` → Action. `EN Movies` → English. One movie → many shelves by id. | 16: year collapse only |
| 11 | Do not duplicate catalog | Shelves are `List<TvStreamRecord>` references (same instance). Later: shelf → `List<streamId>` into one `ChannelMovie` store. | 16: references |
| 12 | Default Movies viewport | Hero + Continue Watching + Popular + New & Recent + English/US, then genres. Raw provider browser under Browse All (Genres / Decades / Years / Languages / Provider Categories). | After 3–8 |
| 13 | Classics | Intentional shelf, not leftover junk. Later: Silent & Early / Golden Age / decade classics. Never put `Movies 1915` at the top. | 16: one Classics shelf |
| 14 | User preference later | Reorder shelves from `UserPreferenceProfile` + `WatchingCubit` (deterministic). No AI. | After history is reliable |
| 15 | Performance | Derive year/decade at ingest; do not regroup 18k on every Movies focus. Page/lazy `ListView`. File JSON until Catalog Engine Phase F. Isolates already planned in `COORDINATION_CATALOG_ENGINE.md`. | Ingest index later |
| 16 | **Immediate screen fix** | Collapse year headings → Movies + Classics + Recently Added. This pass. | **Done** |
| 17 | Report before large edit | This document (A–I). | **Done** |

**Recommended first rows (product, not this PR):** Featured → Continue Watching → Popular → New & Recent → genres. American/English rank inside those rows; they are not the forever #1 heading.

**Rollback:** revert `category_presentation_mapper.dart` + the post-FIX-2 `presentMovies` call in `tv_dashboard_shell.dart`. Provider JSON unchanged.

**Manual TV check:** Movies tab shows Recently Added / Movies / Classics (whichever have items). No `Movies 1915` chip or rail title. Search still finds titles. Empty catalog still uses FIX 4. Adult categories still hidden.

---

## This pass — files

| File | Change |
|------|--------|
| `docs/COORDINATION_MOVIE_CURATION.md` | A–I + 17-point Flutter map |
| `lib/repository/api/category_presentation_mapper.dart` | Year-bucket detect + shelf collapse |
| `test/category_presentation_mapper_test.dart` | Mapper unit tests |
| `lib/presentation/tv/widgets/tv_channel_grid.dart` | `providerCategoryId` / `providerCategoryName` on records |
| `lib/presentation/tv/tv_dashboard_shell.dart` | Stamp provider fields; present shelves after FIX 2 |

Phase 0 FIX 2/3/4 left in place.
