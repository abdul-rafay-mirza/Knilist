import os
from pathlib import Path

# ── AniList OAuth credentials (shared app credentials) ───────────────────────
ANILIST_CLIENT_ID:     str = "42088"
ANILIST_CLIENT_SECRET: str = "iZTeMemCGevgiY1enxPwREWYrYYSXFIjUaXL2wac"

OAUTH_REDIRECT_PORT: int = 8765
GRAPHQL_URL:         str = "https://graphql.anilist.co"
OAUTH_TOKEN_URL:     str = "https://anilist.co/api/v2/oauth/token"