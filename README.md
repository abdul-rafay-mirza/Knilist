# Knilist

> ⚠️ **Warning:** The app is still in active development, so expect missing features and bugs.

Clone the repository to your local machine in `~/Projects`.

```
cd ~/Projects
```
```
git clone https://github.com/abdul-rafay-mirza/Knilist.git
```
```
cd ~/Projects/Knilist
```
Copy the `.desktop` file to `~/.local/share/applications` so it appears in your launcher:

```
cp ~/Projects/Knilist/com.github.abdul-rafay-mirza.knilist.desktop ~/.local/share/applications
```

You also need to generate an AniList API Client using the link [https://anilist.co/settings/developer](https://anilist.co/settings/developer). Set the Redirect URL to `http://localhost:8765` and name it `knilist`.

You need to make a `.env` file in `~/.config/knilist/`:

```
mkdir ~/.config/knilist/
```

```
cd ~/.config/knilist/
```

```
touch .env
```

Open the `.env` file and add the following, replacing the empty strings with your actual AniList API Client ID and Secret:

```
ANILIST_CLIENT_ID="<add_here>"
ANILIST_CLIENT_SECRET="<add_here>"
```

Then run the following command to build and install it using `pipx`:

```
pipx install --force --system-site-packages ~/Projects/Knilist
```

It should now show up in your application launcher as **Knilist**.