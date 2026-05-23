# Knilist

clone the repo

Copy the `.desktop` file to `~/.local/share/applications`

`cp ~/Projects/Knilist/com.github.abdul-rafay-mirza.knilist.desktop ~/.local/share/applications`

you also need to generate an Anilist API Client using the link `https://anilist.co/settings/developer`. set Redirect URL to `http://localhost:8765` and name it `knilist`

you need to make a .env file in `~/.config/knilist/`

`mkdir ~/.config/knilist/`
`cd ~/.config/knilist/`
`touch .env`
and then add the following in the .env file, replacing the strings with your Anilist Api Client ID and Secret:

ANILIST_CLIENT_ID=""
ANILIST_CLIENT_SECRET=""


Then run `pipx install --force --system-site-packages ~/Projects/Knilist` to build it.

It should now show up in the application launcher as `Knilist`