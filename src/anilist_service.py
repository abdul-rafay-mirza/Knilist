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
from .graphql_queries import (
    _VIEWER_QUERY, _ANIME_LIST_QUERY, _MANGA_LIST_QUERY,
    _SAVE_ANIME_ENTRY_MUTATION, _SAVE_MANGA_ENTRY_MUTATION,
    _DELETE_ANIME_ENTRY_MUTATION, _DELETE_MANGA_ENTRY_MUTATION,
    _TOGGLE_FAVOURITE_MUTATION, _ANIME_PAGE_QUERY,
    _CHARACTER_PAGE_QUERY, _TOGGLE_CHARACTER_FAVOURITE_MUTATION,
    _STAFF_PAGE_QUERY, _STAFF_PAGE_NEXT_QUERY, _TOGGLE_STAFF_FAVOURITE_MUTATION,
    _ANIME_FAVOURITE_QUERY, _CHARACTER_FAVOURITE_QUERY, _STAFF_FAVOURITE_QUERY,
)

# Helper functions

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

def _format_duration(sec: int) -> str:
    days = sec // 86400
    hrs  = (sec % 86400) // 3600
    mins = (sec % 3600) // 60
    parts = []
    if days: parts.append(f"{days}d")
    if hrs:  parts.append(f"{hrs}h")
    if mins: parts.append(f"{mins}m")
    return " ".join(parts) if parts else "< 1m"


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
    time_str = f"Ep. {next_ep} in {_format_duration(sec)}"

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

# Service class

class AniListService(QObject):

    animeLoaded        = Signal(list)
    mangaLoaded        = Signal(list)
    userInfoReady      = Signal()
    loadingChanged     = Signal(bool)
    errorOccurred      = Signal(str)
    animeEntrySaved    = Signal()
    mangaEntrySaved    = Signal()
    animeEntryDeleted  = Signal()
    mangaEntryDeleted  = Signal()
    scoreFormatChanged = Signal(str)
    animePageLoaded    = Signal(int, str, str, str, str, str, bool, str, str, str, str)
    animeEntryLoaded   = Signal(int, str)   # JSON of entry fields, or {"onList": false}
    animeFavouriteToggled   = Signal(int, bool)      # emitted after re-fetch is kicked off
    characterPageLoaded = Signal(str)
    characterFavouriteToggled = Signal(int, bool)
    staffPageLoaded           = Signal(str)   # full JSON payload
    staffFavouriteToggled     = Signal(int, bool)
    staffPageMoreLoaded = Signal(str)

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

    def _emit_update_failure(self, exc: Exception) -> None:
        """Every write-mutation failure surfaces this one message to the UI.
        The real exception is printed for debugging, never shown to the user."""
        print(f"[AniListService] update failed: {exc}")
        self.errorOccurred.emit("Network Issue: Failed to update show.")

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

    # Anime slots

    @Slot()
    def fetchAnime(self) -> None:
        def _run():
            try:
                self._begin_loading()
                uid, _ = self._fetch_viewer()
                data    = self._gql(_ANIME_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = []
                for lst in lists:
                    for e in (lst.get("entries") or []):
                        media          = e.get("media") or {}
                        status         = e.get("status", "CURRENT")
                        next_airing    = media.get("nextAiringEpisode")
                        progress       = e.get("progress", 0)
                        total_episodes = media.get("episodes") or 0
                        title_obj      = media.get("title") or {}
                        title          = title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or ""
                        entries.append({
                            "entryId":               e.get("id", 0),
                            "anilistId":             media.get("id", 0),
                            "title":                 title,
                            "titleRomaji":           title_obj.get("romaji", ""),
                            "mediaType":             media.get("format", "TV"),
                            "cover":                 (media.get("coverImage") or {}).get("large", ""),
                            "nextEpText":            _next_ep_text(status, next_airing, progress, total_episodes),
                            "status":                status,
                            "score":                 e.get("score", 0),
                            "progress":              progress,
                            "episodes":              total_episodes,
                            "updatedAt":             e.get("updatedAt", 0),
                            "rewatches":             e.get("repeat", 0),
                            "notes":                 e.get("notes", "") or "",
                            "priority":              e.get("priority", 0),
                            "hiddenFromStatusLists": e.get("hiddenFromStatusLists", False),
                            "isPrivate":             e.get("private", False),
                            "startedAt":             _date_str(_fuzzy_date(e.get("startedAt"))),
                            "completedAt":           _date_str(_fuzzy_date(e.get("completedAt"))),
                        })
                entries.sort(key=lambda e: e["updatedAt"], reverse=True)
                self._entry_id_map      = {e["anilistId"]: e["entryId"] for e in entries}
                self._anime_entry_cache = {e["anilistId"]: e for e in entries}
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

                title_obj = media.get("title") or {}
                title     = title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or ""
                banner       = media.get("bannerImage") or ""
                cover        = (media.get("coverImage") or {}).get("large", "")
                description  = media.get("description") or ""
                is_favourite = media.get("isFavourite", False)
                print(f"[fetchAnimePage] {anilist_id} raw isFavourite from AniList: {is_favourite}")

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
                
                raw_staff_edges = (media.get("staff") or {}).get("edges") or []
                staff = []
                for edge in raw_staff_edges:
                  if edge.get("node") is not None and edge.get("node") != {}:
                    node = edge["node"]
                    staff.append({
                      "role": edge.get("role", ""),
                      "id": node.get("id", 0),
                      "name": (node.get("name") or {}).get("full") or (node.get("name") or {}).get("native", ""),
                      "image": (node.get("image") or {}).get("large", "")
                    })

                next_airing    = media.get("nextAiringEpisode") or {}
                status         = media.get("status") or ""
                studios_nodes  = (media.get("studios") or {}).get("nodes") or []

                information = {
                    "status":             status,
                    "format":             media.get("format") or "",
                    "episodes":           media.get("episodes") or 0,
                    "duration":           media.get("duration") or 0,
                    "startDate":          _date_str(_fuzzy_date(media.get("startDate"))),
                    "endDate":            _date_str(_fuzzy_date(media.get("endDate"))),
                    "season":             media.get("season") or "",
                    "seasonYear":         media.get("seasonYear") or 0,
                    "averageScore":       media.get("averageScore") or 0,
                    "meanScore":          media.get("meanScore") or 0,
                    "popularity":         media.get("popularity") or 0,
                    "favourites":         media.get("favourites") or 0,
                    "source":             media.get("source") or "",
                    "hashtag":            media.get("hashtag") or "",
                    "genres":             media.get("genres") or [],
                    "synonyms":           media.get("synonyms") or [],
                    "studios":   list(dict.fromkeys(s["name"] for s in studios_nodes if     s.get("isAnimationStudio"))),
                    "producers": list(dict.fromkeys(s["name"] for s in studios_nodes if not s.get("isAnimationStudio"))),
                    "titleRomaji":        (media.get("title") or {}).get("romaji")  or "",
                    "titleEnglish":       (media.get("title") or {}).get("english") or "",
                    "titleNative":        (media.get("title") or {}).get("native")  or "",
                    # Airing — only populated when RELEASING
                    "nextAiringEpisode":  next_airing.get("episode", 0),
                    "timeUntilAiring":    _format_duration(next_airing.get("timeUntilAiring", 0))
                                          if (status == "RELEASING" and next_airing) else "",
                }

                self.animePageLoaded.emit(
                    anilist_id, title, banner, cover, description,
                    json.dumps(relations), is_favourite,
                    json.dumps(characters),
                    json.dumps(recommendations),
                    json.dumps(staff),
                    json.dumps(information)
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
                name_altrnative_spoiler = name_dict.get("alternativeSpoiler") or []

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

                raw_media_edges = (character.get("media") or {}).get("edges") or []
                media: list[dict] = []
                va_dict: dict[int, dict] = {}

                for edge in raw_media_edges:
                    node = edge.get("node")
                    if not node:
                        continue
                    title_obj = node.get("title") or {}
                    media.append({
                        "mediaId": node.get("id", 0),
                        "type":    node.get("type") or "",
                        "title":   title_obj.get("english") or title_obj.get("romaji", ""),
                        "cover":   (node.get("coverImage") or {}).get("extraLarge", ""),
                    })
                    for va in (edge.get("voiceActors") or []):
                        va_id = va.get("id", 0)
                        if va_id and va_id not in va_dict:
                            name_obj = va.get("name") or {}
                            va_dict[va_id] = {
                                "staffId":    va_id,
                                "name":       name_obj.get("userPreferred") or name_obj.get("full", ""),
                                "nameNative": name_obj.get("native", ""),
                                "image":      (va.get("image") or {}).get("large", ""),
                                "language":   va.get("languageV2", ""),
                            }

                voice_actors = list(va_dict.values())

                payload = {
                    "characterId":        characterId,
                    "nameFull":           name_full,
                    "nameNative":         name_native,
                    "nameUserPreferred":  name_user_preferred,
                    "nameAlternative":    name_alternative,   # list, serialised below
                    "nameAlternativeSpoiler": name_altrnative_spoiler,
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
                    "voiceActors": voice_actors
                }

                self.characterPageLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchStaffPage(self, staff_id: int) -> None:
        def _run():
            try:
                self._begin_loading()
                data  = self._gql(_STAFF_PAGE_QUERY, {"id": staff_id})
                staff = data.get("Staff") or {}

                name_dict     = staff.get("name") or {}
                date_of_birth = _fuzzy_date(staff.get("dateOfBirth"))
                date_of_death = _fuzzy_date(staff.get("dateOfDeath"))

                sm_conn        = staff.get("staffMedia") or {}
                media_has_next = (sm_conn.get("pageInfo") or {}).get("hasNextPage", False)
                staff_media    = []
                for edge in (sm_conn.get("edges") or []):
                    node = edge.get("node")
                    if not node:
                        continue
                    title_obj = node.get("title") or {}
                    staff_media.append({
                        "staffRole":  edge.get("staffRole", ""),
                        "mediaId":    node.get("id", 0),
                        "type":       node.get("type", ""),
                        "title":      (title_obj.get("userPreferred")
                                    or title_obj.get("english")
                                    or title_obj.get("romaji", "")),
                        "coverImage": (node.get("coverImage") or {}).get("large", ""),
                    })

                ch_conn       = staff.get("characters") or {}
                char_has_next = (ch_conn.get("pageInfo") or {}).get("hasNextPage", False)
                characters    = []
                for edge in (ch_conn.get("edges") or []):
                    char_node = edge.get("node")
                    if not char_node:
                        continue
                    char_name  = char_node.get("name") or {}
                    char_media = []
                    for m in (edge.get("media") or []):
                        if not m:
                            continue
                        t = m.get("title") or {}
                        char_media.append({
                            "mediaId":    m.get("id", 0),
                            "title":      (t.get("userPreferred") or t.get("english") or t.get("romaji", "")),
                            "coverImage": (m.get("coverImage") or {}).get("large", ""),
                        })
                    characters.append({
                        "characterId": char_node.get("id", 0),
                        "name":        (char_name.get("userPreferred") or char_name.get("full", "")),
                        "nameNative":  char_name.get("native", ""),
                        "image":       (char_node.get("image") or {}).get("large", ""),
                        "media":       char_media,
                    })

                age_raw = staff.get("age")
                payload = {
                    "staffId":            staff_id,
                    "nameUserPreferred":  name_dict.get("userPreferred", ""),
                    "nameFull":           name_dict.get("full", ""),
                    "nameNative":         name_dict.get("native", ""),
                    "nameAlternative":    name_dict.get("alternative") or [],
                    "image":              (staff.get("image") or {}).get("large", ""),
                    "description":        staff.get("description") or "",
                    "language":           staff.get("languageV2") or "",
                    "primaryOccupations": staff.get("primaryOccupations") or [],
                    "gender":             staff.get("gender") or "",
                    "age":                str(age_raw) if age_raw else "",
                    "yearsActive":        staff.get("yearsActive") or [],
                    "homeTown":           staff.get("homeTown") or "",
                    "bloodType":          staff.get("bloodType") or "",
                    "isFavourite":        staff.get("isFavourite", False),
                    "isFavouriteBlocked": staff.get("isFavouriteBlocked", False),
                    "dateOfBirth":        _date_str(date_of_birth),
                    "dateOfDeath":        _date_str(date_of_death),
                    "siteUrl":            staff.get("siteUrl") or "",
                    "staffMedia":         staff_media,
                    "characters":         characters,
                    "mediaHasNext":       media_has_next,
                    "charHasNext":        char_has_next,
                }
                self.staffPageLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, int)
    def fetchStaffPageMore(self, staff_id: int, media_page: int, char_page: int) -> None:
        def _run():
            try:
                data  = self._gql(_STAFF_PAGE_NEXT_QUERY, {
                    "id":        staff_id,
                    "mediaPage": media_page if media_page > 0 else 1,
                    "charPage":  char_page  if char_page  > 0 else 1,
                })
                staff = data.get("Staff") or {}

                staff_media    = []
                media_has_next = False
                if media_page > 0:
                    sm_conn        = staff.get("staffMedia") or {}
                    media_has_next = (sm_conn.get("pageInfo") or {}).get("hasNextPage", False)
                    for edge in (sm_conn.get("edges") or []):
                        node = edge.get("node")
                        if not node:
                            continue
                        title_obj = node.get("title") or {}
                        staff_media.append({
                            "staffRole":  edge.get("staffRole", ""),
                            "mediaId":    node.get("id", 0),
                            "type":       node.get("type", ""),
                            "title":      (title_obj.get("userPreferred")
                                        or title_obj.get("english")
                                        or title_obj.get("romaji", "")),
                            "coverImage": (node.get("coverImage") or {}).get("large", ""),
                        })

                characters    = []
                char_has_next = False
                if char_page > 0:
                    ch_conn       = staff.get("characters") or {}
                    char_has_next = (ch_conn.get("pageInfo") or {}).get("hasNextPage", False)
                    for edge in (ch_conn.get("edges") or []):
                        char_node = edge.get("node")
                        if not char_node:
                            continue
                        char_name  = char_node.get("name") or {}
                        char_media = []
                        for m in (edge.get("media") or []):
                            if not m:
                                continue
                            t = m.get("title") or {}
                            char_media.append({
                                "mediaId":    m.get("id", 0),
                                "title":      (t.get("userPreferred") or t.get("english") or t.get("romaji", "")),
                                "coverImage": (m.get("coverImage") or {}).get("large", ""),
                            })
                        characters.append({
                            "characterId": char_node.get("id", 0),
                            "name":        (char_name.get("userPreferred") or char_name.get("full", "")),
                            "nameNative":  char_name.get("native", ""),
                            "image":       (char_node.get("image") or {}).get("large", ""),
                            "media":       char_media,
                        })

                self.staffPageMoreLoaded.emit(json.dumps({
                    "staffId":      staff_id,
                    "staffMedia":   staff_media,
                    "characters":   characters,
                    "mediaHasNext": media_has_next,
                    "charHasNext":  char_has_next,
                    "isError":      False,
                }))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
                # Emit so QML can unblock _isFetchingMore; user can scroll to retry
                self.staffPageMoreLoaded.emit(json.dumps({
                    "staffId":      staff_id,
                    "staffMedia":   [],
                    "characters":   [],
                    "mediaHasNext": False,
                    "charHasNext":  False,
                    "isError":      True,
                }))

        threading.Thread(target=_run, daemon=True).start()


    @Slot(int, int, str)
    def saveAnimeProgress(self, media_id: int, progress: int, status: str) -> None:
        self._loading = True
        self.loadingChanged.emit(True)

        def _run():
            try:
                self._gql(_SAVE_ANIME_ENTRY_MUTATION,
                          {"mediaId": media_id, "progress": progress, "status": status})
                self.animeEntrySaved.emit()
            except Exception as exc:
                self._loading = False
                self.loadingChanged.emit(False)
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int, str, float, str, str, int, str, int, bool, bool)
    def saveAnimeEntry(
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
                self._gql(_SAVE_ANIME_ENTRY_MUTATION, variables)
                self.animeEntrySaved.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def removeAnimeEntry(self, media_id: int) -> None:
        entry_id = self._entry_id_map.get(media_id)
        if not entry_id:
            self.errorOccurred.emit(
                f"Cannot remove: anime entry ID not found for media {media_id}. "
                "Try syncing first."
            )
            return

        def _run():
            try:
                self._gql(_DELETE_ANIME_ENTRY_MUTATION, {"id": entry_id})
                self._entry_id_map.pop(media_id, None)
                self._anime_entry_cache.pop(media_id, None)
                self.animeEntryDeleted.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, float)
    def saveScore(self, media_id: int, score: float) -> None:
        def _run():
            try:
                self._gql(_SAVE_ANIME_ENTRY_MUTATION, {
                    "mediaId": media_id,
                    "score":   score,
                })
                self.entrySaved.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, bool)
    def toggleAnimeFavourite(self, anilist_id: int, currently_favourite: bool) -> None:
        # currently_favourite is no longer used to compute anything — kept only
        # so the QML call site doesn't need to change. The emitted value always
        # comes from a fresh query made after the mutation confirms.
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_FAVOURITE_MUTATION, {"animeId": anilist_id})
                data   = self._gql(_ANIME_FAVOURITE_QUERY, {"id": anilist_id})
                is_fav = (data.get("Media") or {}).get("isFavourite", False)
                self.animeFavouriteToggled.emit(anilist_id, is_fav)
                print("Anime Favourite:", is_fav)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, bool)
    def toggleCharacterFavourite(self, character_id: int, currently_favourite: bool) -> None:
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_CHARACTER_FAVOURITE_MUTATION, {"characterId": character_id})
                data   = self._gql(_CHARACTER_FAVOURITE_QUERY, {"id": character_id})
                is_fav = (data.get("Character") or {}).get("isFavourite", False)
                print("Character Favourite:", is_fav)
                self.characterFavouriteToggled.emit(character_id, is_fav)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, bool)
    def toggleStaffFavourite(self, staff_id: int, currently_favourite: bool) -> None:
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_STAFF_FAVOURITE_MUTATION, {"staffId": staff_id})
                data   = self._gql(_STAFF_FAVOURITE_QUERY, {"id": staff_id})
                is_fav = (data.get("Staff") or {}).get("isFavourite", False)
                print("Staff Favourite:", is_fav)
                self.staffFavouriteToggled.emit(staff_id, is_fav)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()


    # Manga slots

    @Slot()
    def fetchManga(self) -> None:
        def _run():
            try:
                self._begin_loading()
                uid, _ = self._fetch_viewer()
                data    = self._gql(_MANGA_LIST_QUERY, {"userId": int(uid)})
                lists   = (data.get("MediaListCollection") or {}).get("lists", [])
                entries = []
                for lst in lists:
                    for e in (lst.get("entries") or []):
                        media     = e.get("media") or {}
                        status    = e.get("status", "CURRENT")
                        title_obj = media.get("title") or {}
                        title     = title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or ""
                        entries.append({
                            "entryId":               e.get("id", 0),
                            "anilistId":             media.get("id", 0),
                            "title":                 title,
                            "titleRomaji":           title_obj.get("romaji", ""),
                            "mediaType":             media.get("format", "MANGA"),
                            "cover":                 (media.get("coverImage") or {}).get("large", ""),
                            "status":                status,
                            "score":                 e.get("score", 0),
                            "progress":              e.get("progress", 0),
                            "progressVolumes":       e.get("progressVolumes", 0),
                            "chapters":              media.get("chapters") or 0,
                            "volumes":               media.get("volumes") or 0,
                            "updatedAt":             e.get("updatedAt", 0),
                            "rewatches":             e.get("repeat", 0),
                            "notes":                 e.get("notes", "") or "",
                            "priority":              e.get("priority", 0),
                            "hiddenFromStatusLists": e.get("hiddenFromStatusLists", False),
                            "isPrivate":             e.get("private", False),
                            "startedAt":             _date_str(_fuzzy_date(e.get("startedAt"))),
                            "completedAt":           _date_str(_fuzzy_date(e.get("completedAt"))),
                        })
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
                self._emit_update_failure(exc)
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
                self._emit_update_failure(exc)
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
                self._emit_update_failure(exc)
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
                self._gql(_DELETE_MANGA_ENTRY_MUTATION, {"id": entry_id})
                self._manga_entry_id_map.pop(media_id, None)
                self.mangaEntryDeleted.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
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
