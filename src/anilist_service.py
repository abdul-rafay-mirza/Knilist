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
from PySide6.QtCore import QObject, Signal, Slot, Property, QProcess
from PySide6.QtGui import QGuiApplication
from .config import ANILIST_GRAPHQL_URL
from datetime import datetime, timezone
from .graphql_queries import (
    _VIEWER_QUERY, _USER_QUERY, _ANIME_LIST_QUERY, _MANGA_LIST_QUERY,
    _SAVE_ANIME_ENTRY_MUTATION, _SAVE_MANGA_ENTRY_MUTATION,
    _DELETE_ANIME_ENTRY_MUTATION, _DELETE_MANGA_ENTRY_MUTATION,
    _TOGGLE_ANIME_FAVOURITE_MUTATION, _ANIME_PAGE_QUERY,
    _CHARACTER_PAGE_QUERY, _TOGGLE_CHARACTER_FAVOURITE_MUTATION,
    _STAFF_PAGE_QUERY, _STAFF_PAGE_NEXT_QUERY, _TOGGLE_STAFF_FAVOURITE_MUTATION,
    _ANIME_FAVOURITE_QUERY, _CHARACTER_FAVOURITE_QUERY, _STAFF_FAVOURITE_QUERY,
    _STUDIO_PAGE_QUERY, _TOGGLE_STUDIO_FAVOURITE_MUTATION, _STUDIO_FAVOURITE_QUERY,
    _ALL_CHARACTERS_QUERY, _ALL_STAFF_QUERY,
    _MANGA_PAGE_QUERY, _MANGA_FAVOURITE_QUERY, _TOGGLE_MANGA_FAVOURITE_MUTATION,
    _PROFILE_PAGE_QUERY,
    _FOLLOWING_LIST_QUERY, _FOLLOWERS_LIST_QUERY, _TOGGLE_FOLLOW_MUTATION,
    _SEARCH_MEDIA_QUERY, _SEARCH_CHARACTERS_QUERY, _SEARCH_STAFF_QUERY,
    _SEARCH_STUDIOS_QUERY, _SEARCH_USERS_QUERY,
    _NOTIFICATIONS_QUERY,
    _ACTIVITY_QUERY, _ACTIVITY_REPLIES_QUERY,
    _UPDATE_NSFW_SETTING_MUTATION,
    _UPDATE_SCORE_FORMAT_MUTATION,
    _UPDATE_TITLE_LANGUAGE_MUTATION,
    _UPDATE_STAFF_NAME_LANGUAGE_MUTATION,
)

# Helper functions

def _get_ordinal_suffix(day: int) -> str:
    """Returns the correct English ordinal suffix (st, nd, rd, th) for a day."""
    if 11 <= day <= 13:
        return "th"
    return {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")

def _format_timestamp(timestamp: int) -> str:
    """Converts a Unix timestamp (e.g., 1561983210) into '1st July, 2019'."""
    if not timestamp:
        return ""
    try:
        dt = datetime.fromtimestamp(timestamp, tz=timezone.utc)
        
        day = dt.day
        suffix = _get_ordinal_suffix(day)
        month = dt.strftime("%B")  # Full month name (e.g., "July")
        year = dt.strftime("%Y")   # 4-digit year (e.g., "2019")
        
        return f"{day}{suffix} {month}, {year}"
    except (ValueError, OSError, OverflowError):
        return ""

def _format_relative_timestamp(timestamp: int) -> str:
    """Converts a Unix timestamp into AniList's short relative style
    ('2 weeks ago', '3 hours ago') as used on activity/reply rows.
    Falls back to _format_timestamp's full date once the gap reaches a
    year, matching AniList's own site behaviour."""
    if not timestamp:
        return ""
    try:
        now = datetime.now(tz=timezone.utc)
        then = datetime.fromtimestamp(timestamp, tz=timezone.utc)
        seconds = max(0, (now - then).total_seconds())

        minute, hour, day, week, month, year = 60, 3600, 86400, 604800, 2592000, 31536000

        if seconds < minute:
            value, unit = int(seconds), "second"
        elif seconds < hour:
            value, unit = int(seconds // minute), "minute"
        elif seconds < day:
            value, unit = int(seconds // hour), "hour"
        elif seconds < week:
            value, unit = int(seconds // day), "day"
        elif seconds < month:
            value, unit = int(seconds // week), "week"
        elif seconds < year:
            value, unit = int(seconds // month), "month"
        else:
            return _format_timestamp(timestamp)

        value = max(1, value)
        return f"{value} {unit if value == 1 else unit + 's'} ago"
    except (ValueError, OSError, OverflowError):
        return ""

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

def _parse_studio_media_edges(edges: list | None) -> list[dict]:
    """Normalise Studio.media edges into flat dicts for the QML side.
    AniList's Studio.media connection can return the same media more than once
    within one page (e.g. multiple credit records) — dedupe by id, keeping the
    first occurrence."""
    media_list = []
    seen_ids = set()
    for edge in edges or []:
        node = edge.get("node")
        if not node:
            continue
        media_id = node.get("id", 0)
        if media_id in seen_ids:
            continue
        seen_ids.add(media_id)
        title_obj = node.get("title") or {}
        media_list.append({
            "mediaId":    media_id,
            "title":      title_obj.get("userPreferred", ""),
            "type":       "ANIME",   # HorizontalScrollableMediaCoverCards' cardClicked expects this
            "year":       (node.get("startDate") or {}).get("year") or 0,
            "coverImage": (node.get("coverImage") or {}).get("large", ""),
        })
    return media_list

def _flatten_favourite_media(edges: list | None) -> list[dict]:
    """Flatten Favourites.anime/manga edges into flat dicts"""
    result = []
    for edge in edges or []:
        node = edge.get("node")
        if not node:
            continue
        title_obj = node.get("title") or {}
        result.append({
            "mediaId":    node.get("id", 0),
            "title":      title_obj.get("userPreferred") or "",
            "coverImage": (node.get("coverImage") or {}).get("large", ""),
        })
    return result


def _flatten_favourite_people(edges: list | None) -> list[dict]:
    """Flatten Favourites.characters/staff edges into flat dicts"""
    result = []
    for edge in edges or []:
        node = edge.get("node")
        if not node:
            continue
        name_obj = node.get("name") or {}
        result.append({
            "id":    node.get("id", 0),
            "name":  name_obj.get("userPreferred") or "",
            "image": (node.get("image") or {}).get("large", ""),
        })
    return result


def _flatten_favourite_studios(edges: list | None) -> list[dict]:
    """Flatten Favourites.studios edges (name only — studios have no image)."""
    result = []
    for edge in edges or []:
        node = edge.get("node")
        if not node:
            continue
        result.append({"id": node.get("id", 0), "name": node.get("name") or ""})
    return result

def _flatten_user_list(users: list | None) -> list[dict]:
    """Flatten Page.following/Page.followers results into flat dicts.
    Unlike Favourites/Studio.media, these fields return plain User objects
    directly — no edges/node wrapper."""
    result = []
    for u in users or []:
        is_following = u.get("isFollowing", False)
        is_follower  = u.get("isFollower", False)
        result.append({
            "id":          u.get("id", 0),
            "name":        u.get("name") or "",
            "avatar":      (u.get("avatar") or {}).get("large", ""),
            "bannerImage": u.get("bannerImage") or "",
            "isFollowing": is_following,
            "isFollower":  is_follower,
            "isMutual":    bool(is_following) and bool(is_follower),
            "createdAt":   _format_timestamp(u.get("createdAt")),
            "updatedAt":   _format_timestamp(u.get("updatedAt"))
        })
    return result


def _flatten_search_media(nodes: list | None) -> list[dict]:
    """Shape shared by the Anime and Manga search tabs. Both tabs consume
    averageScore/favourites/userStatus via AnimeAndMangaSearchCard.qml on
    the QML side."""
    result = []
    for node in nodes or []:
        title_obj = node.get("title") or {}
        list_entry = node.get("mediaListEntry") or {}
        result.append({
            "id":           node.get("id", 0),
            "title":        title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or "",
            "coverImage":   (node.get("coverImage") or {}).get("large", ""),
            "format":       node.get("format") or "",
            "year":         (node.get("startDate") or {}).get("year") or 0,
            "averageScore": node.get("averageScore") or 0,
            "favourites":   node.get("favourites") or 0,
            # "" when mediaListEntry is null (not on the viewer's list) —
            # matches AnimeAndMangaSearchCard.qml's userStatus empty-string contract.
            "userStatus":   list_entry.get("status") or "",
        })
    return result


def _flatten_search_people(nodes: list | None) -> list[dict]:
    """Shape shared by the Characters and Staff search tabs."""
    result = []
    for node in nodes or []:
        name_obj = node.get("name") or {}
        result.append({
            "id":         node.get("id", 0),
            "name":       name_obj.get("userPreferred") or name_obj.get("full") or name_obj.get("native") or "",
            "image":      (node.get("image") or {}).get("large", ""),
            "favourites": node.get("favourites") or 0,
        })
    return result


def _flatten_search_studios(nodes: list | None) -> list[dict]:
    return [{"id": n.get("id", 0), "name": n.get("name") or "", "favourites": n.get("favourites") or 0}
            for n in (nodes or [])]


def _flatten_search_users(nodes: list | None) -> list[dict]:
    result = []
    for node in nodes or []:
        result.append({
            "id":     node.get("id", 0),
            "name":   node.get("name") or "",
            "avatar": (node.get("avatar") or {}).get("large", ""),
        })
    return result


# __typename -> (message-template-key, image-source-key) used by
# _flatten_notification below. "message" holds a {name}-style template;
# the actual user/media name is substituted in per-notification since
# AniList's `context`/`contexts` strings already contain filler words
# ("liked your activity") but not the name itself in a form we control —
# building the sentence client-side keeps wording consistent across types.
_ACTIVITY_STYLE_NOTIFICATIONS = {
    "ActivityMessageNotification":        "sent you a message",
    "ActivityMentionNotification":        "mentioned you in an activity",
    "ActivityReplyNotification":          "replied to your activity",
    "ActivityReplySubscribedNotification": "replied to an activity you commented on",
    "ActivityLikeNotification":           "liked your activity",
    "ActivityReplyLikeNotification":      "liked your reply",
}


def _flatten_notification(node: dict) -> dict | None:
    """Normalise one NotificationUnion member (see _NOTIFICATIONS_QUERY) into
    the flat shape NotificationsPage.qml's delegate expects:
        { id, kind, title, subtitle, image, createdAt, displayTime, activityId, mediaId }
    createdAt is left as the raw Unix int for callers that want it;
    displayTime is the human-readable string actually shown on screen.
    Returns None for a shape we don't recognise (e.g. a notification type
    added to the union after this was written) so callers can filter it out
    instead of emitting a broken row."""
    typename = node.get("__typename")

    if typename == "AiringNotification":
        media = node.get("media") or {}
        title = (media.get("title") or {}).get("userPreferred") or ""
        episode = node.get("episode") or 0
        return {
            "id":         node.get("id", 0),
            "kind":       "airing",
            "title":      title,
            "subtitle":   f"Episode {episode} aired",
            "image":      (media.get("coverImage") or {}).get("large", ""),
            "createdAt":  node.get("createdAt") or 0,
            "displayTime": _format_timestamp(node.get("createdAt")),
            "activityId": 0,
            "mediaId":    media.get("id", 0),
        }

    if typename == "RelatedMediaAdditionNotification":
        media = node.get("media") or {}
        title = (media.get("title") or {}).get("userPreferred") or ""
        return {
            "id":         node.get("id", 0),
            "kind":       "relatedMedia",
            "title":      title,
            "subtitle":   "New related anime/manga added",
            "image":      (media.get("coverImage") or {}).get("large", ""),
            "createdAt":  node.get("createdAt") or 0,
            "displayTime": _format_timestamp(node.get("createdAt")),
            "activityId": 0,
            "mediaId":    node.get("mediaId") or 0,
        }

    if typename == "FollowingNotification":
        user = node.get("user") or {}
        return {
            "id":         node.get("id", 0),
            "kind":       "following",
            "title":      user.get("name") or "",
            "subtitle":   "started following you",
            "image":      (user.get("avatar") or {}).get("large", ""),
            "createdAt":  node.get("createdAt") or 0,
            "displayTime": _format_timestamp(node.get("createdAt")),
            "activityId": 0,
            "mediaId":    0,
        }

    if typename in _ACTIVITY_STYLE_NOTIFICATIONS:
        user = node.get("user") or {}
        return {
            "id":         node.get("id", 0),
            "kind":       "activity",
            "title":      user.get("name") or "",
            "subtitle":   _ACTIVITY_STYLE_NOTIFICATIONS[typename],
            "image":      (user.get("avatar") or {}).get("large", ""),
            "createdAt":  node.get("createdAt") or 0,
            "displayTime": _format_timestamp(node.get("createdAt")),
            "activityId": node.get("activityId") or 0,
            "mediaId":    0,
        }

    return None


def _flatten_notifications(nodes: list | None) -> list[dict]:
    result = []
    for node in nodes or []:
        flat = _flatten_notification(node)
        if flat is not None:
            result.append(flat)
    return result


def _flatten_activity_replies(nodes: list | None) -> list[dict]:
    """Normalises ActivityReply nodes (see _ACTIVITY_QUERY /
    _ACTIVITY_REPLIES_QUERY) into the flat shape ActivityPage.qml's reply
    delegate expects. Shared by fetchActivity (first page, fetched inline
    with the activity) and fetchActivityReplies (subsequent pages), so the
    two stay in sync instead of duplicating this shape in both places."""
    result = []
    for node in nodes or []:
        user = node.get("user") or {}
        result.append({
            "id":         node.get("id", 0),
            "activityId": node.get("activityId") or 0,
            "text":       node.get("text") or "",
            "createdAt":  node.get("createdAt") or 0,
            "displayTime": _format_relative_timestamp(node.get("createdAt")),
            "likeCount":  len(node.get("likes") or []),
            "user":       {
                "id":     user.get("id", 0),
                "name":   user.get("name") or "",
                "avatar": (user.get("avatar") or {}).get("large", ""),
            },
        })
    return result


# searchType (exactly as sent by HomePage's searchTypes / SearchPage.qml) ->
#   query text, extra GraphQL variables beyond search/page, the field to read
#   off the Page result, and the flattener for that field's nodes.
_SEARCH_CONFIG = {
    "Anime":      (_SEARCH_MEDIA_QUERY,      {"type": "ANIME"}, "media",      _flatten_search_media),
    "Manga":      (_SEARCH_MEDIA_QUERY,      {"type": "MANGA"}, "media",      _flatten_search_media),
    "Characters": (_SEARCH_CHARACTERS_QUERY, {},                "characters", _flatten_search_people),
    "Staff":      (_SEARCH_STAFF_QUERY,      {},                "staff",      _flatten_search_people),
    "Studios":    (_SEARCH_STUDIOS_QUERY,    {},                "studios",    _flatten_search_studios),
    "Users":      (_SEARCH_USERS_QUERY,      {},                "users",      _flatten_search_users),
}


def _compute_tendencies(anime_stats: dict) -> list[dict]:
    """Turn statistics.anime breakdowns into 'Anime Tendencies' lines.
    None of this is an AniList concept — it's a heuristic built from the
    breakdowns AniList does expose, so the thresholds below are tunable,
    not authoritative."""
    tendencies = []

    genres_loved = anime_stats.get("genresLoved") or []
    if genres_loved:
        tendencies.append({
            "kind":   "genresLoved",
            "values": [g.get("genre", "") for g in genres_loved[:3]],
        })

    # Require a few entries so one low score doesn't "win" a genre outright
    genres_hated = [g for g in (anime_stats.get("genresHated") or []) if (g.get("count") or 0) >= 3]
    if genres_hated:
        tendencies.append({
            "kind":   "genresHated",
            "values": [genres_hated[0].get("genre", "")],
        })

    cast_tags = [
        t for t in (anime_stats.get("tagsLoved") or [])
        if ((t.get("tag") or {}).get("category") or "").startswith("Cast")
    ]
    if cast_tags:
        tendencies.append({
            "kind":   "tagsLoved",
            "values": [(t.get("tag") or {}).get("name", "") for t in cast_tags[:3]],
        })

    years_loved = [y for y in (anime_stats.get("yearsLoved") or []) if (y.get("count") or 0) >= 2]
    if years_loved:
        tendencies.append({
            "kind":   "yearsLoved",
            "values": [str(y.get("releaseYear", "")) for y in years_loved[:3]],
        })

    start_years = [y.get("startYear") for y in (anime_stats.get("startYears") or []) if y.get("startYear")]
    if start_years:
        tendencies.append({"kind": "firstYear", "values": [str(min(start_years))]})

    statuses  = {s.get("status"): s.get("count", 0) for s in (anime_stats.get("statuses") or [])}
    completed = statuses.get("COMPLETED", 0)
    dropped   = statuses.get("DROPPED", 0)
    if (completed + dropped) > 0:
        rate = round(completed / (completed + dropped) * 100, 2)
        tendencies.append({"kind": "completionRate", "values": [str(rate)]})

    return tendencies

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
    studioPageLoaded = Signal(str)
    studioFavouriteToggled = Signal(int, bool)
    allCharactersPageLoaded = Signal(str)
    allStaffPageLoaded = Signal(str)
    mangaPageLoaded = Signal(int, str, str, str, str, str, bool, str, str, str, str)
    mangaEntryLoaded = Signal(int, str)   # JSON of entry fields, or {"onList": false}
    mangaFavouriteToggled = Signal(int, bool)
    profileLoaded = Signal(str)   # full JSON payload for the profile page
    homeProfileLoaded = Signal(str)   # {name, avatar, bannerImage, unreadNotificationCount} for the home page header and drawer badge
    unreadNotificationCountChanged = Signal(int)   # fires after markAllNotificationsRead succeeds, so the drawer badge can update without waiting for the next fetchHomeProfile
    followingPageLoaded = Signal(str)   # full JSON payload for the following list page
    followersPageLoaded = Signal(str)   # full JSON payload for the followers list page
    followToggled = Signal(int, bool, bool)   # userId, isFollowing, isFollower
    userProfileLoaded = Signal(str)   # full JSON payload for the "any user" page
    userAnimeLoaded = Signal(int, list)   # userId, entries - read-only list for UsersAnimeListPage
    userMangaLoaded = Signal(int, list)   # userId, entries - read-only list for UsersMangaListPage
    searchResultsLoaded = Signal(str)   # full JSON payload for SearchPage
    notificationsPageLoaded = Signal(str)   # full JSON payload for NotificationsPage
    activityPageLoaded = Signal(str)   # full JSON payload for ActivityPage (activity + first page of replies)
    activityRepliesLoaded = Signal(str)   # full JSON payload for ActivityPage's "load more replies"
    nsfwEnabledChanged = Signal(bool)   # fires whenever the confirmed displayAdultContent value changes — after a viewer fetch, a successful setNsfwEnabled(), or a failed one snapping back to the last known-good value
    titleLanguageChanged = Signal(str)   # fires whenever the confirmed titleLanguage value changes — same shape as nsfwEnabledChanged
    staffNameLanguageChanged = Signal(str)   # fires whenever the confirmed staffNameLanguage value changes — same shape as titleLanguageChanged

    def __init__(self, auth_manager, parent=None):
        super().__init__(parent)
        self._auth                  = auth_manager
        self._loading               = False
        self._loading_count         = 0
        self._score_format          = "POINT_10"
        self._entry_id_map:         dict[int, int]  = {}
        self._manga_entry_id_map:   dict[int, int]  = {}
        self._anime_entry_cache:    dict[int, dict] = {}  # anilistId → full normalised entry
        self._manga_entry_cache:    dict[int, dict] = {}  # anilistId → full normalised entry
        self._anime_entry_cache:    dict[int, dict] = {}  # anilistId → full normalised entry
        self._manga_entry_cache:    dict[int, dict] = {}  # anilistId → full normalised entry
        self._viewer_id:            int | None = None      # cached after first Viewer fetch
        self._followers_fetch_gen: int = 0
        self._following_fetch_gen: int = 0
        self._search_gen: int = 0
        self._notifications_fetch_gen: int = 0
        self._activity_replies_fetch_gen: int = 0
        self._nsfw_enabled: bool = False   # updated once viewer.options is fetched
        self._title_language: str = "ROMAJI"   # AniList's own default; updated once viewer.options is fetched
        self._staff_name_language: str = "ROMAJI_WESTERN"   # AniList's own default; updated once viewer.options is fetched

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

    def _emit_update_failure(self, exc: Exception, message: str = "Network Issue: Failed to update show.") -> None:
        """Every write-mutation failure surfaces this one message to the UI.
        The real exception is printed for debugging, never shown to the user.
        `message` defaults to the original generic text so every existing
        call site keeps behaving exactly as before; callers for which that
        text is misleading (e.g. it says "show", not every mutation is
        about a show) can pass something more specific."""
        print(f"[AniListService] update failed: {exc}")
        self.errorOccurred.emit(message)

    # ── Properties ────────────────────────────────────────────────────────────

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(str, notify=scoreFormatChanged)
    def scoreFormat(self) -> str:
        return self._score_format

    @Property(bool, notify=nsfwEnabledChanged)
    def nsfwEnabled(self) -> bool:
        return self._nsfw_enabled

    @Property(str, notify=titleLanguageChanged)
    def titleLanguage(self) -> str:
        return self._title_language

    @Property(str, notify=staffNameLanguageChanged)
    def staffNameLanguage(self) -> str:
        return self._staff_name_language

    # ── Internal ──────────────────────────────────────────────────────────────

    def _gql(self, query: str, variables: dict | None = None) -> dict:
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        token = self._auth.token()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        resp = requests.post(
            ANILIST_GRAPHQL_URL,
            json={"query": query, "variables": variables or {}},
            headers=headers,
            timeout=15,
        )
        resp.raise_for_status()
        body = resp.json()
        if "errors" in body:
            raise RuntimeError(body["errors"][0]["message"])
        return body["data"]

    def _fetch_viewer_raw(self) -> dict:
        """Single GraphQL round-trip for the Viewer query. Callers pick the
        fields they need out of the returned dict."""
        return self._gql(_VIEWER_QUERY).get("Viewer") or {}

    def _apply_viewer_bookkeeping(self, viewer: dict) -> None:
        uid  = str(viewer.get("id", ""))
        name = viewer.get("name", "")
        if uid:
            self._viewer_id = int(uid)
        self._auth.setUserInfo(uid, name)
        self.userInfoReady.emit()
        fmt = (viewer.get("mediaListOptions") or {}).get("scoreFormat", "POINT_10")
        if fmt != self._score_format:
            self._score_format = fmt
            self.scoreFormatChanged.emit(fmt)

        nsfw = (viewer.get("options") or {}).get("displayAdultContent", False)
        if nsfw != self._nsfw_enabled:
            self._nsfw_enabled = nsfw
            self.nsfwEnabledChanged.emit(nsfw)

        title_lang = (viewer.get("options") or {}).get("titleLanguage", "ROMAJI")
        if title_lang != self._title_language:
            self._title_language = title_lang
            self.titleLanguageChanged.emit(title_lang)

        staff_lang = (viewer.get("options") or {}).get("staffNameLanguage", "ROMAJI_WESTERN")
        if staff_lang != self._staff_name_language:
            self._staff_name_language = staff_lang
            self.staffNameLanguageChanged.emit(staff_lang)

    def _fetch_viewer(self) -> tuple[str, str]:
        """Fetch viewer info, update score format, return (uid, name)."""
        viewer = self._fetch_viewer_raw()
        self._apply_viewer_bookkeeping(viewer)
        return str(viewer.get("id", "")), viewer.get("name", "")

    def _get_viewer_id(self) -> int:
        """Return the viewer's numeric id — cached after the first successful
        Viewer fetch, so paging through Following/Followers doesn't re-fetch
        Viewer on every 'load more'."""
        if self._viewer_id is None:
            uid, _ = self._fetch_viewer()
            self._viewer_id = int(uid) if uid else 0
        return self._viewer_id

    # Home page Slot

    @Slot()
    def fetchHomeProfile(self) -> None:
        """Fetch just what HomePage's header needs — name, avatar, banner,
        unread notification count — via the single-round-trip Viewer query,
        instead of fetchProfile()'s full payload (which pages through every
        favourites connection). Main.qml also calls this directly (not just
        HomePage) so the drawer's notification badge populates at startup
        regardless of which page the user opens first."""
        def _run():
            try:
                self._begin_loading()
                viewer = self._fetch_viewer_raw()
                self._apply_viewer_bookkeeping(viewer)

                payload = {
                    "name":                   viewer.get("name", ""),
                    "avatar":                 (viewer.get("avatar") or {}).get("large", ""),
                    "bannerImage":            viewer.get("bannerImage") or "",
                    "unreadNotificationCount": viewer.get("unreadNotificationCount") or 0,
                }
                self.homeProfileLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    # Profile Slot
    
    @Slot()
    def fetchProfile(self) -> None:
        """Fetch the full profile payload — avatar, banner, about, badges,
        stats, favourites, follow counts, and derived tendencies — for the
        profile page.

        Favourites (anime/manga/characters/staff/studios) are paginated
        independently by AniList, so we loop page-by-page per connection,
        accumulating edges, until every connection reports hasNextPage:
        false. _MAX_FAVOURITE_PAGES caps the loop as a safety net against
        a runaway request in case of an unexpected API response shape."""
        _MAX_FAVOURITE_PAGES = 200   # 200 * 25 = 5000 entries per connection, generous headroom

        def _run():
            try:
                self._begin_loading()
                uid, _ = self._fetch_viewer()

                pages = {"animePage": 1, "mangaPage": 1, "charPage": 1,
                        "staffPage": 1, "studioPage": 1}
                has_next = {"anime": True, "manga": True, "characters": True,
                            "staff": True, "studios": True}
                accumulated_edges = {"anime": [], "manga": [], "characters": [],
                                    "staff": [], "studios": []}

                viewer      = {}
                options     = {}
                anime_stats = {}
                manga_stats = {}
                following_total = 0
                followers_total = 0

                for loop_count in range(_MAX_FAVOURITE_PAGES):
                    variables  = {"userId": int(uid), **pages}
                    data       = self._gql(_PROFILE_PAGE_QUERY, variables)
                    viewer     = data.get("Viewer") or {}
                    favourites = viewer.get("favourites") or {}

                    if loop_count == 0:
                        options     = viewer.get("options") or {}
                        stats       = viewer.get("statistics") or {}
                        anime_stats = stats.get("anime") or {}
                        manga_stats = stats.get("manga") or {}
                        following_total = ((data.get("followingPage") or {}).get("pageInfo") or {}).get("total", 0)
                        followers_total = ((data.get("followersPage") or {}).get("pageInfo") or {}).get("total", 0)

                    for key, page_var in (("anime", "animePage"), ("manga", "mangaPage"),
                                        ("characters", "charPage"), ("staff", "staffPage"),
                                        ("studios", "studioPage")):
                        if not has_next[key]:
                            continue
                        conn = favourites.get(key) or {}
                        accumulated_edges[key].extend(conn.get("edges") or [])
                        has_next[key] = (conn.get("pageInfo") or {}).get("hasNextPage", False)
                        if has_next[key]:
                            pages[page_var] += 1

                    if not any(has_next.values()):
                        break

                payload = {
                    "id":                      viewer.get("id", 0),
                    "name":                    viewer.get("name", ""),
                    "about":                   viewer.get("about") or "",
                    "avatar":                  (viewer.get("avatar") or {}).get("large", ""),
                    "bannerImage":             viewer.get("bannerImage") or "",
                    "unreadNotificationCount": viewer.get("unreadNotificationCount") or 0,
                    "donatorTier":             viewer.get("donatorTier") or 0,
                    "donatorBadge":            viewer.get("donatorBadge") or "",
                    "moderatorRoles":          viewer.get("moderatorRoles") or [],
                    "titleLanguage":           options.get("titleLanguage") or "",
                    "displayAdultContent":     options.get("displayAdultContent", False),
                    "profileColor":            options.get("profileColor") or "blue",
                    "scoreFormat":             self._score_format,

                    "animeCount":     anime_stats.get("count") or 0,
                    "mangaCount":     manga_stats.get("count") or 0,
                    "followingCount": following_total,
                    "followersCount": followers_total,

                    "episodesWatched": anime_stats.get("episodesWatched") or 0,
                    "daysWatched":     (anime_stats.get("minutesWatched") or 0) / 1440,
                    "animeMeanScore":  anime_stats.get("meanScore") or 0,
                    "chaptersRead":    manga_stats.get("chaptersRead") or 0,
                    "volumesRead":     manga_stats.get("volumesRead") or 0,
                    "mangaMeanScore":  manga_stats.get("meanScore") or 0,

                    "favouriteAnime":      _flatten_favourite_media(accumulated_edges["anime"]),
                    "favouriteManga":      _flatten_favourite_media(accumulated_edges["manga"]),
                    "favouriteCharacters": _flatten_favourite_people(accumulated_edges["characters"]),
                    "favouriteStaff":      _flatten_favourite_people(accumulated_edges["staff"]),
                    "favouriteStudios":    _flatten_favourite_studios(accumulated_edges["studios"]),

                    "tendencies": _compute_tendencies(anime_stats),
                }
                self.profileLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchUserProfile(self, user_id: int) -> None:
        """Fetch the full profile payload for ANY user (self or someone else)
        via _USER_QUERY. Mirrors fetchProfile()'s favourites-pagination loop,
        but targets User(id: $id) instead of Viewer, so it works for a
        user page opened from someone's Followers/Following list too.

        Note: _USER_QUERY's followingPage/followersPage sibling fields key
        off $id (not $userId, unlike _PROFILE_PAGE_QUERY) — so the variables
        dict below uses "id", matching the query's own variable name."""
        _MAX_FAVOURITE_PAGES = 200   # same safety cap as fetchProfile()

        def _run():
            try:
                self._begin_loading()

                pages = {"animePage": 1, "mangaPage": 1, "charPage": 1,
                        "staffPage": 1, "studioPage": 1}
                has_next = {"anime": True, "manga": True, "characters": True,
                            "staff": True, "studios": True}
                accumulated_edges = {"anime": [], "manga": [], "characters": [],
                                    "staff": [], "studios": []}

                user = {}
                anime_stats = {}
                manga_stats = {}
                following_total = 0
                followers_total = 0

                for loop_count in range(_MAX_FAVOURITE_PAGES):
                    variables  = {"id": user_id, "perPage": 25, **pages}
                    data       = self._gql(_USER_QUERY, variables)
                    user       = data.get("User") or {}
                    favourites = user.get("favourites") or {}

                    if loop_count == 0:
                        stats       = user.get("statistics") or {}
                        anime_stats = stats.get("anime") or {}
                        manga_stats = stats.get("manga") or {}
                        following_total = ((data.get("followingPage") or {}).get("pageInfo") or {}).get("total", 0)
                        followers_total = ((data.get("followersPage") or {}).get("pageInfo") or {}).get("total", 0)

                    for key, page_var in (("anime", "animePage"), ("manga", "mangaPage"),
                                        ("characters", "charPage"), ("staff", "staffPage"),
                                        ("studios", "studioPage")):
                        if not has_next[key]:
                            continue
                        conn = favourites.get(key) or {}
                        accumulated_edges[key].extend(conn.get("edges") or [])
                        has_next[key] = (conn.get("pageInfo") or {}).get("hasNextPage", False)
                        if has_next[key]:
                            pages[page_var] += 1

                    if not any(has_next.values()):
                        break

                options = user.get("options") or {}

                viewer_id = self._auth.userId
                is_self = bool(viewer_id) and str(user.get("id", "")) == viewer_id

                payload = {
                    "id":                user.get("id", 0),
                    "name":              user.get("name", ""),
                    "about":             user.get("about") or "",
                    "avatar":            (user.get("avatar") or {}).get("large", ""),
                    "bannerImage":       user.get("bannerImage") or "",
                    "previousNames":     [n.get("name", "") for n in (user.get("previousNames") or [])],
                    "isFollowing":       user.get("isFollowing", False),
                    "isFollower":        user.get("isFollower", False),
                    "isBlocked":         user.get("isBlocked", False),
                    "isSelf":            is_self,
                    "donatorTier":       user.get("donatorTier") or 0,
                    "donatorBadge":      user.get("donatorBadge") or "",
                    "createdAt":         user.get("createdAt") or 0,
                    "moderatorRoles":    user.get("moderatorRoles") or [],
                    "bans":              user.get("bans") or [],
                    "profileColor":      options.get("profileColor") or "blue",
                    "scoreFormat":       (user.get("mediaListOptions") or {}).get("scoreFormat", "POINT_10"),

                    "animeCount":     anime_stats.get("count") or 0,
                    "mangaCount":     manga_stats.get("count") or 0,
                    "followingCount": following_total,
                    "followersCount": followers_total,

                    "episodesWatched": anime_stats.get("episodesWatched") or 0,
                    "daysWatched":     (anime_stats.get("minutesWatched") or 0) / 1440,
                    "animeMeanScore":  anime_stats.get("meanScore") or 0,
                    "chaptersRead":    manga_stats.get("chaptersRead") or 0,
                    "volumesRead":     manga_stats.get("volumesRead") or 0,
                    "mangaMeanScore":  manga_stats.get("meanScore") or 0,

                    "favouriteAnime":      _flatten_favourite_media(accumulated_edges["anime"]),
                    "favouriteManga":      _flatten_favourite_media(accumulated_edges["manga"]),
                    "favouriteCharacters": _flatten_favourite_people(accumulated_edges["characters"]),
                    "favouriteStaff":      _flatten_favourite_people(accumulated_edges["staff"]),
                    "favouriteStudios":    _flatten_favourite_studios(accumulated_edges["studios"]),
                }
                self.userProfileLoaded.emit(json.dumps(payload))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int)
    def fetchFollowing(self, user_id: int, page: int) -> None:
        is_first_page = page <= 1   # QML passes 1 for the initial load, currentPage+1 to load more

        self._following_fetch_gen += 1
        my_gen = self._following_fetch_gen

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()
                target_id = user_id if user_id else self._get_viewer_id()
                data     = self._gql(_FOLLOWING_LIST_QUERY, {
                    "userId": target_id,
                    "page":   page if page > 0 else 1,
                })
                if my_gen != self._following_fetch_gen:
                    return
                page_obj = data.get("Page") or {}
                has_next = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)

                self.followingPageLoaded.emit(json.dumps({
                    "page":        page,
                    "users":       _flatten_user_list(page_obj.get("following")),
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                if my_gen != self._following_fetch_gen:
                    return
                self.errorOccurred.emit(str(exc))
                self.followingPageLoaded.emit(json.dumps({
                    "page": page, "users": [], "hasNextPage": False, "isError": True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int)
    def fetchFollowers(self, user_id: int, page: int) -> None:
        is_first_page = page <= 1

        self._followers_fetch_gen += 1
        my_gen = self._followers_fetch_gen

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()
                target_id = user_id if user_id else self._get_viewer_id()
                data     = self._gql(_FOLLOWERS_LIST_QUERY, {
                    "userId": target_id,
                    "page":   page if page > 0 else 1,
                })
                if my_gen != self._followers_fetch_gen:
                    return
                page_obj = data.get("Page") or {}
                has_next = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)

                self.followersPageLoaded.emit(json.dumps({
                    "page":        page,
                    "users":       _flatten_user_list(page_obj.get("followers")),
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                if my_gen != self._followers_fetch_gen:
                    return
                self.errorOccurred.emit(str(exc))
                self.followersPageLoaded.emit(json.dumps({
                    "page": page, "users": [], "hasNextPage": False, "isError": True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def toggleFollow(self, user_id: int) -> None:
        """Follow/unfollow a user. AniList's ToggleFollow mutation returns the
        resulting isFollowing/isFollower state directly on the mutation
        response, so — unlike the favourite toggles — no follow-up query is
        needed to confirm the new state."""
        def _run():
            try:
                self._begin_loading()
                data         = self._gql(_TOGGLE_FOLLOW_MUTATION, {"userId": user_id})
                result       = data.get("ToggleFollow") or {}
                is_following = result.get("isFollowing", False)
                is_follower  = result.get("isFollower", False)
                print("Follow toggled:", user_id, "isFollowing:", is_following, "isFollower:", is_follower)
                self.followToggled.emit(user_id, is_following, is_follower)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    # Notifications slots

    @Slot(int)
    def fetchNotifications(self, page: int) -> None:
        """Backs NotificationsPage.qml. Same paging/generation-counter shape
        as fetchFollowing/fetchFollowers: QML passes 1 for the initial load
        or a refresh, currentPage+1 to load more, and a generation counter
        makes sure only the most recently requested page ever gets emitted
        if a refresh fires while an older page request is still in flight."""
        is_first_page = page <= 1

        self._notifications_fetch_gen += 1
        my_gen = self._notifications_fetch_gen

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()
                data     = self._gql(_NOTIFICATIONS_QUERY, {
                    "page": page if page > 0 else 1,
                })
                if my_gen != self._notifications_fetch_gen:
                    return   # a newer fetch/page request has since superseded this one
                page_obj = data.get("Page") or {}
                has_next = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)

                self.notificationsPageLoaded.emit(json.dumps({
                    "page":         page,
                    "notifications": _flatten_notifications(page_obj.get("notifications")),
                    "hasNextPage":  has_next,
                    "isError":      False,
                }))
            except Exception as exc:
                if my_gen != self._notifications_fetch_gen:
                    return
                self.errorOccurred.emit(str(exc))
                self.notificationsPageLoaded.emit(json.dumps({
                    "page": page, "notifications": [], "hasNextPage": False,
                    "isError": True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot()
    def markAllNotificationsRead(self) -> None:
        """Backs NotificationsPage's "Read All" action. Fires a throwaway
        1-item notifications fetch with resetNotificationCount: true, which
        zeroes AniList's own aggregate Viewer.unreadNotificationCount —
        the only server-side "mark read" effect this API exposes. Emits
        unreadNotificationCountChanged(0) on success so the drawer badge
        clears immediately instead of waiting for the next fetchHomeProfile."""
        def _run():
            try:
                self._begin_loading()
                self._gql(_NOTIFICATIONS_QUERY, {"page": 1, "perPage": 1, "resetCount": True})
                self.unreadNotificationCountChanged.emit(0)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    # Activity slots

    @Slot(int)
    def fetchActivity(self, activity_id: int) -> None:
        """Backs ActivityPage.qml. Single-shot detail fetch (same shape as
        fetchCharacterPage/fetchStudioPage, not paginated like
        fetchNotifications) since it targets exactly one Activity node.
        Normalises whichever ActivityUnion member comes back (ListActivity/
        TextActivity/MessageActivity) into one flat shape the page can
        render uniformly, the same way _flatten_notification does for
        NotificationUnion. Also emits the first page of replies inline so
        the page has content immediately without a second round-trip."""
        def _run():
            try:
                self._begin_loading()
                data     = self._gql(_ACTIVITY_QUERY, {"id": activity_id})
                activity = data.get("Activity") or {}
                typename = activity.get("__typename")

                if typename == "ListActivity":
                    user  = activity.get("user") or {}
                    media = activity.get("media") or {}
                    flat = {
                        "kind":       "list",
                        "user":       {"id": user.get("id", 0), "name": user.get("name") or "",
                                        "avatar": (user.get("avatar") or {}).get("large", "")},
                        # status/progress are AniList's own short strings
                        # ("Rewatched", "Watched 3 of 12") — already
                        # formatted server-side, no client assembly needed
                        "text":       f"{activity.get('status') or ''} {activity.get('progress') or ''}".strip(),
                        "mediaId":    media.get("id", 0),
                        "mediaTitle": (media.get("title") or {}).get("userPreferred") or "",
                        "mediaCover": (media.get("coverImage") or {}).get("large", ""),
                        "mediaType":  media.get("type") or "",
                        "recipient":  None,
                    }
                elif typename == "TextActivity":
                    user = activity.get("user") or {}
                    flat = {
                        "kind":       "text",
                        "user":       {"id": user.get("id", 0), "name": user.get("name") or "",
                                        "avatar": (user.get("avatar") or {}).get("large", "")},
                        "text":       activity.get("text") or "",
                        "mediaId":    0, "mediaTitle": "", "mediaCover": "", "mediaType": "",
                        "recipient":  None,
                    }
                elif typename == "MessageActivity":
                    messenger = activity.get("messenger") or {}
                    recipient = activity.get("recipient") or {}
                    flat = {
                        "kind":       "message",
                        "user":       {"id": messenger.get("id", 0), "name": messenger.get("name") or "",
                                        "avatar": (messenger.get("avatar") or {}).get("large", "")},
                        "text":       activity.get("message") or "",
                        "mediaId":    0, "mediaTitle": "", "mediaCover": "", "mediaType": "",
                        "recipient":  {"id": recipient.get("id", 0), "name": recipient.get("name") or "",
                                        "avatar": (recipient.get("avatar") or {}).get("large", "")},
                    }
                else:
                    # Activity was deleted, is private, or is a union member
                    # added after this was written — surface as an error
                    # rather than emit a broken/empty page.
                    self.errorOccurred.emit("This activity is no longer available.")
                    self.activityPageLoaded.emit(json.dumps({"isError": True}))
                    return

                flat["activityId"]  = activity.get("id", 0)
                flat["createdAt"]   = activity.get("createdAt") or 0
                flat["displayTime"] = _format_relative_timestamp(activity.get("createdAt"))
                flat["replyCount"]  = activity.get("replyCount") or 0
                flat["likeCount"]   = len(activity.get("likes") or [])
                flat["isLocked"]    = activity.get("isLocked", False)
                flat["siteUrl"]     = activity.get("siteUrl") or ""

                page_obj  = data.get("Page") or {}
                has_next  = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)
                replies   = _flatten_activity_replies(page_obj.get("activityReplies"))

                self.activityPageLoaded.emit(json.dumps({
                    "activity":     flat,
                    "replies":      replies,
                    "repliesPage":  1,
                    "hasNextPage":  has_next,
                    "isError":      False,
                }))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
                self.activityPageLoaded.emit(json.dumps({"isError": True}))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, int)
    def fetchActivityReplies(self, activity_id: int, page: int) -> None:
        """Backs ActivityPage's "load more replies". Same paging/generation-
        counter shape as fetchNotifications: QML passes currentPage+1, and
        a generation counter makes sure only the most recently requested
        page ever gets emitted if the page is left (or refreshed) while an
        older page request is still in flight."""
        self._activity_replies_fetch_gen += 1
        my_gen = self._activity_replies_fetch_gen

        def _run():
            try:
                data = self._gql(_ACTIVITY_REPLIES_QUERY, {
                    "activityId": activity_id,
                    "page":       page if page > 0 else 1,
                })
                if my_gen != self._activity_replies_fetch_gen:
                    return   # a newer replies request has since superseded this one
                page_obj = data.get("Page") or {}
                has_next = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)

                self.activityRepliesLoaded.emit(json.dumps({
                    "replies":     _flatten_activity_replies(page_obj.get("activityReplies")),
                    "repliesPage": page,
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                if my_gen != self._activity_replies_fetch_gen:
                    return
                self.errorOccurred.emit(str(exc))
                self.activityRepliesLoaded.emit(json.dumps({
                    "replies": [], "repliesPage": page, "hasNextPage": False,
                    "isError": True,
                }))

        threading.Thread(target=_run, daemon=True).start()

    # Settings slots

    @Slot(bool)
    def setNsfwEnabled(self, enabled: bool) -> None:
        """Persist the Adult Content (NSFW) display setting directly on the
        user's AniList account via the UpdateUser mutation — this is a
        real account-wide setting, not a local knilist preference, so it
        also affects anilist.co and any other client the user is signed
        into.

        SettingsPage.qml's Switch flips its own visual state the instant
        the user taps it (that's just how QtQuick's Switch/AbstractButton
        works — it's optimistic by construction, not something we chose).
        On success we trust the mutation's own response as the source of
        truth for the confirmed value, matching how toggleFollow already
        treats AniList's response as authoritative rather than assuming
        the request succeeded exactly as sent. On failure we emit the
        previous value again so the switch snaps back — otherwise the UI
        would keep showing "on" while the AniList account itself still
        says "off"."""
        previous = self._nsfw_enabled

        def _run():
            try:
                self._begin_loading()
                data      = self._gql(_UPDATE_NSFW_SETTING_MUTATION, {"displayAdultContent": enabled})
                confirmed = (data.get("UpdateUser") or {}).get("options", {}).get("displayAdultContent", enabled)
                self._nsfw_enabled = confirmed
                self.nsfwEnabledChanged.emit(confirmed)
            except Exception as exc:
                self._nsfw_enabled = previous
                self.nsfwEnabledChanged.emit(previous)   # snap the switch back to the last known-good state
                self._emit_update_failure(exc, "Network Issue: Failed to update your Adult Content setting.")
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(str)
    def setScoreFormat(self, fmt: str) -> None:
        """Persist the list scoring system directly on the user's AniList
        account via the UpdateUser mutation. Same shape as setNsfwEnabled
        above: SettingsPage.qml's ComboBox updates its own currentIndex
        the moment the user picks an option, so on success we trust the
        mutation's own response (mediaListOptions.scoreFormat) as the
        confirmed value — reusing the scoreFormat property and
        scoreFormatChanged signal that already exist for the read-only
        display — and on failure we emit the previous value again so the
        ComboBox snaps back to what the account actually has."""
        previous = self._score_format

        def _run():
            try:
                self._begin_loading()
                data      = self._gql(_UPDATE_SCORE_FORMAT_MUTATION, {"scoreFormat": fmt})
                confirmed = (data.get("UpdateUser") or {}).get("mediaListOptions", {}).get("scoreFormat", fmt)
                self._score_format = confirmed
                self.scoreFormatChanged.emit(confirmed)
            except Exception as exc:
                self._score_format = previous
                self.scoreFormatChanged.emit(previous)   # snap the ComboBox back to the last known-good state
                self._emit_update_failure(exc, "Network Issue: Failed to update your scoring system.")
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(str)
    def setTitleLanguage(self, lang: str) -> None:
        """Persist which title (romaji/English/native) the user wants to
        see, directly on the AniList account via UpdateUser — same shape
        as setNsfwEnabled and setScoreFormat above. On success we trust
        the mutation's own response (options.titleLanguage) as the
        confirmed value; on failure we emit the previous value again so
        the ComboBox snaps back to what the account actually has."""
        previous = self._title_language

        def _run():
            try:
                self._begin_loading()
                data      = self._gql(_UPDATE_TITLE_LANGUAGE_MUTATION, {"titleLanguage": lang})
                confirmed = (data.get("UpdateUser") or {}).get("options", {}).get("titleLanguage", lang)
                self._title_language = confirmed
                self.titleLanguageChanged.emit(confirmed)
            except Exception as exc:
                self._title_language = previous
                self.titleLanguageChanged.emit(previous)   # snap the ComboBox back to the last known-good state
                self._emit_update_failure(exc, "Network Issue: Failed to update your title language.")
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(str)
    def setStaffNameLanguage(self, lang: str) -> None:
        """Persist how staff and character names are ordered/displayed
        (Western-order romaji, original-order romaji, or native) directly
        on the AniList account via UpdateUser — same shape as
        setTitleLanguage above. On success we trust the mutation's own
        response (options.staffNameLanguage) as the confirmed value; on
        failure we emit the previous value again so the ComboBox snaps
        back to what the account actually has."""
        previous = self._staff_name_language

        def _run():
            try:
                self._begin_loading()
                data      = self._gql(_UPDATE_STAFF_NAME_LANGUAGE_MUTATION, {"staffNameLanguage": lang})
                confirmed = (data.get("UpdateUser") or {}).get("options", {}).get("staffNameLanguage", lang)
                self._staff_name_language = confirmed
                self.staffNameLanguageChanged.emit(confirmed)
            except Exception as exc:
                self._staff_name_language = previous
                self.staffNameLanguageChanged.emit(previous)   # snap the ComboBox back to the last known-good state
                self._emit_update_failure(exc, "Network Issue: Failed to update your staff & character name language.")
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

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
    def fetchUserAnime(self, user_id: int) -> None:
        """Read-only anime list for another AniList user, backing
        UsersAnimeListPage. Reuses _ANIME_LIST_QUERY/field-shaping exactly
        like fetchAnime(), but queries the given user_id directly instead of
        the viewer, and deliberately never touches _entry_id_map /
        _anime_entry_cache - those back the viewer's own editor/score
        mutations and must not be overwritten with another user's entries."""
        def _run():
            try:
                self._begin_loading()
                data    = self._gql(_ANIME_LIST_QUERY, {"userId": user_id})
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
                self.userAnimeLoaded.emit(user_id, entries)
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
                            "title":        title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or "",
                            "coverImage":   (node.get("coverImage") or {}).get("large", ""),
                            "status":       node.get("status", ""),
                        })

                raw_characters = (media.get("characters") or {}).get("edges") or []
                characters = []
                for edge in raw_characters:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        name_obj = node.get("name") or {}
                        characters.append({
                            "characterId": node.get("id", 0),
                            "name":        name_obj.get("userPreferred") or name_obj.get("full") or "",
                            "nativeName":  name_obj.get("native", "") or "",
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
                        "title": title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or "", 
                        "coverImage": (media_recommendation.get("coverImage") or {}).get("large", "")
                    })
                
                raw_staff_edges = (media.get("staff") or {}).get("edges") or []
                staff = []
                for edge in raw_staff_edges:
                  if edge.get("node") is not None and edge.get("node") != {}:
                    node = edge["node"]
                    name_obj = node.get("name") or {}
                    staff.append({
                      "role": edge.get("role", ""),
                      "id": node.get("id", 0),
                      "name": name_obj.get("userPreferred") or name_obj.get("full") or name_obj.get("native") or "",
                      "image": (node.get("image") or {}).get("large", "")
                    })

                next_airing    = media.get("nextAiringEpisode") or {}
                status         = media.get("status") or ""
                studios_nodes  = (media.get("studios") or {}).get("nodes") or []

                studios = []
                producers = []
                seen_studios = set()
                for node in studios_nodes:
                    if node["id"] in seen_studios:
                        continue
                    if node["isAnimationStudio"]:
                        studios.append(node)
                    else:
                        producers.append(node)
                    seen_studios.add(node["id"])
                
                print(studios)
                print(producers)

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
                    "studios":            studios,
                    "producers":          producers,
                    "titleRomaji":        (media.get("title") or {}).get("romaji")  or "",
                    "titleEnglish":       (media.get("title") or {}).get("english") or "",
                    "titleNative":        (media.get("title") or {}).get("native")  or "",
                    # Airing — only populated when RELEASING
                    "nextAiringEpisode":  next_airing.get("episode", 0),
                    "timeUntilAiring":    _format_duration(next_airing.get("timeUntilAiring", 0))
                                          if (status == "RELEASING" and next_airing) else "",
                    "tags": media.get("tags") or [],
                    "externalLinks": media.get("externalLinks") or []
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

    @Slot(int, int)
    def fetchStudioPage(self, studio_id: int, page: int) -> None:
        is_first_page = page <= 1   # QML passes 1 for the initial load, currentPage+1 to load more

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()   # global spinner only for the first load
                data   = self._gql(_STUDIO_PAGE_QUERY, {"id": studio_id, "page": page if page > 0 else 1})
                studio = data.get("Studio") or {}
                media_conn = studio.get("media") or {}
                has_next   = (media_conn.get("pageInfo") or {}).get("hasNextPage", False)

                self.studioPageLoaded.emit(json.dumps({
                    "studioId":    studio_id,
                    "page":        page,
                    "name":        studio.get("name") or "",
                    "isFavourite": studio.get("isFavourite", False),
                    "media":       _parse_studio_media_edges(media_conn.get("edges")),
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
                # Always emit studioPageLoaded too, even here — QML has exactly one
                # handler to clear its loading flags in, regardless of page or outcome.
                self.studioPageLoaded.emit(json.dumps({
                    "studioId":    studio_id,
                    "page":        page,
                    "name":        "",
                    "isFavourite": False,
                    "media":       [],
                    "hasNextPage": False,
                    "isError":     True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, bool)
    def toggleStudioFavourite(self, studio_id: int, currently_favourite: bool) -> None:
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_STUDIO_FAVOURITE_MUTATION, {"studioId": studio_id})
                data   = self._gql(_STUDIO_FAVOURITE_QUERY, {"id": studio_id})
                is_fav = (data.get("Studio") or {}).get("isFavourite", False)
                print("Studio Favourite:", is_fav)
                self.studioFavouriteToggled.emit(studio_id, is_fav)
            except Exception as exc:
                self._emit_update_failure(exc)
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
                        "title":   title_obj.get("userPreferred") or title_obj.get("english", "") or title_obj.get("romaji", ""),
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
    def saveAnimeScore(self, media_id: int, score: float) -> None:
        def _run():
            try:
                self._gql(_SAVE_ANIME_ENTRY_MUTATION, {
                    "mediaId": media_id,
                    "score":   score,
                })
                self.animeEntrySaved.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int, float)
    def saveMangaScore(self, media_id: int, score: float) -> None:
        def _run():
            try:
                self._gql(_SAVE_MANGA_ENTRY_MUTATION, {
                    "mediaId": media_id,
                    "score":   score,
                })
                self.mangaEntrySaved.emit()
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
                self._gql(_TOGGLE_ANIME_FAVOURITE_MUTATION, {"animeId": anilist_id})
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
                self._manga_entry_cache = {e["anilistId"]: e for e in entries}
                self.mangaLoaded.emit(entries)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchUserManga(self, user_id: int) -> None:
        """Read-only manga list for another AniList user, backing
        UsersMangaListPage. Reuses _MANGA_LIST_QUERY/field-shaping exactly
        like fetchManga(), but queries the given user_id directly instead of
        the viewer, and deliberately never touches _manga_entry_id_map /
        _manga_entry_cache - those back the viewer's own editor/score
        mutations and must not be overwritten with another user's entries."""
        def _run():
            try:
                self._begin_loading()
                data    = self._gql(_MANGA_LIST_QUERY, {"userId": user_id})
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
                self.userMangaLoaded.emit(user_id, entries)
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchMangaEntry(self, anilist_id: int) -> None:
        """Emit the cached list entry for this manga, or {"onList": false} if not on list."""
        entry = self._manga_entry_cache.get(anilist_id)
        print("fetchMangaEntry called for:", anilist_id, "cache hit:", entry is not None)
        if not entry:
            self.mangaEntryLoaded.emit(anilist_id, json.dumps({"onList": False}))
            return
        payload = dict(entry)
        payload["onList"] = True
        self.mangaEntryLoaded.emit(anilist_id, json.dumps(payload))

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
                self._manga_entry_cache.pop(media_id, None)
                self.mangaEntryDeleted.emit()
            except Exception as exc:
                self._emit_update_failure(exc)
        threading.Thread(target=_run, daemon=True).start()

    @Slot(int)
    def fetchMangaPage(self, anilist_id: int) -> None:
        def _run():
            try:
                self._begin_loading()
                data  = self._gql(_MANGA_PAGE_QUERY, {"id": anilist_id})
                media = data.get("Media") or {}

                title_obj = media.get("title") or {}
                title     = title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or ""
                banner       = media.get("bannerImage") or ""
                cover        = (media.get("coverImage") or {}).get("large", "")
                description  = media.get("description") or ""
                is_favourite = media.get("isFavourite", False)
                print(f"[fetchMangaPage] {anilist_id} raw isFavourite from AniList: {is_favourite}")

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
                            "title":        title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or "",
                            "coverImage":   (node.get("coverImage") or {}).get("large", ""),
                            "status":       node.get("status", ""),
                        })

                raw_characters = (media.get("characters") or {}).get("edges") or []
                characters = []
                for edge in raw_characters:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        name_obj = node.get("name")
                        characters.append({
                            "characterId": node.get("id", 0),
                            "name":        name_obj.get("userPreferred") or name_obj.get("full") or "",
                            "nativeName":  name_obj.get("native", "") or "",
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
                            "title": title_obj.get("userPreferred") or title_obj.get("english") or title_obj.get("romaji") or "", 
                            "coverImage": (media_recommendation.get("coverImage") or {}).get("large", "")
                        })

                raw_staff_edges = (media.get("staff") or {}).get("edges") or []
                staff = []
                for edge in raw_staff_edges:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        name_obj = node.get("name") or {}
                        staff.append({
                            "role": edge.get("role", ""),
                            "id": node.get("id", 0),
                            "name": name_obj.get("userPreferred") or name_obj.get("full") or name_obj.get("native") or "",
                            "image": (node.get("image") or {}).get("large", "")
                        })

                status = media.get("status") or ""

                information = {
                    "status":             status,
                    "format":             media.get("format") or "",
                    "chapters":           media.get("chapters") or 0,
                    "volumes":            media.get("volumes") or 0,
                    "startDate":          _date_str(_fuzzy_date(media.get("startDate"))),
                    "endDate":            _date_str(_fuzzy_date(media.get("endDate"))),
                    "averageScore":       media.get("averageScore") or 0,
                    "meanScore":          media.get("meanScore") or 0,
                    "popularity":         media.get("popularity") or 0,
                    "favourites":         media.get("favourites") or 0,
                    "source":             media.get("source") or "",
                    "genres":             media.get("genres") or [],
                    "synonyms":           media.get("synonyms") or [],
                    "titleRomaji":        (media.get("title") or {}).get("romaji")  or "",
                    "titleEnglish":       (media.get("title") or {}).get("english") or "",
                    "titleNative":        (media.get("title") or {}).get("native")  or "",
                    "tags": media.get("tags") or [],
                    "externalLinks": media.get("externalLinks") or []
                }

                self.mangaPageLoaded.emit(
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

    @Slot(int, bool)
    def toggleMangaFavourite(self, anilist_id: int, currently_favourite: bool) -> None:
        # currently_favourite is no longer used to compute anything — kept only
        # so the QML call site doesn't need to change. The emitted value always
        # comes from a fresh query made after the mutation confirms.
        def _run():
            try:
                self._begin_loading()
                self._gql(_TOGGLE_MANGA_FAVOURITE_MUTATION, {"mangaId": anilist_id})
                data   = self._gql(_MANGA_FAVOURITE_QUERY, {"id": anilist_id})
                is_fav = (data.get("Media") or {}).get("isFavourite", False)
                self.mangaFavouriteToggled.emit(anilist_id, is_fav)
                print("Manga Favourite:", is_fav)
            except Exception as exc:
                self._emit_update_failure(exc)
            finally:
                self._end_loading()
        threading.Thread(target=_run, daemon=True).start()

    # All Character Page
    @Slot(int, int)
    def fetchAllCharactersPage(self, anilistId: int, page: int) -> None:
        is_first_page = page <= 1   # QML passes 1 for the initial load, currentPage+1 to load more

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()   # global spinner only for the first load
                data      = self._gql(_ALL_CHARACTERS_QUERY, {"id": anilistId, "page": page if page > 0 else 1})
                media     = data.get("Media") or {}
                char_con = media.get("characters") or {}
                has_next  = (char_con.get("pageInfo") or {}).get("hasNextPage", False)

                raw_characters = char_con.get("edges") or []
                characters = []
                for edge in raw_characters:
                    if edge.get("node") is not None and edge.get("node") != {}:
                        node = edge["node"]
                        characters.append({
                            "characterId": node.get("id", 0),
                            "name":        (node.get("name") or {}).get("full") or (node.get("name") or {}).get("native", "") or "",
                            "image":       (node.get("image") or {}).get("large", ""),
                            "role":        edge.get("role", ""),
                        })

                self.allCharactersPageLoaded.emit(json.dumps({
                    "anilistId":   anilistId,
                    "page":        page,
                    "characters":  characters,
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
                # Always emit allCharactersPageLoaded too, even here — QML has exactly
                # one handler to clear its loading flags in, regardless of outcome.
                self.allCharactersPageLoaded.emit(json.dumps({
                    "anilistId":   anilistId,
                    "page":        page,
                    "characters":  [],
                    "hasNextPage": False,
                    "isError":     True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    # All Character Page
    @Slot(int, int)
    def fetchAllStaffPage(self, anilistId: int, page: int) -> None:
        is_first_page = page <= 1   # QML passes 1 for the initial load, currentPage+1 to load more

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()   # global spinner only for the first load
                data      = self._gql(_ALL_STAFF_QUERY, {"id": anilistId, "page": page if page > 0 else 1})
                media     = data.get("Media") or {}
                staff_con = media.get("staff") or {}
                has_next  = (staff_con.get("pageInfo") or {}).get("hasNextPage", False)

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

                self.allStaffPageLoaded.emit(json.dumps({
                    "anilistId":   anilistId,
                    "page":        page,
                    "staff":  staff,
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
                self.allStaffPageLoaded.emit(json.dumps({
                    "anilistId":   anilistId,
                    "page":        page,
                    "staff":  [],
                    "hasNextPage": False,
                    "isError":     True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

        threading.Thread(target=_run, daemon=True).start()

    # Search

    @Slot(str, str, int)
    def search(self, search_type: str, query: str, page: int) -> None:
        """Backs SearchPage.qml. search_type is one of HomePage's searchTypes
        strings ("Anime", "Manga", "Characters", "Staff", "Studios", "Users").

        QML can fire a new call before the previous one resolves — every
        keystroke, once debounced, is still a new call — so exactly like
        fetchFollowing/fetchFollowers, a generation counter is used to make
        sure only the most recently requested page/query ever gets emitted,
        regardless of the order the network responses actually arrive in."""
        is_first_page = page <= 1   # QML passes 1 for a fresh search, currentPage+1 to load more

        self._search_gen += 1
        my_gen = self._search_gen

        query_text = (query or "").strip()
        if not query_text:
            # Nothing to search — respond immediately so QML can clear its
            # results without waiting on a network round trip.
            self.searchResultsLoaded.emit(json.dumps({
                "searchType": search_type, "query": query_text, "page": 1,
                "results": [], "hasNextPage": False, "isError": False,
            }))
            return

        config = _SEARCH_CONFIG.get(search_type)
        if config is None:
            self.errorOccurred.emit(f"Unknown search type: {search_type}")
            return
        gql_query, extra_variables, field_name, flatten = config

        def _run():
            try:
                if is_first_page:
                    self._begin_loading()
                data = self._gql(gql_query, {
                    "search": query_text,
                    "page":   page if page > 0 else 1,
                    **extra_variables,
                })
                if my_gen != self._search_gen:
                    return   # a newer search/page request has since superseded this one
                page_obj = data.get("Page") or {}
                has_next = (page_obj.get("pageInfo") or {}).get("hasNextPage", False)

                self.searchResultsLoaded.emit(json.dumps({
                    "searchType":  search_type,
                    "query":       query_text,
                    "page":        page,
                    "results":     flatten(page_obj.get(field_name)),
                    "hasNextPage": has_next,
                    "isError":     False,
                }))
            except Exception as exc:
                if my_gen != self._search_gen:
                    return
                self.errorOccurred.emit(str(exc))
                self.searchResultsLoaded.emit(json.dumps({
                    "searchType": search_type, "query": query_text, "page": page,
                    "results": [], "hasNextPage": False, "isError": True,
                }))
            finally:
                if is_first_page:
                    self._end_loading()

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

    @Slot(str)
    def copyToClipboard(self, text: str) -> None:
        """Copy an arbitrary string (e.g. a video/audio direct link) to the
        system clipboard. Used by the Opening/Ending Themes section's
        'Copy link' actions."""
        QGuiApplication.clipboard().setText(text)

    @Slot(str, str)
    @Slot(str, str, str)
    def openInExternalPlayer(self, url: str, player: str, cover_image: str = "") -> None:
        """Best-effort launch of a local media player binary (mpv/vlc) with
        `url` as its argument, via QProcess.startDetached.

        Deliberately NOT using mpv:// or vlc:// url schemes here: neither is
        registered by the players themselves on any platform — both require
        a separately-installed third-party protocol handler that most users
        won't have — so a link built on either scheme would silently do
        nothing for most people. Shelling out to the real binary works
        as long as it's on PATH, with no extra setup required."""

        print(f"Cover image: {cover_image}")

        binaries = {"mpv": "mpv", "vlc": "vlc"}
        program  = binaries.get(player.lower())
        if not program:
            self.errorOccurred.emit(f"Unknown player: {player}")
            return

        args = [url]
        if program == "mpv":
            args = ["--force-window=yes"]

            if cover_image:
                args.append(f"--cover-art-file={cover_image}")
            args.append(url)

        try:
            started, _pid = QProcess.startDetached(program, args)
        except Exception as exc:
            started = False
            print(f"[AniListService] failed to launch {program}: {exc}")

        if not started:
            self.errorOccurred.emit(
                f"Couldn't start {player.upper()}. Make sure it's installed and on your PATH."
            )
