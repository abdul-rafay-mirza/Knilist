# Knilist

![Knilist Screenshot](screenshots/knilist_screenshot.jpg)

> ⚠️ **Warning:** The app is still in active development, so expect missing features and bugs.

## About:

Knilist is an Anilist client for Linux written in QML Kirigami + Python. It is designed run best under KDE Plasma.

## Installation:

### Option A: Arch Linux (pacman)

1. Clone the repository to your local machine in `~/Projects`.

```
cd ~/Projects
```
```
git clone https://github.com/abdul-rafay-mirza/Knilist.git
```
```
cd ~/Projects/Knilist
```

2. Run the install script
```
bash install.sh
```

It should now show up in your application launcher as **Knilist**.

### Option B: Flatpak (any distro)

1. Make sure Flathub is added (needed for runtime dependencies):
```
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

2. Add the Knilist repository and install:
```
flatpak remote-add --if-not-exists knilist https://abdul-rafay-mirza.github.io/knilist-flatpak/knilist.flatpakrepo
```
```
flatpak install knilist com.github.abdulrafaymirza.knilist
```

During installation, Flatpak will prompt to install the following runtime dependency from Flathub if you don't already have it:
- `org.kde.Platform//6.11`

Confirm the prompt to proceed. These are one-time downloads shared by other Flatpak apps using the same runtime/base.

3. Run the app:
```
flatpak run com.github.abdulrafaymirza.knilist
```

## Uninstall:

### Arch Linux (pacman)
To completely uninstall the application, either run the uninstall script:
```
bash uninstall.sh
```
or alternatively, run:
```
sudo pacman -R knilist-git
```

### Flatpak
```
flatpak uninstall com.github.abdulrafaymirza.knilist
```

## Updating:

### Flatpak
```
flatpak update com.github.abdulrafaymirza.knilist
```

## Notes:
The `.desktop` file is located in:
```
/usr/share/applications/com.github.abdul-rafay-mirza.knilist.desktop
```
Pacman owns it there, so when you run `sudo pacman -R knilist-git`, it gets removed automatically along with everything else.

*(Flatpak installs manage their own `.desktop` file inside the sandbox — no manual cleanup needed there.)*