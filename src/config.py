import os
from pathlib import Path
from dotenv import load_dotenv

# Load from ~/.config/knilist/.env (created by user for API credentials,
# also used by auth.py to persist the session token)
xdg_config = Path.home() / ".config" / "knilist" / ".env"

if xdg_config.exists():
    print(f"DEBUG: Loading from {xdg_config}")
    load_dotenv(dotenv_path=xdg_config)
else:
    from dotenv import find_dotenv
    fallback_path = find_dotenv()
    print(f"DEBUG: Loading from fallback {fallback_path}")
    load_dotenv(fallback_path)

# ── AniList OAuth credentials (set by user) ───────────────────────────────────
ANILIST_CLIENT_ID:     str = os.getenv("ANILIST_CLIENT_ID", "")
ANILIST_CLIENT_SECRET: str = os.getenv("ANILIST_CLIENT_SECRET", "")

OAUTH_REDIRECT_PORT: int = 8765
GRAPHQL_URL:         str = "https://graphql.anilist.co"
OAUTH_TOKEN_URL:     str = "https://anilist.co/api/v2/oauth/token"
