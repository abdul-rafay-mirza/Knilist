import os
from pathlib import Path
from dotenv import load_dotenv

# 1. Try standard Linux config path first
xdg_config = Path.home() / ".config" / "knilist" / ".env"

if xdg_config.exists():
    print(f"DEBUG: Loading from {xdg_config}")
    load_dotenv(dotenv_path=xdg_config)
else:
    # 2. Fallback to current directory (useful for local development)
    fallback_path = find_dotenv()
    print(f"DEBUG: Loading from fallback {fallback_path}")
    load_dotenv(fallback_path)

# ──────────────────────────────────────────────────────────────────────────────
# AniList OAuth app config
# ──────────────────────────────────────────────────────────────────────────────

# Read from the environment, fallback to an empty string if not found
ANILIST_CLIENT_ID:     str = os.getenv("ANILIST_CLIENT_ID", "")
ANILIST_CLIENT_SECRET: str = os.getenv("ANILIST_CLIENT_SECRET", "")

OAUTH_REDIRECT_PORT: int  = 8765
GRAPHQL_URL:         str  = "https://graphql.anilist.co"
OAUTH_TOKEN_URL:     str  = "https://anilist.co/api/v2/oauth/token"

KEYRING_SERVICE:      str = "knilist"
KEYRING_TOKEN_KEY:    str = "anilist_token"
KEYRING_USERID_KEY:   str = "anilist_user_id"
KEYRING_USERNAME_KEY: str = "anilist_username"