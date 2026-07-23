"""
musicbrainz_cover_art.py — resolve a song's actual album art via MusicBrainz +
the Cover Art Archive (CAA). Kept as its own module rather than folded into
anilist_service.py or graphql_queries.py: this hits two REST APIs that have
nothing to do with GraphQL or AniList, and both come with their own strict
etiquette requirements (see below), so isolating them means the rate-limit
state and the User-Agent string live in exactly one place.

WHY TWO HOPS, AND WHY MUSICBRAINZ ISN'T ENOUGH ON ITS OWN
----------------------------------------------------------
MusicBrainz is a metadata database — it does NOT host images. Album art
lives on a separate service, the Cover Art Archive (coverartarchive.org),
keyed by a MusicBrainz MBID (release or release-group UUID). So getting
actual pixels for "NIGHT DANCER by imase" takes two requests:

  1. MusicBrainz `recording` search — find the song, get back the
     release-group MBID(s) it appears on.
  2. Cover Art Archive `release-group/{mbid}` — get the actual image URLs
     for that MBID.

Querying at the RELEASE-GROUP level (not the individual release) on
purpose: CAA cover art is very often only attached to the release-group as
a whole rather than to every specific release edition, so release-group is
the more forgiving of the two lookups. See:
https://musicbrainz.org/doc/Cover_Art_Archive/API

RATE LIMITING — THIS IS NOT OPTIONAL
-------------------------------------
MusicBrainz's documented rule (https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting):
  "All users of the API must ensure that each of their client applications
  never make more than ONE call per second... If you impact the server by
  making more than one call per second, your IP address may be blocked
  preventing all further access to MusicBrainz."
That's a per-IP limit, so it applies per end-user of this desktop app (each
user's machine is its own IP) — but WITHIN one user's app, every call this
module makes must still be serialized to 1/sec, because a single anime page
can have 3-4 OP/ED themes resolved back-to-back. _MB_RATE_LIMITER enforces
that globally within this process for every function in this module.

The Cover Art Archive itself has no documented rate limit as of this
writing, but calls to it are still funneled through the same limiter for
simplicity — one gate, no risk of the two APIs racing each other.

USER-AGENT — ALSO NOT OPTIONAL
--------------------------------
MusicBrainz requires "a proper User-Agent string" identifying the
application; generic/anonymous-looking User-Agents get a lower throttling
ceiling. _USER_AGENT below should be updated with a real contact URL
(repo link or similar) before shipping — MusicBrainz support pages ask for
this so they have a way to reach an app's maintainer if it misbehaves.

WHAT THIS MODULE DELIBERATELY DOES NOT DO
-------------------------------------------
- No on-disk caching. Every call still costs a real network round trip.
  Right now that's mitigated only by fetchOpeningEndingSongs() resolving
  each theme once per page-open — if this gets used somewhere hotter than
  that, add a cache in front of get_album_art_for_song() rather than here.
- No retries. A 503 (rate limit hit despite the limiter — e.g. another
  process on the same machine also calling MusicBrainz) or a network error
  is treated the same as "no art found": return "". This is an enhancement
  to an already-working theme list, not a critical path, so failing
  quietly is the right default — a missing image should never surface as
  an errorOccurred in the UI.
"""

import threading
import time
import requests

_MUSICBRAINZ_BASE = "https://musicbrainz.org/ws/2"
_COVER_ART_BASE    = "https://coverartarchive.org"

# TODO: replace the contact URL with this project's actual repo/homepage
# before shipping — see the User-Agent section above.
_USER_AGENT = "Knilist/0.1 (https://github.com/REPLACE_ME/knilist)"

_REQUEST_TIMEOUT = 10  # seconds; both APIs are normally fast, but neither
                        # gets an unbounded wait from a background thread


class _RateLimiter:
    """Blocks callers so calls to a given host never exceed one per
    `min_interval` seconds, measured from the *start* of the previous call
    that used this limiter. threading.Lock makes this safe across the
    multiple daemon threads anilist_service.py spawns per page load."""

    def __init__(self, min_interval: float):
        self._min_interval = min_interval
        self._lock = threading.Lock()
        self._last_call_at = 0.0

    def wait(self) -> None:
        with self._lock:
            now = time.monotonic()
            elapsed = now - self._last_call_at
            if elapsed < self._min_interval:
                time.sleep(self._min_interval - elapsed)
            self._last_call_at = time.monotonic()


# Shared across every call this module makes, to both musicbrainz.org and
# coverartarchive.org — see the module docstring for why both share one gate.
_MB_RATE_LIMITER = _RateLimiter(min_interval=1.0)


def _mb_get(path: str, params: dict) -> dict | None:
    """GET against the MusicBrainz API, rate-limited, JSON response. Returns
    None on any error (bad status, timeout, malformed JSON, no matches) —
    callers treat None exactly like "nothing found"."""
    _MB_RATE_LIMITER.wait()
    try:
        resp = requests.get(
            f"{_MUSICBRAINZ_BASE}/{path}",
            params={**params, "fmt": "json"},
            headers={"User-Agent": _USER_AGENT, "Accept": "application/json"},
            timeout=_REQUEST_TIMEOUT,
        )
        if resp.status_code != 200:
            return None
        return resp.json()
    except (requests.RequestException, ValueError):
        return None


def _caa_get(release_group_mbid: str) -> dict | None:
    """GET the Cover Art Archive listing for a release-group MBID.
    404 means "no cover art chosen for this release-group" — a normal,
    expected outcome, not an error — so it's folded into the same None
    return as any other failure."""
    _MB_RATE_LIMITER.wait()
    try:
        resp = requests.get(
            f"{_COVER_ART_BASE}/release-group/{release_group_mbid}",
            headers={"User-Agent": _USER_AGENT, "Accept": "application/json"},
            timeout=_REQUEST_TIMEOUT,
        )
        if resp.status_code != 200:
            return None
        return resp.json()
    except (requests.RequestException, ValueError):
        return None


def _find_release_group_mbid(song_title: str, artist_name: str) -> str | None:
    """Search MusicBrainz recordings for `song_title` by `artist_name`,
    return the release-group MBID of the first result that actually has
    one. Falls back to a title-only search if the artist+title search
    comes up empty — animethemes.moe and MusicBrainz don't always agree on
    artist name spelling/romanization, and a title-only match is still far
    better than no match, given this is best-effort art, not authoritative
    metadata."""
    if not song_title:
        return None

    queries = []
    if artist_name:
        queries.append(f'recording:"{song_title}" AND artist:"{artist_name}"')
    queries.append(f'recording:"{song_title}"')

    for query in queries:
        data = _mb_get("recording", {"query": query, "limit": 5})
        if not data:
            continue
        for recording in (data.get("recordings") or []):
            for release in (recording.get("releases") or []):
                rg = release.get("release-group") or {}
                rg_id = rg.get("id")
                if rg_id:
                    return rg_id
    return None


def get_album_art_for_song(song_title: str, artist_name: str) -> str:
    """Best-effort album art URL for a song, via MusicBrainz + Cover Art
    Archive. Returns "" (never raises) if nothing is found at any step —
    unmatched recording, matched recording with no release-group, or a
    release-group with no chosen cover art are all equally "no art", since
    the caller's fallback (the artist photo, or nothing) is the same either
    way. Picks the 500px thumbnail: big enough for a card backdrop, far
    smaller than the ~1200px/original that CAA also offers."""
    rg_mbid = _find_release_group_mbid(song_title, artist_name)
    if not rg_mbid:
        return ""

    caa_data = _caa_get(rg_mbid)
    if not caa_data:
        return ""

    for image in (caa_data.get("images") or []):
        if not image.get("front", False):
            continue
        thumbnails = image.get("thumbnails") or {}
        return (
            thumbnails.get("500")
            or thumbnails.get("large")
            or image.get("image", "")
            or ""
        )
    return ""
