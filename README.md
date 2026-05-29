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

Then run the following command to build and install it using `pipx`:

```
pipx install --force --system-site-packages ~/Projects/Knilist
```

It should now show up in your application launcher as **Knilist**.