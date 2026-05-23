"""
auth.py — AniList OAuth 2.0 (implicit grant) + KWallet / Secret Service storage.
"""

import threading
import webbrowser
from http.server    import HTTPServer, BaseHTTPRequestHandler
from urllib.parse   import urlparse, parse_qs

from PySide6.QtCore import QObject, Signal, Slot, Property

try:
    import keyring
    import keyring.errors
    # Probe for a working backend at import time.
    # get_password() on a dummy key is the only reliable way to detect
    # the "no backend" case before we actually need to store a secret.
    try:
        keyring.get_password("_knilist_probe", "_knilist_probe")
        _KEYRING_OK = True
    except keyring.errors.NoKeyringError:
        _KEYRING_OK = False
except ImportError:
    _KEYRING_OK = False

from .config import (
    ANILIST_CLIENT_ID,
    ANILIST_CLIENT_SECRET,
    OAUTH_REDIRECT_PORT,
    OAUTH_TOKEN_URL,
    KEYRING_SERVICE,
    KEYRING_TOKEN_KEY,
    KEYRING_USERID_KEY,
    KEYRING_USERNAME_KEY,
)

# ── Keyring helpers ───────────────────────────────────────────────────────────

_mem: dict[str, str] = {}

def _store(key: str, value: str) -> None:
    if _KEYRING_OK:
        try:
            keyring.set_password(KEYRING_SERVICE, key, value)
            return
        except Exception:
            pass
    _mem[key] = value

def _load(key: str) -> str | None:
    if _KEYRING_OK:
        try:
            return keyring.get_password(KEYRING_SERVICE, key)
        except Exception:
            pass
    return _mem.get(key)

def _delete(key: str) -> None:
    if _KEYRING_OK:
        try:
            keyring.delete_password(KEYRING_SERVICE, key)
        except Exception:
            pass
    _mem.pop(key, None)


# ── Callback page ─────────────────────────────────────────────────────────────

# ── Callback page ─────────────────────────────────────────────────────────────
# The code arrives as a plain query parameter (?code=XXX), so no JS tricks
# needed — the server reads it directly.

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
        self._token    = _load(KEYRING_TOKEN_KEY)
        self._user_id  = _load(KEYRING_USERID_KEY)   or ""
        self._username = _load(KEYRING_USERNAME_KEY) or ""

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
        _store(KEYRING_USERID_KEY,   user_id)
        _store(KEYRING_USERNAME_KEY, username)
        self.loginStateChanged.emit()

    @Slot()
    def login(self) -> None:
        if not ANILIST_CLIENT_ID or not ANILIST_CLIENT_SECRET:
            self.loginFailed.emit(
                "ANILIST_CLIENT_ID or ANILIST_CLIENT_SECRET is empty.\n"
                "Edit src/config.py with your AniList app credentials."
            )
            return

        redirect_uri = f"http://localhost:{OAUTH_REDIRECT_PORT}"

        # Step 1 — send the user to AniList to approve access
        auth_url = (
            "https://anilist.co/api/v2/oauth/authorize"
            f"?client_id={ANILIST_CLIENT_ID}"
            f"&redirect_uri={redirect_uri}"
            "&response_type=code"          # Authorization Code flow
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

                    # Shut down after the first request (success or failure)
                    threading.Thread(target=srv.shutdown, daemon=True).start()

                def log_message(self, *_):
                    pass

            srv = HTTPServer(("localhost", OAUTH_REDIRECT_PORT), _Handler)
            srv.serve_forever()

            code = received["code"]
            if not code:
                self.loginFailed.emit("Authentication cancelled or timed out.")
                return

            # Step 2 — exchange the authorisation code for an access token
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
                _store(KEYRING_TOKEN_KEY, token)
                self._token = token
                self.loginSuccess.emit()
                self.loginStateChanged.emit()
            else:
                self.loginFailed.emit("No access_token in AniList response.")

        threading.Thread(target=_run_server, daemon=True).start()
        webbrowser.open(auth_url)

    @Slot()
    def logout(self) -> None:
        _delete(KEYRING_TOKEN_KEY)
        _delete(KEYRING_USERID_KEY)
        _delete(KEYRING_USERNAME_KEY)
        self._token    = None
        self._user_id  = ""
        self._username = ""
        self.logoutDone.emit()
        self.loginStateChanged.emit()
