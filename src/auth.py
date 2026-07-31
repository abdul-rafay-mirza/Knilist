import webbrowser

import keyring
from PySide6.QtCore import QObject, Signal, Slot, Property

from .config import ANILIST_CLIENT_ID

# ── Keyring service name ───────────────────────────────────────────────────────
_SERVICE = "knilist"

_KEY_TOKEN    = "token"
_KEY_USER_ID  = "user_id"
_KEY_USERNAME = "username"


def _store(key: str, value: str) -> None:
    keyring.set_password(_SERVICE, key, value)


def _load(key: str) -> str | None:
    return keyring.get_password(_SERVICE, key) or None


def _delete(key: str, retries: int = 2) -> bool:
    """Delete a keyring entry. Returns True if the entry is now gone
    (either it was deleted just now, or it never existed), False if the
    backend raised something other than "no such entry" — which means
    the value may still be there on next launch.

    keyring.errors.PasswordDeleteError is raised both for "no such
    entry" (fine — nothing to remove, treat as success) and for real
    backend failures (NOT fine — swallowing this unconditionally is
    what let logout silently no-op against some backends, e.g. a
    transient hiccup in whichever OS credential store keyring is
    backed by, where the daemon handle is briefly unresponsive, while
    still emitting logoutDone as if it had worked).

    Transient backend errors are common enough that a single failed
    attempt shouldn't be taken as final — retry a couple of times
    with a short backoff before concluding the delete genuinely
    failed.
    """
    import time

    for attempt in range(retries + 1):
        try:
            keyring.delete_password(_SERVICE, key)
            return True
        except keyring.errors.PasswordDeleteError:
            # Confirm this was actually a "not found" case before treating
            # it as harmless. If get_password still returns a value after
            # a PasswordDeleteError, the delete genuinely failed rather
            # than the entry having been absent already.
            if _load(key) is None:
                return True
            if attempt < retries:
                time.sleep(0.3)

    return False


# ── AuthManager ───────────────────────────────────────────────────────────────

class AuthManager(QObject):
    loginSuccess            = Signal()
    loginFailed             = Signal(str)
    logoutDone              = Signal()
    loginStateChanged       = Signal()
    # Fired right after submitToken stores a pasted token — before it's
    # been checked against AniList. app.py listens for this and issues a
    # Viewer query via AniListService; that call's outcome decides
    # whether loginSuccess (verified) or loginFailed (rejected, token
    # rolled back) fires next. Kept separate from loginSuccess so nothing
    # downstream (fetchAnime/fetchManga/etc., all wired to loginSuccess)
    # runs against a token that turns out to be garbage.
    tokenPendingVerification = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        # Load persisted values from the OS keyring on startup
        self._token    = _load(_KEY_TOKEN)
        self._user_id  = _load(_KEY_USER_ID)  or ""
        self._username = _load(_KEY_USERNAME) or ""

    @Property(bool, notify=loginStateChanged)
    def isLoggedIn(self) -> bool:
        return bool(self._token)

    @Property(str, notify=loginStateChanged)
    def userId(self) -> str:
        return self._user_id

    @Property(str, notify=loginStateChanged)
    def username(self) -> str:
        return self._username

    def token(self) -> str:
        return self._token or ""

    def setUserInfo(self, user_id: str, username: str) -> None:
        self._user_id  = user_id
        self._username = username
        _store(_KEY_USER_ID,  user_id)
        _store(_KEY_USERNAME, username)
        self.loginStateChanged.emit()

    @Slot()
    def login(self) -> None:
        # Pin flow: AniList's app Redirect URL must be set to
        # https://anilist.co/api/v2/oauth/pin — with that in place,
        # AniList ignores any redirect_uri we'd send here and instead
        # shows the token as plain text on its own page for the user
        # to copy. So there's nothing to listen for locally; login()
        # just opens the browser and waits for submitToken().
        if not ANILIST_CLIENT_ID:
            self.loginFailed.emit("ANILIST_CLIENT_ID is empty.")
            return

        auth_url = (
            "https://anilist.co/api/v2/oauth/authorize"
            f"?client_id={ANILIST_CLIENT_ID}"
            "&response_type=token"
        )
        webbrowser.open(auth_url)

    @Slot(str)
    def submitToken(self, token: str) -> None:
        """Called from LoginPage once the user pastes the token AniList
        showed them on the pin page. Replaces the old local-server +
        token-exchange flow entirely — the token arrives already-issued,
        so there's no code to exchange and no client_secret involved.

        A pasted string could be malformed, truncated, or copied wrong,
        so this doesn't confirm login on its own. It stores the token
        provisionally and emits tokenPendingVerification; app.py answers
        that by running a Viewer query through AniListService (which
        already needs a valid token to succeed) and then calls back into
        confirmVerified() or rejectVerification() below.
        """
        token = token.strip()
        if not token:
            self.loginFailed.emit("Paste the token AniList gave you.")
            return

        _store(_KEY_TOKEN, token)
        self._token = token
        # isLoggedIn flips true here so token() is available for the
        # verification call itself — AniListService._gql reads
        # self._auth.token() at call time, so this needs to happen
        # before app.py's handler runs the Viewer query.
        self.loginStateChanged.emit()
        self.tokenPendingVerification.emit()

    @Slot()
    def confirmVerified(self) -> None:
        """Called by app.py once the post-submitToken Viewer query
        succeeds. Finalises what submitToken started provisionally."""
        self.loginSuccess.emit()

    @Slot(str)
    def rejectVerification(self, message: str) -> None:
        """Called by app.py if the post-submitToken Viewer query fails —
        AniList didn't recognise the pasted token. Rolls back exactly
        what submitToken did: clears the keyring entry and in-memory
        token, then flips isLoggedIn back to false so LoginPage stays
        up instead of showing a logged-in UI backed by a dead token."""
        _delete(_KEY_TOKEN)
        self._token = None
        self.loginStateChanged.emit()
        self.loginFailed.emit(message)

    @Slot()
    def logout(self) -> None:
        token_cleared = _delete(_KEY_TOKEN)
        _delete(_KEY_USER_ID)
        _delete(_KEY_USERNAME)

        # Always clear in-memory state and flip isLoggedIn for this
        # session, regardless of whether the keyring backend actually
        # persisted the deletion — the user asked to be logged out now,
        # and that much is under our control even if the backend is
        # flaky.
        self._token    = None
        self._user_id  = ""
        self._username = ""
        self.logoutDone.emit()
        self.loginStateChanged.emit()

        # But if the token specifically didn't actually get removed
        # from the keyring, __init__ will reload it on the next launch
        # and silently log the user back in. Surface that now instead
        # of letting it resurface later as an unexplained "why am I
        # still logged in" — token_cleared is False only when the
        # backend raised something other than "no such entry" (see
        # _delete's docstring).
        if not token_cleared:
            # _delete() already retried a few times internally before
            # reporting failure here, so this isn't a one-off transient
            # blip — the OS credential store still has the old token
            # stored under this service name, and __init__ will reload
            # it next launch, silently logging the user back in as if
            # logout never happened. Surfacing that now (rather than
            # letting it resurface as an unexplained "why am I logged
            # in again") is the whole point of tracking token_cleared
            # separately from the in-memory state reset above.
            self.loginFailed.emit(
                "Logged out for this session, but your saved token "
                "could not be removed from your OS credential store "
                "and will likely log you back in next launch. This "
                "usually means the credential store is locked, "
                "misconfigured, or unavailable. Check your system's "
                "keyring/credential manager directly. (Check in "
                "KWalletManager GUI and delete knilist entry and also "
                "run the command \"secret-tool search service knilist\" "
                "and make sure it does not show anything.)"
            )
