import os
import stat
import threading
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib    import Path
from urllib.parse import urlparse, parse_qs

import keyring
from PySide6.QtCore import QObject, Signal, Slot, Property

from .config import (
    ANILIST_CLIENT_ID,
    ANILIST_CLIENT_SECRET,
    OAUTH_REDIRECT_PORT,
    OAUTH_TOKEN_URL,
)

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


# ── Callback HTML pages ───────────────────────────────────────────────────────

_SUCCESS_HTML = b"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>knilist \xe2\x80\x94 Login</title>
  <style>
    body { font-family: sans-serif; display: flex; align-items: center;
           justify-content: center; height: 100vh; margin: 0;
           background: #0d1117; color: #e6e6e6; }
    .box { text-align: center; padding: 2rem 3rem;
           border-radius: 14px; background: #1a1f2e; }
    h2 { margin: 0 0 .5rem; } p { opacity: .6; margin: 0; }
  </style>
</head>
<body>
<div class="box">
  <h2>\u2714 Logged in!</h2>
  <p>You can close this tab and return to knilist.</p>
</div>
</body>
</html>"""

_ERROR_HTML = b"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>knilist \xe2\x80\x94 Error</title></head>
<body style="font-family:sans-serif;background:#0d1117;color:#e6e6e6;
             display:flex;align-items:center;justify-content:center;height:100vh">
  <div style="text-align:center">
    <h2>\u2718 Login failed</h2><p>No authorisation code received.</p>
  </div>
</body>
</html>"""


# ── AuthManager ───────────────────────────────────────────────────────────────

class AuthManager(QObject):
    loginSuccess      = Signal()
    loginFailed       = Signal(str)
    logoutDone        = Signal()
    loginStateChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        # Load persisted values from ~/.config/knilist/.env on startup
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
        if not ANILIST_CLIENT_ID or not ANILIST_CLIENT_SECRET:
            self.loginFailed.emit(
                "ANILIST_CLIENT_ID or ANILIST_CLIENT_SECRET is empty.\n"
                "Add them to ~/.config/knilist/.env"
            )
            return

        redirect_uri = f"http://localhost:{OAUTH_REDIRECT_PORT}"
        auth_url = (
            "https://anilist.co/api/v2/oauth/authorize"
            f"?client_id={ANILIST_CLIENT_ID}"
            f"&redirect_uri={redirect_uri}"
            "&response_type=code"
        )

        def _run_server():
            received: dict[str, str | None] = {"code": None}

            class _Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    parsed = urlparse(self.path)
                    qs     = parse_qs(parsed.query)
                    code   = (qs.get("code") or [None])[0]

                    if code:
                        received["code"] = code
                        body = _SUCCESS_HTML
                    else:
                        body = _ERROR_HTML

                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    threading.Thread(target=srv.shutdown, daemon=True).start()

                def log_message(self, *_):
                    pass

            srv = HTTPServer(("localhost", OAUTH_REDIRECT_PORT), _Handler)
            srv.serve_forever()

            code = received["code"]
            if not code:
                self.loginFailed.emit("Authentication cancelled or timed out.")
                return

            # Exchange code for access token
            try:
                import requests as _req
                resp = _req.post(
                    OAUTH_TOKEN_URL,
                    json={
                        "grant_type":    "authorization_code",
                        "client_id":     ANILIST_CLIENT_ID,
                        "client_secret": ANILIST_CLIENT_SECRET,
                        "redirect_uri":  redirect_uri,
                        "code":          code,
                    },
                    headers={"Content-Type": "application/json",
                             "Accept":       "application/json"},
                    timeout=15,
                )
                resp.raise_for_status()
                token = resp.json().get("access_token")
            except Exception as exc:
                self.loginFailed.emit(f"Token exchange failed: {exc}")
                return

            if token:
                _store(_KEY_TOKEN, token)
                self._token = token
                self.loginSuccess.emit()
                self.loginStateChanged.emit()
            else:
                self.loginFailed.emit("No access_token in AniList response.")

        threading.Thread(target=_run_server, daemon=True).start()
        webbrowser.open(auth_url)

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
                "misconfigured, or unavailable — check your system's "
                "keyring/credential manager directly, or run `python3 -c "
                "\"import keyring; print(keyring.get_keyring())\"` "
                "to see which backend is active."
            )