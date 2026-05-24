"""
auth.py — AniList OAuth 2.0 (Authorization Code flow).

Token persistence: stored in ~/.config/knilist/.env alongside the API
credentials, using python-dotenv's set_key() to write individual keys.
The file is chmod 600 on creation so only the owning user can read it.
This follows the XDG config directory convention for user-private data.
"""

import os
import stat
import threading
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib    import Path
from urllib.parse import urlparse, parse_qs

from dotenv import load_dotenv, set_key, unset_key
from PySide6.QtCore import QObject, Signal, Slot, Property

from .config import (
    ANILIST_CLIENT_ID,
    ANILIST_CLIENT_SECRET,
    OAUTH_REDIRECT_PORT,
    OAUTH_TOKEN_URL,
)

# ── XDG config file used for all persistent state ─────────────────────────────
_CONFIG_DIR  = Path.home() / ".config" / "knilist"
_CONFIG_FILE = _CONFIG_DIR / ".env"

# Keys written into the .env file
_KEY_TOKEN    = "KNILIST_TOKEN"
_KEY_USER_ID  = "KNILIST_USER_ID"
_KEY_USERNAME = "KNILIST_USERNAME"


def _ensure_config_file() -> None:
    """Create the config dir + file if absent, and lock down permissions."""
    _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not _CONFIG_FILE.exists():
        _CONFIG_FILE.touch()
    # chmod 600 — owner read/write only
    _CONFIG_FILE.chmod(stat.S_IRUSR | stat.S_IWUSR)


def _store(key: str, value: str) -> None:
    _ensure_config_file()
    set_key(str(_CONFIG_FILE), key, value, quote_mode="never")


def _load(key: str) -> str | None:
    _ensure_config_file()
    # Re-read the file each time so we always get the latest value.
    # override=False would skip keys already in os.environ (the API creds);
    # we use a fresh dict instead to avoid polluting os.environ.
    from dotenv import dotenv_values
    values = dotenv_values(str(_CONFIG_FILE))
    return values.get(key) or None


def _delete(key: str) -> None:
    _ensure_config_file()
    unset_key(str(_CONFIG_FILE), key)


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
        _delete(_KEY_TOKEN)
        _delete(_KEY_USER_ID)
        _delete(_KEY_USERNAME)
        self._token    = None
        self._user_id  = ""
        self._username = ""
        self.logoutDone.emit()
        self.loginStateChanged.emit()
