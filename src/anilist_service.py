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

# ── GraphQL queries ───────────────────────────────────────────────────────────

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
          title { userPreferred romaji }
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

_MANGA_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: MANGA) {
    lists {
      entries {
        id
        status
        score
        progress
        progressVolumes
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
          title { userPreferred romaji }
          format
          chapters
          volumes
          coverImage { large }
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

_SAVE_MANGA_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $progressVolumes:      Int,
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
    progressVolumes:      $progressVolumes,
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
    progressVolumes
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

_TOGGLE_FAVOURITE_MUTATION = """
mutation ($animeId: Int) {
  ToggleFavourite(animeId: $animeId) {
    anime {
      nodes { id }
    }
  }
}
"""

_ANIME_PAGE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    title {
      romaji
      english
      native
    }
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
    format
    episodes
    duration
    status
    startDate {
      day
      month
      year
    }
    endDate {
      day
      month
      year
    }
    averageScore
    meanScore
    popularity
    favourites
    isFavourite
    studios {
      nodes {
        name
        isAnimationStudio
      }
    }
    source
    hashtag
    genres
    synonyms
    tags {
      name
      rank
      isMediaSpoiler
    }
    externalLinks {
      site
      url
    }
    bannerImage
    coverImage {
      large
    }
    description
    relations {
      edges {
        relationType(version: 2)
        node {
          id
          type
          format
          title {
            romaji
            english
          }
          coverImage {
            large
          }
          status
        }
      }
    }
    characters(sort: [FAVOURITES_DESC, ROLE], perPage: 24) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    staff(sort: [FAVOURITES_DESC, ROLE], perPage: 6) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    recommendations(sort: [RATING_DESC], perPage: 20) {
      nodes {
        mediaRecommendation {
          id
          title {
            english
            native
            romaji
          }
          coverImage {
            large
          }
        }
      }
    }
  }
}
"""

_CHARACTER_PAGE_QUERY = """
query ($id: Int) {
  Character (id: $id) {
    name {
      first
      middle
      last
      full
      native
      alternative
      alternativeSpoiler
      userPreferred
    }
    image {
      large
    }
    description
    age
    bloodType
    isFavourite
    isFavouriteBlocked
    gender
    dateOfBirth {
      day
      month
      year
    }
    siteUrl
    media {
      nodes {
        id
        type
        title {
          english
          native
          romaji
        }
        coverImage {
          extraLarge
        }
      }
    }
  }
}
"""

_TOGGLE_CHARACTER_FAVOURITE_MUTATION = """
mutation ($characterId: Int) {
  ToggleFavourite(characterId: $characterId) {
    characters {
      nodes { id }
    }
  }
}
"""

# ── Helper functions ──────────────────────────────────────────────────────────

def _format_score(score: float, fmt: str) -> str:
    if score == 0:
        return ""
    if fmt == "POINT_100":
        return str(int(score))
    if fmt == "POINT_10_DECIMAL":
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
    mins    = (sec % 3600) // 60
    secs = sec % 60

    if days > 0:
        time_str = f"Ep. {next_ep} in {days}d"
    elif hrs > 0:
        time_str = f"Ep. {next_ep} in {hrs}h"
    elif mins > 0:
        time_str = f"Ep. {next_ep} in {mins}m"
    else:
        time_str = f"Ep. {next_ep} in {secs}s"

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
        "titleRomaji":           (media.get("title") or {}).get("romaji", ""),
        "mediaType":             media.get("format", "TV"),
        "cover":                 (media.get("coverImage") or {}).get("large", ""),
        "nextEpText":            _next_ep_text(status, next_airing, progress, total_episodes),
        "status":                status,
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


def _normalise_manga(entry: dict) -> dict:
    media  = entry.get("media") or {}
    status = entry.get("status", "CURRENT")
    return {
        "entryId":               entry.get("id", 0),
        "anilistId":             media.get("id", 0),
        "title":                 (media.get("title") or {}).get("userPreferred", "Unknown"),
        "titleRomaji":           (media.get("title") or {}).get("romaji", ""),
        "mediaType":             media.get("format", "MANGA"),
        "cover":                 (media.get("coverImage") or {}).get("large", ""),
        "status":                status,
        "score":                 entry.get("score", 0),
        "progress":              entry.get("progress", 0),
        "progressVolumes":       entry.get("progressVolumes", 0),
        "chapters":              media.get("chapters") or 0,
        "volumes":               media.get("volumes") or 0,
        "updatedAt":             entry.get("updatedAt", 0),
        "rewatches":             entry.get("repeat", 0),
        "notes":                 entry.get("notes", "") or "",
        "priority":              entry.get("priority", 0),
        "hiddenFromStatusLists": entry.get("hiddenFromStatusLists", False),
        "isPrivate":             entry.get("private", False),
        "startedAt":             _date_str(_fuzzy_date(entry.get("startedAt"))),
        "completedAt":           _date_str(_fuzzy_date(entry.get("completedAt"))),
    }


# ── Service class ─────────────────────────────────────────────────────────────

class AniListService(QObject):

    animeLoaded        = Signal(list)
    mangaLoaded        = Signal(list)
    userInfoReady      = Signal()
    loadingChanged     = Signal(bool)
    errorOccurred      = Signal(str)
    entrySaved         = Signal()
    mangaEntrySaved    = Signal()
    entryDeleted       = Signal()
    scoreFormatChanged = Signal(str)
    animePageLoaded    = Signal(int, str, str, str, str, str, bool, str, str)
    animeEntryLoaded   = Signal(int, str)   # JSON of entry fields, or {"onList": false}
    favouriteToggled   = Signal(int, bool)      # emitted after re-fetch is kicked off
    characterPageLoaded = Signal(str)
    characterFavouriteToggled = Signal(int, bool)

    def __init__(self, auth_manager, parent=None):
        super().__init__(parent)
        self._auth                  = auth_manager
        self._loading               = False
        self._loading_count         = 0
        self._score_format          = "POINT_10"
        self._entry_id_map:         dict[int, int]  = {}
        self._manga_entry_id_map:   dict[int, int]  = {}
        self._anime_entry_cache:    dict[int, dict] = {}  # anilistId → full normalised entry

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

    # ── Properties ────────────────────────────────────────────────────────────

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=scoreFormatChanged)
    def scoreFormat(self) -> str:
        return self._score_format

    # ── Internal ──────────────────────────────────────────────────────────────

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

    def _fetch_viewer(self) -> tuple[str, str]:
        """Fetch viewer info, update score format, return (uid, name)."""
        viewer = self._gql(_VIEWER_QUERY).get("Viewer") or {}
        uid    = str(viewer.get("id", ""))
        name   = viewer.get("name", "")
        self._auth.setUserInfo(uid, name)
        self.userInfoReady.emit()
        fmt = ((viewer.get("mediaListOptions") or {}).get("scoreFormat", "POINT_10"))
        if fmt != self._score_format:
            self._score_format = fmt
            self.scoreFormatChanged.emit(fmt)
        return uid, name

    # ── Anime slots ───────────────────────────────────────────────────────────

    @Slot()
    def fetchAnime(self) -> None:
        def _run():
            try:
                self._begin_loading()
                uid, _ = self._fetch_viewer()
                data    = self._gql(_ANIME_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = [
                    _normalise(e)
                    for lst in lists
                    for e in (lst.get("entries") or [])
                ]
                entries.sort(key=lambda e: e["updatedAt"], reverse=True)
                self._entry_id_map       = {e["anilistId"]: e["entryId"] for e in entries}
                self._anime_entry_cache  = {e["anilistId"]: e for e in entries}
                self.animeLoaded.emit(entries)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchAnimePage(self, anilist_id: int) -> None:
        def _run():
            try:
                self._begin_loading()
                data  = self._gql(_ANIME_PAGE_QUERY, {"id": anilist_id})
                media = data.get("Media") or {}

                title        = (media.get("title") or {}).get("romaji", "")
                banner       = media.get("bannerImage") or ""
                cover        = (media.get("coverImage") or {}).get("large", "")
                description  = media.get("description") or ""
                is_favourite = media.get("isFavourite", False)

                raw_relations: list = (media.get("relations") or {}).get("edges") or []
                relations = []
                for edge in raw_relations:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        title_obj = node.get("title") or {}
                        relations.append({
                            "mediaId":      node.get("id", 0),
                            "relationType": edge.get("relationType", ""),
                            "mediaType":    node.get("type", ""),
                            "format":       node.get("format", ""),
                            "title":        title_obj.get("english") or title_obj.get("romaji", ""),
                            "coverImage":   (node.get("coverImage") or {}).get("large", ""),
                            "status":       node.get("status", ""),
                        })

                raw_characters = (media.get("characters") or {}).get("edges") or []
                characters = []
                for edge in raw_characters:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        characters.append({
                            "characterId": node.get("id", 0),
                            "name":        (node.get("name") or {}).get("full", ""),
                            "nativeName":  (node.get("name") or {}).get("native", "") or "",
                            "image":       (node.get("image") or {}).get("large", ""),
                            "role":        edge.get("role", ""),
                        })

                raw_recommendation_nodes = (media.get("recommendations") or {}).get("nodes") or []
                recommendations = []
                for node in raw_recommendation_nodes:
                  if node.get("mediaRecommendation") is not None and node.get("mediaRecommendation") != {}:
                    media_recommendation = node["mediaRecommendation"]
                    title_obj = media_recommendation.get("title") or {}
                    recommendations.append({
                        "mediaId": media_recommendation.get("id", 0),
                        "title": title_obj.get("english") or title_obj.get("romaji", ""), 
                        "coverImage": (media_recommendation.get("coverImage") or {}).get("large", "")
                    })

                self.animePageLoaded.emit(
                    anilist_id, title, banner, cover, description,
                    json.dumps(relations), is_favourite,
                    json.dumps(characters),
                    json.dumps(recommendations)
                )
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchAnimeEntry(self, anilist_id: int) -> None:
        """Emit the cached list entry for this anime, or {"onList": false} if not on list."""
        entry = self._anime_entry_cache.get(anilist_id)
        print("fetchAnimeEntry called for:", anilist_id, "cache hit:", entry is not None)
        if not entry:
            self.animeEntryLoaded.emit(anilist_id, json.dumps({"onList": False}))
            return
        payload = dict(entry)
        payload["onList"] = True
        self.animeEntryLoaded.emit(anilist_id, json.dumps(payload))

    @Slot(int)
    def fetchCharacterPage(self, characterId: int) -> None:
        def _run():
            try:
                self._begin_loading()
                data      = self._gql(_CHARACTER_PAGE_QUERY, {"id": characterId})
                character = data.get("Character") or {}

                name_dict          = character.get("name") or {}
                name_full          = name_dict.get("full") or ""
                name_native        = name_dict.get("native") or ""
                name_user_preferred = name_dict.get("userPreferred") or ""
                # alternative is a list — keep it as one, serialise with the rest
                name_alternative   = name_dict.get("alternative") or []

                image              = (character.get("image") or {}).get("large", "")
                description        = character.get("description") or ""
                # age is a plain string on AniList ("17", "17-18", etc.), not an int
                age                = character.get("age") or ""
                blood_type         = character.get("bloodType") or ""
                is_favourite       = character.get("isFavourite", False)
                is_favourite_blocked = character.get("isFavouriteBlocked", False)
                gender             = character.get("gender") or ""
                date_of_birth      = _fuzzy_date(character.get("dateOfBirth"))
                site_url           = character.get("siteUrl") or ""

                # Media appearances — iterate each node in the list
                raw_media = (character.get("media") or {}).get("nodes") or []
                media = [
                    {
                        "mediaId": node.get("id", 0),
                        "type": node.get("type") or "",
                        "title":   (node.get("title") or {}).get("english")
                                  or (node.get("title") or {}).get("romaji", ""),
                        "cover":   (node.get("coverImage") or {}).get("extraLarge", ""),
                    }
                    for node in raw_media
                ]

                payload = {
                    "characterId":        characterId,
                    "nameFull":           name_full,
                    "nameNative":         name_native,
                    "nameUserPreferred":  name_user_preferred,
                    "nameAlternative":    name_alternative,   # list, serialised below
                    "image":              image,
                    "description":        description,
                    "age":                age,
                    "bloodType":          blood_type,
                    "isFavourite":        is_favourite,
                    "isFavouriteBlocked": is_favourite_blocked,
                    "gender":             gender,
                    "dateOfBirth":        _date_str(date_of_birth),
                    "siteUrl":            site_url,
                    "media":              media,              # list, serialised below
                }

                self.characterPageLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()


    @Slot(int, int, str)
    def saveProgress(self, media_id: int, progress: int, status: str) -> None:
        self._loading = True
        self.loadingChanged.emit(True)

        def _run():
            try:
                self._gql(_SAVE_ENTRY_MUTATION,
                          {"mediaId": media_id, "progress": progress, "status": status})
                self.entrySaved.emit()
            except Exception as exc:
                self._loading = False
                self.loadingChanged.emit(False)
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, str, float, str, str, int, str, int, bool, bool)
    def saveEntry(
        self,
        media_id:          int,
        progress:          int,
        status:            str,
        score:             float,
        started_at_json:   str,
        completed_at_json: str,
        rewatches:         int,
        notes:             str,
        priority:          int,
        hidden:            bool,
        private:           bool,
    ) -> None:
        variables = {
            "mediaId":               media_id,
            "status":                status,
            "score":                 score,
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
                self._anime_entry_cache.pop(media_id, None)
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

    @Slot(int, bool)
    def toggleFavourite(self, anilist_id: int, currently_favourite: bool) -> None:
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_FAVOURITE_MUTATION, {"animeId": anilist_id})
                self.favouriteToggled.emit(anilist_id, not currently_favourite)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, bool)
    def toggleCharacterFavourite(self, character_id: int, currently_favourite: bool) -> None:
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_CHARACTER_FAVOURITE_MUTATION, {"characterId": character_id})
                self.characterFavouriteToggled.emit(character_id, not currently_favourite)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()

    # ── Manga slots ───────────────────────────────────────────────────────────

    @Slot()
    def fetchManga(self) -> None:
        def _run():
            try:
                self._begin_loading()
                uid, _ = self._fetch_viewer()
                data    = self._gql(_MANGA_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = [
                    _normalise_manga(e)
                    for lst in lists
                    for e in (lst.get("entries") or [])
                ]
                entries.sort(key=lambda e: e["updatedAt"], reverse=True)
                self._manga_entry_id_map = {e["anilistId"]: e["entryId"] for e in entries}
                self.mangaLoaded.emit(entries)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, str)
    def saveMangaProgress(self, media_id: int, chapters: int, status: str) -> None:
        self._loading = True
        self.loadingChanged.emit(True)

        def _run():
            try:
                self._gql(_SAVE_MANGA_ENTRY_MUTATION,
                          {"mediaId": media_id, "progress": chapters, "status": status})
                self.mangaEntrySaved.emit()
            except Exception as exc:
                self._loading = False
                self.loadingChanged.emit(False)
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int)
    def saveMangaVolumeProgress(self, media_id: int, volumes: int) -> None:
        self._loading = True
        self.loadingChanged.emit(True)

        def _run():
            try:
                self._gql(_SAVE_MANGA_ENTRY_MUTATION,
                          {"mediaId": media_id, "progressVolumes": volumes})
                self.mangaEntrySaved.emit()
            except Exception as exc:
                self._loading = False
                self.loadingChanged.emit(False)
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, int, str, float, str, str, int, str, int, bool, bool)
    def saveMangaEntry(
        self,
        media_id:          int,
        chapters:          int,
        volumes:           int,
        status:            str,
        score:             float,
        started_at_json:   str,
        completed_at_json: str,
        rereads:           int,
        notes:             str,
        priority:          int,
        hidden:            bool,
        private:           bool,
    ) -> None:
        variables = {
            "mediaId":               media_id,
            "status":                status,
            "score":                 score,
            "progress":              chapters,
            "progressVolumes":       volumes,
            "repeat":                rereads,
            "notes":                 notes,
            "priority":              priority,
            "hiddenFromStatusLists": hidden,
            "private":               private,
            "startedAt":             _parse_date(started_at_json),
            "completedAt":           _parse_date(completed_at_json),
        }

        def _run():
            try:
                self._gql(_SAVE_MANGA_ENTRY_MUTATION, variables)
                self.mangaEntrySaved.emit()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def removeMangaEntry(self, media_id: int) -> None:
        entry_id = self._manga_entry_id_map.get(media_id)
        if not entry_id:
            self.errorOccurred.emit(
                f"Cannot remove: manga entry ID not found for media {media_id}. "
                "Try syncing first."
            )
            return

        def _run():
            try:
                self._gql(_DELETE_ENTRY_MUTATION, {"id": entry_id})
                self._manga_entry_id_map.pop(media_id, None)
                self.entryDeleted.emit()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
        threading.Thread(target=_run, daemon=True).start()

    # ── QML-callable helpers ──────────────────────────────────────────────────

    @Slot(float, result=str)
    def formatScore(self, score: float) -> str:
        return _format_score(score, self._score_format)

    @Slot(result=float)
    def scoreMax(self) -> float:
        return {
            "POINT_100":        100.0,
            "POINT_10_DECIMAL": 10.0,
            "POINT_10":         10.0,
            "POINT_5":          5.0,
            "POINT_3":          3.0,
        }.get(self._score_format, 10.0)
