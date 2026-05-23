# ──────────────────────────────────────────────────────────────────────────────
# AniList OAuth app config
#
# 1. Go to https://anilist.co/settings/developer  →  "Create New Client"
# 2. Set "Redirect URL" to exactly:  http://localhost:8765
# 3. Paste the Client ID below.
# ──────────────────────────────────────────────────────────────────────────────

ANILIST_CLIENT_ID:     str = "42088"   # ← from anilist.co/settings/developer
ANILIST_CLIENT_SECRET: str = "iZTeMemCGevgiY1enxPwREWYrYYSXFIjUaXL2wac"   # ← from the same page

OAUTH_REDIRECT_PORT: int  = 8765
GRAPHQL_URL:         str  = "https://graphql.anilist.co"
OAUTH_TOKEN_URL:     str  = "https://anilist.co/api/v2/oauth/token"

KEYRING_SERVICE:      str = "knilist"
KEYRING_TOKEN_KEY:    str = "anilist_token"
KEYRING_USERID_KEY:   str = "anilist_user_id"
KEYRING_USERNAME_KEY: str = "anilist_username"
