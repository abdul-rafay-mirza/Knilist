"""
anilist_service.py — AniList GraphQL client exposed as a QML context property.
"""

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
mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
  SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) {
    id
    progress
    status
  }
}
"""


def _next_ep_text(status: str, next_airing: dict | None) -> str:
    if status == "COMPLETED":
        return "Finished"
    if not next_airing:
        return "TBA"
    sec  = next_airing.get("timeUntilAiring", 0)
    ep   = next_airing.get("episode", "?")
    days = sec // 86400
    hrs  = (sec % 86400) // 3600
    if days > 0:
        return f"Ep. {ep} in {days}d"
    if hrs > 0:
        return f"Ep. {ep} in {hrs}h"
    return f"Ep. {ep} airing soon"


def _normalise(entry: dict) -> dict:
    media       = entry.get("media") or {}
    status      = entry.get("status", "CURRENT")
    next_airing = media.get("nextAiringEpisode")
    return {
        "entryId":    entry.get("id", 0),
        "anilistId":  media.get("id", 0),
        "title":      (media.get("title") or {}).get("userPreferred", "Unknown"),
        "mediaType":  media.get("format", "TV"),
        "cover":      (media.get("coverImage") or {}).get("large", ""),
        "nextEpText": _next_ep_text(status, next_airing),
        "status":     status,
        "score":      entry.get("score", 0),
        "progress":   entry.get("progress", 0),
        "episodes":   media.get("episodes") or 0,
    }


class AniListService(QObject):
    animeLoaded    = Signal(list)
    userInfoReady  = Signal()
    loadingChanged = Signal(bool)
    errorOccurred  = Signal(str)

    def __init__(self, auth_manager, parent=None):
        super().__init__(parent)
        self._auth    = auth_manager
        self._loading = False

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

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

                data    = self._gql(_ANIME_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = [
                    _normalise(e)
                    for lst in lists
                    for e in (lst.get("entries") or [])
                ]
                self.animeLoaded.emit(entries)

            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._loading = False
                self.loadingChanged.emit(False)

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, str)
    def saveProgress(self, media_id: int, progress: int, status: str) -> None:
        def _run():
            try:
                self._gql(_SAVE_ENTRY_MUTATION,
                          {"mediaId": media_id, "progress": progress, "status": status})
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()
