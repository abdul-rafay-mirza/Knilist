"""
anilist_service.py — AniList GraphQL client exposed as a QML context property.

IMPORTANT — AniList score semantics:
  The `score` field in both queries AND mutations is always in the user's
  chosen display format (scoreFormat). There is NO internal 0-100 scale on
  the v2 API. Whatever number the user types is sent directly to AniList.
  We only need scoreFormat to know how to *display* and *validate* the value.
"""

import json
import threading
import requests
from PySide6.QtCore import QObject, Signal, Slot, Property

from .config import GRAPHQL_URL

_VIEWER_QUERY = """
query {
  Viewer {
    id
    name
    avatar { large }
    mediaListOptions {
      scoreFormat
    }
  }
}
"""

_ANIME_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: ANIME) {
    lists {
      entries {
        id
        status
        score
        progress
        repeat
        notes
        priority
        hiddenFromStatusLists
        private
        startedAt  { year month day }
        completedAt { year month day }
        updatedAt
        media {
          id
          title { userPreferred }
          format
          episodes
          coverImage { large }
          nextAiringEpisode {
            episode
            timeUntilAiring
          }
        }
      }
    }
  }
}
"""

_SAVE_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $repeat:               Int,
  $notes:                String,
  $priority:             Int,
  $hiddenFromStatusLists: Boolean,
  $private:              Boolean,
  $startedAt:            FuzzyDateInput,
  $completedAt:          FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId:              $mediaId,
    status:               $status,
    score:                $score,
    progress:             $progress,
    repeat:               $repeat,
    notes:                $notes,
    priority:             $priority,
    hiddenFromStatusLists: $hiddenFromStatusLists,
    private:              $private,
    startedAt:            $startedAt,
    completedAt:          $completedAt
  ) {
    id
    progress
    status
    score
  }
}
"""

_DELETE_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""


def _format_score(score: float, fmt: str) -> str:
    """
    Return a display string for a score value that is already in the user's
    chosen format (i.e. straight from the AniList API, no conversion needed).
    Returns "" when score is 0 (unrated).
    """
    if score == 0:
        return ""
    if fmt == "POINT_100":
        return str(int(score))
    if fmt == "POINT_10_DECIMAL":
        # Show one decimal only when there is a fractional part
        return f"{score:.1f}" if score != int(score) else str(int(score))
    if fmt == "POINT_10":
        return str(int(score))
    if fmt == "POINT_5":
        n = int(score)
        return "★" * n + "☆" * (5 - n)
    if fmt == "POINT_3":
        return {1: ":(", 2: ":|", 3: ":)"}.get(int(score), "")
    return str(score)


def _next_ep_text(status: str, next_airing: dict | None,
                  progress: int, total_episodes: int) -> str:
    if status == "COMPLETED":
        return "Finished"
    if not next_airing:
        if total_episodes > 0:
            behind = total_episodes - progress
            if behind == 1:
                return "Finished airing · 1 episode left"
            if behind > 1:
                return f"Finished airing · {behind} episodes left"
            return "Finished airing"
        return "TBA"

    sec     = next_airing.get("timeUntilAiring", 0)
    next_ep = next_airing.get("episode", 0)
    days    = sec // 86400
    hrs     = (sec % 86400) // 3600

    if days > 0:
        time_str = f"Ep. {next_ep} in {days}d"
    elif hrs > 0:
        time_str = f"Ep. {next_ep} in {hrs}h"
    else:
        time_str = f"Ep. {next_ep} airing soon"

    behind = (next_ep - 1) - progress
    if behind == 1:
        return f"{time_str} · You are 1 episode behind"
    if behind > 1:
        return f"{time_str} · You are {behind} episodes behind"
    return time_str


def _fuzzy_date(d: dict | None) -> dict | None:
    if not d:
        return None
    y = d.get("year") or 0
    if y == 0:
        return None
    return {"year": y, "month": d.get("month") or 1, "day": d.get("day") or 1}


def _date_str(d: dict | None) -> str:
    if not d or not d.get("year"):
        return ""
    return f"{d['year']:04d}-{d.get('month', 1):02d}-{d.get('day', 1):02d}"


def _normalise(entry: dict) -> dict:
    media          = entry.get("media") or {}
    status         = entry.get("status", "CURRENT")
    next_airing    = media.get("nextAiringEpisode")
    progress       = entry.get("progress", 0)
    total_episodes = media.get("episodes") or 0
    return {
        "entryId":               entry.get("id", 0),
        "anilistId":             media.get("id", 0),
        "title":                 (media.get("title") or {}).get("userPreferred", "Unknown"),
        "mediaType":             media.get("format", "TV"),
        "cover":                 (media.get("coverImage") or {}).get("large", ""),
        "nextEpText":            _next_ep_text(status, next_airing, progress, total_episodes),
        "status":                status,
        # score is stored exactly as AniList returns it (already in display format)
        "score":                 entry.get("score", 0),
        "progress":              progress,
        "episodes":              total_episodes,
        "updatedAt":             entry.get("updatedAt", 0),
        "rewatches":             entry.get("repeat", 0),
        "notes":                 entry.get("notes", "") or "",
        "priority":              entry.get("priority", 0),
        "hiddenFromStatusLists": entry.get("hiddenFromStatusLists", False),
        "isPrivate":             entry.get("private", False),
        "startedAt":             _date_str(_fuzzy_date(entry.get("startedAt"))),
        "completedAt":           _date_str(_fuzzy_date(entry.get("completedAt"))),
    }


class AniListService(QObject):
    animeLoaded        = Signal(list)
    userInfoReady      = Signal()
    loadingChanged     = Signal(bool)
    errorOccurred      = Signal(str)
    entrySaved         = Signal()
    entryDeleted       = Signal()
    scoreFormatChanged = Signal(str)

    def __init__(self, auth_manager, parent=None):
        super().__init__(parent)
        self._auth         = auth_manager
        self._loading      = False
        self._score_format = "POINT_10"          # safe default until login
        self._entry_id_map: dict[int, int] = {}

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=scoreFormatChanged)
    def scoreFormat(self) -> str:
        return self._score_format

    def _gql(self, query: str, variables: dict | None = None) -> dict:
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        token = self._auth.token()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        resp = requests.post(
            GRAPHQL_URL,
            json={"query": query, "variables": variables or {}},
            headers=headers,
            timeout=15,
        )
        resp.raise_for_status()
        body = resp.json()
        if "errors" in body:
            raise RuntimeError(body["errors"][0]["message"])
        return body["data"]

    @Slot()
    def fetchAll(self) -> None:
        def _run():
            try:
                self._loading = True
                self.loadingChanged.emit(True)

                viewer = self._gql(_VIEWER_QUERY).get("Viewer") or {}
                uid    = str(viewer.get("id", ""))
                name   = viewer.get("name", "")
                self._auth.setUserInfo(uid, name)
                self.userInfoReady.emit()

                fmt = (
                    (viewer.get("mediaListOptions") or {})
                    .get("scoreFormat", "POINT_10")
                )
                if fmt != self._score_format:
                    self._score_format = fmt
                    self.scoreFormatChanged.emit(fmt)

                data    = self._gql(_ANIME_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = [
                    _normalise(e)
                    for lst in lists
                    for e in (lst.get("entries") or [])
                ]
                entries.sort(key=lambda e: e["updatedAt"], reverse=True)
                self._entry_id_map = {e["anilistId"]: e["entryId"] for e in entries}
                self.animeLoaded.emit(entries)

            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._loading = False
                self.loadingChanged.emit(False)

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, str)
    def saveProgress(self, media_id: int, progress: int, status: str) -> None:
        # Set loading immediately on the calling (QML) thread so the overlay
        # appears the instant the button is clicked, before the thread starts.
        self._loading = True
        self.loadingChanged.emit(True)

        def _run():
            try:
                self._gql(_SAVE_ENTRY_MUTATION,
                          {"mediaId": media_id, "progress": progress, "status": status})
                self.entrySaved.emit()   # triggers fetchAll in AnimePage
            except Exception as exc:
                self._loading = False
                self.loadingChanged.emit(False)
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    # score is passed as-is in the user's format — AniList handles it directly.
    @Slot(int, int, str, float, str, str, int, str, int, bool, bool)
    def saveEntry(
        self,
        media_id:          int,
        progress:          int,
        status:            str,
        score:             float,   # in user's display format, sent straight to AniList
        started_at_json:   str,
        completed_at_json: str,
        rewatches:         int,
        notes:             str,
        priority:          int,
        hidden:            bool,
        private:           bool,
    ) -> None:
        def _parse_date(s: str) -> dict | None:
            if not s:
                return None
            try:
                d = json.loads(s)
                return {"year": d.get("year", 0),
                        "month": d.get("month", 1),
                        "day":   d.get("day", 1)}
            except Exception:
                return None

        variables = {
            "mediaId":               media_id,
            "status":                status,
            "score":                 score,      # no conversion — AniList format passthrough
            "progress":              progress,
            "repeat":                rewatches,
            "notes":                 notes,
            "priority":              priority,
            "hiddenFromStatusLists": hidden,
            "private":               private,
            "startedAt":             _parse_date(started_at_json),
            "completedAt":           _parse_date(completed_at_json),
        }

        def _run():
            try:
                self._gql(_SAVE_ENTRY_MUTATION, variables)
                self.entrySaved.emit()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def removeEntry(self, media_id: int) -> None:
        entry_id = self._entry_id_map.get(media_id)
        if not entry_id:
            self.errorOccurred.emit(
                f"Cannot remove: entry ID not found for media {media_id}. "
                "Try syncing first."
            )
            return

        def _run():
            try:
                self._gql(_DELETE_ENTRY_MUTATION, {"id": entry_id})
                self._entry_id_map.pop(media_id, None)
                self.entryDeleted.emit()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, float)
    def saveScore(self, media_id: int, score: float) -> None:
        def _run():
            try:
                self._gql(_SAVE_ENTRY_MUTATION, {
                    "mediaId": media_id,
                    "score":   score,
                })
                self.entrySaved.emit()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    # ── QML-callable helpers ──────────────────────────────────────────────────

    @Slot(float, result=str)
    def formatScore(self, score: float) -> str:
        """Format a score value (already in the user's format) for display."""
        return _format_score(score, self._score_format)

    @Slot(result=float)
    def scoreMax(self) -> float:
        """Return the maximum valid score value for the current format."""
        return {
            "POINT_100":        100.0,
            "POINT_10_DECIMAL": 10.0,
            "POINT_10":         10.0,
            "POINT_5":          5.0,
            "POINT_3":          3.0,
        }.get(self._score_format, 10.0)
