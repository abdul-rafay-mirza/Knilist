"""
anime_themes_service.py — animethemes.moe GraphQL client exposed as a QML
context property. Split out from anilist_service.py: this talks to a
completely different GraphQL endpoint (graphql.animethemes.moe) with its
own schema, and orchestrates musicbrainz_cover_art.py for album art —
neither has anything to do with AniList itself, so it doesn't belong on
AniListService.

Deliberately its own QObject with its own loading state rather than a
method bolted onto AniListService or a class that wraps/composes it:
AnimePage.qml already tracks animeThemesLoading as a page-local property
distinct from anything AniList reports (see AnimePage.qml's
_loadAnimeData), so this mirrors that separation at the Python level
instead of reintroducing coupling one layer down.
"""

import json
import threading
import requests
from PySide6.QtCore import QObject, Signal, Slot, Property
from .graphql_queries import _OPENING_AND_ENDING_SONGS_QUERY
from .musicbrainz_cover_art import get_album_art_for_song
from .config import ANIMETHEMES_GRAPHQL_URL


def _flatten_anime_themes(themes: list | None) -> list[dict]:
    """Flatten animethemes.moe's `animethemes` (OP/ED songs) into plain
    dicts for the QML side. This is a different API/response shape than
    AniList's own — a theme (e.g. "OP1") can have more than one entry
    when it covers different episode ranges or versions, and each entry
    can have more than one video variant (resolution, subbed/unsubbed) —
    both are kept as lists rather than picking a "best" one here, so QML
    decides.

    Deliberately does NO network I/O — this stays a pure flattening step.
    `albumArt` is always emitted as "" here; fetchOpeningEndingSongs()
    resolves the real value afterward via musicbrainz_cover_art and pushes
    it to QML per-theme through themeAlbumArtLoaded, since resolving every
    theme's art costs a real (rate-limited) network round trip per song and
    would otherwise stall the initial theme list by several seconds."""
    result = []
    for theme in themes or []:
        song = theme.get("song") or {}

        artists = []
        for perf in (song.get("performances") or []):
            artist = perf.get("artist") or {}
            name   = artist.get("name") or ""
            if name:
                images = []
                for img in ((artist.get("images") or {}).get("nodes") or []):
                    images.append({
                        "link":  img.get("link", "") or "",
                        "facet": img.get("facet", "") or "",
                    })
                artists.append({
                    "name":   name,
                    "images": images,
                })

        entries = []
        for entry in (theme.get("animethemeentries") or []):
            videos = []
            for video in ((entry.get("videos") or {}).get("nodes") or []):
                audio = video.get("audio") or {}
                videos.append({
                    "basename":   video.get("basename", "") or "",
                    "mimetype":   video.get("mimetype", "") or "",
                    "source":     video.get("source", "") or "",
                    "resolution": video.get("resolution") or 0,
                    "size":       video.get("size") or 0,
                    "subbed":     video.get("subbed", False),
                    "videoLink":  video.get("link", "") or "",
                    "audioLink":  audio.get("link", "") or "",
                    "audioSize":  audio.get("size") or 0,
                })
            entries.append({
                "episodes": entry.get("episodes", "") or "",
                "videos":   videos,
            })

        result.append({
            "themeId":     theme.get("id", 0),
            "type":        theme.get("type", "") or "",
            "songTitle":   song.get("title", "") or "",
            "artists":     artists,                       # list of {name, images}
            "artistsText": ", ".join(a["name"] for a in artists),  # convenience string for QML display
            "entries":     entries,
            "albumArt":    "",   # filled in later via themeAlbumArtLoaded — see docstring
        })
    return result


class AnimeThemesService(QObject):

    openingEndingSongsLoaded = Signal(int, str)   # anilistId, JSON {"themes": [...], "isError": bool}
    themeAlbumArtLoaded      = Signal(int, int, str)   # anilistId, themeId, albumArtUrl ("" = none found)
    loadingChanged           = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._loading       = False
        self._loading_count = 0

    def _begin_loading(self):
        self._loading_count += 1
        if not self._loading:
            self._loading = True
            self.loadingChanged.emit(True)

    def _end_loading(self):
        self._loading_count -= 1
        if self._loading_count <= 0:
            self._loading_count = 0
            self._loading = False
            self.loadingChanged.emit(False)

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Slot(int)
    def fetchOpeningEndingSongs(self, anilist_id: int) -> None:
        """OP/ED video+audio links for an anime, from animethemes.moe — a
        separate GraphQL endpoint from AniList's own. Not used anywhere
        else, so we post to it directly here instead of growing a second
        `_gql`-style helper for one call site.

        Album art is resolved as a SECOND, separate step after the theme
        list itself is emitted: MusicBrainz enforces 1 request/sec (see
        musicbrainz_cover_art.py), so resolving art for e.g. 4 themes
        (OP1/OP2/ED1/ED2) up front would add several seconds before the
        user sees anything. Instead, the theme list appears immediately
        with albumArt: "" on every theme, and themeAlbumArtLoaded fires
        once per theme as each lookup completes, letting QML patch in
        each card's art as it arrives rather than waiting on all of them."""
        def _run():
            try:
                self._begin_loading()
                resp = requests.post(
                    ANIMETHEMES_GRAPHQL_URL,
                    json={
                        "query":     _OPENING_AND_ENDING_SONGS_QUERY,
                        "variables": {"id": [anilist_id]},
                    },
                    headers={"Content-Type": "application/json", "Accept": "application/json"},
                    timeout=15,
                )
                resp.raise_for_status()
                body = resp.json()
                if "errors" in body:
                    raise RuntimeError(body["errors"][0]["message"])

                matches = (body.get("data") or {}).get("findAnimeByExternalSite") or []
                first   = (matches[0] or {}) if matches else {}
                themes  = first.get("animethemes") or []
                flattened = _flatten_anime_themes(themes)

                self.openingEndingSongsLoaded.emit(anilist_id, json.dumps({
                    "themes":  flattened,
                    "isError": False,
                }))

                # Album art is best-effort and can take a few seconds across
                # several themes (rate-limited to 1 MusicBrainz call/sec) —
                # deliberately NOT covered by _begin_loading/_end_loading,
                # since per the progressive-loading design this should never
                # hold up or re-trigger the section's own loading spinner.
                self._resolve_theme_album_art(anilist_id, flattened)
            except Exception as exc:
                # No errorOccurred-style signal here (that belonged to
                # AniListService's global "Network Issue" toast plumbing).
                # The failure path is instead fully carried by isError in
                # the payload below — AnimePage.qml's onOpeningEndingSongsLoaded
                # already reads payload.isError into animeThemesError, and
                # OpeningEndingThemesSection already renders that state, so
                # nothing upstream needs a second failure channel. Printed
                # here purely for local debugging, matching how
                # musicbrainz_cover_art.py already treats its own failures
                # as "log and degrade quietly" rather than surfacing them.
                print(f"[AnimeThemesService] fetch failed: {exc}")
                self.openingEndingSongsLoaded.emit(anilist_id, json.dumps({
                    "themes":  [],
                    "isError": True,
                }))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    def _resolve_theme_album_art(self, anilist_id: int, flattened_themes: list[dict]) -> None:
        """Runs on its own daemon thread (separate from fetchOpeningEndingSongs's
        _run, which has already returned/emitted by the time this starts).
        Resolves each theme's album art one at a time — sequential on
        purpose, since get_album_art_for_song() is already internally
        rate-limited to 1 MusicBrainz call/sec, so parallelizing this loop
        would only mean threads blocking on the same limiter, not real
        concurrency. A failure resolving ONE theme's art (network error,
        no MusicBrainz match, no cover art on file) never raises — it just
        means that theme's card keeps showing the artist photo instead,
        exactly as it did before this feature existed."""
        def _run():
            for theme in flattened_themes:
                theme_id    = theme.get("themeId", 0)
                song_title  = theme.get("songTitle", "")
                artists     = theme.get("artists") or []
                artist_name = artists[0]["name"] if artists else ""

                album_art = get_album_art_for_song(song_title, artist_name)
                if album_art:
                    self.themeAlbumArtLoaded.emit(anilist_id, theme_id, album_art)

        threading.Thread(target=_run, daemon=True).start()
