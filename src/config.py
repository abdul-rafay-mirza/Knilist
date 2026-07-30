import os
from pathlib import Path

# ── AniList OAuth credentials ─────────────────────────────────────────────────
# Pin flow: no client secret needed. AniList doesn't support the implicit
# grant (response_type=token) directly — it errors with unsupported_grant_type —
# but does support it via the auth-pin redirect, where the token is shown as
# plain text on an AniList-hosted page instead of being sent to a redirect_uri
# we control. Requires the app's Redirect URL (in AniList's dev settings) to
# be set to https://anilist.co/api/v2/oauth/pin.
ANILIST_CLIENT_ID: str = "47347"

ANILIST_GRAPHQL_URL:     str = "https://graphql.anilist.co"
ANIMETHEMES_GRAPHQL_URL: str = "https://graphql.animethemes.moe"
