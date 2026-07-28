import sys
import configparser
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QPalette, QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, Signal, QStandardPaths, QSettings
from PySide6.QtQuickControls2 import QQuickStyle


# (.colors section, key, target QPalette role) — verified against KDE's own
# KColorScheme::createApplicationPalette() in kcolorscheme.cpp. Omits the
# Light/Midlight/Mid/Dark/Shadow "shade" roles, which KDE derives with a
# contrast-aware shading algorithm rather than a direct file value — a real
# gap, but a minor, mostly-bevel-and-border one; everything else here is a
# straight ports of the actual role source.
_PALETTE_ROLE_MAP = [
    ("Colors:Window", "BackgroundNormal", QPalette.ColorRole.Window),
    ("Colors:Window", "ForegroundNormal", QPalette.ColorRole.WindowText),
    ("Colors:View", "BackgroundNormal", QPalette.ColorRole.Base),
    ("Colors:View", "BackgroundAlternate", QPalette.ColorRole.AlternateBase),
    ("Colors:View", "ForegroundNormal", QPalette.ColorRole.Text),
    ("Colors:View", "ForegroundInactive", QPalette.ColorRole.PlaceholderText),
    ("Colors:View", "ForegroundLink", QPalette.ColorRole.Link),
    ("Colors:View", "ForegroundVisited", QPalette.ColorRole.LinkVisited),
    ("Colors:Button", "BackgroundNormal", QPalette.ColorRole.Button),
    ("Colors:Button", "ForegroundNormal", QPalette.ColorRole.ButtonText),
    ("Colors:Selection", "BackgroundNormal", QPalette.ColorRole.Highlight),
    ("Colors:Selection", "BackgroundNormal", QPalette.ColorRole.Accent),
    ("Colors:Selection", "ForegroundNormal", QPalette.ColorRole.HighlightedText),
    ("Colors:Tooltip", "BackgroundNormal", QPalette.ColorRole.ToolTipBase),
    ("Colors:Tooltip", "ForegroundNormal", QPalette.ColorRole.ToolTipText),
]


class ThemeChanger(QObject):
    themesChanged = Signal()

    def __init__(self, engine):
        super().__init__()
        self.engine = engine
        self._settings = QSettings()

        self._themes = []
        self._load_kde_color_schemes()

    def _load_kde_color_schemes(self):
        """Scans system and user directories for installed KDE Color Schemes."""
        search_paths = QStandardPaths.locateAll(
            QStandardPaths.StandardLocation.GenericDataLocation,
            "color-schemes",
            QStandardPaths.LocateDirectory
        )

        # Map display Name -> {id, path}. "id" is the ColorScheme= value
        # (kept around for reference/logging); "path" is what applyTheme
        # actually reads now, since theming is done in-process rather than
        # by shelling out to a system-wide CLI tool.
        theme_map = {}

        for path_str in search_paths:
            path = Path(path_str)
            if not path.exists():
                continue

            for color_file in path.glob("*.colors"):
                try:
                    config = configparser.ConfigParser(interpolation=None)
                    config.read(color_file, encoding="utf-8")
                    name = config.get("General", "Name", fallback=color_file.stem)
                    scheme_id = config.get("General", "ColorScheme", fallback=color_file.stem)
                    theme_map[name] = {"id": scheme_id, "path": color_file}
                except Exception:
                    theme_map[color_file.stem] = {"id": color_file.stem, "path": color_file}

        sorted_names = sorted(theme_map.keys())
        self._themes = []
        for name in sorted_names:
            entry = theme_map[name]
            self._themes.append({
                "name": name,
                "id": entry["id"],
                "path": entry["path"],
            })

    @Slot(result=list)
    def getThemes(self):
        return [t["name"] for t in self._themes]

    def _build_palette(self, colors_path):
        """Reads a KDE .colors scheme file and builds a QPalette from it.
        This mirrors what KColorSchemeManager::activateScheme() does
        internally in the C++ demo, but without needing that class — there
        is currently no usable PySide6/PyQt binding for KConfigWidgets, so
        this reimplements the relevant slice directly. .colors values are
        "R,G,B" strings, not hex, hence the manual split below."""
        config = configparser.ConfigParser(interpolation=None)
        config.read(colors_path, encoding="utf-8")

        palette = QPalette()

        for section, key, role in _PALETTE_ROLE_MAP:
            if not config.has_option(section, key):
                continue

            parts = config.get(section, key).split(",")
            if len(parts) != 3:
                continue

            red = int(parts[0])
            green = int(parts[1])
            blue = int(parts[2])
            color = QColor(red, green, blue)

            palette.setColor(QPalette.ColorGroup.Active, role, color)
            palette.setColor(QPalette.ColorGroup.Inactive, role, color)

        return palette

    @Slot(str)
    def applyTheme(self, name):
        """Applies a KDE color scheme to THIS application only. Two things
        happen, in this order, mirroring KColorSchemeManager::activateScheme()
        in the C++ demo:

        1. qApp gets a "KDE_COLOR_SCHEME_PATH" property pointing at the
           .colors file. This is the actual mechanism — KColorScheme's own
           default config lookup (used internally by Kirigami/qqc2-desktop-
           style for Theme.textColor, Theme.backgroundColor, etc.) checks
           this exact property before falling back to the system kdeglobals.
           Without it, Kirigami-native content ignores QPalette entirely and
           keeps rendering the system scheme — which is what was happening.
        2. QPalette is set for the smaller slice of controls that actually
           read QPalette directly (plain QQC2 fallback bits, native dialogs).

        The property must be set BEFORE setPalette(), since the desktop
        style's palette-change handler reads it at that point. Neither step
        writes to ~/.config/kdeglobals or touches any other running app —
        plasma-apply-colorscheme is not used anywhere in this file."""
        entry = next(
            (t for t in self._themes if t["name"] == name), None
        )
        if entry is None:
            return

        app = QGuiApplication.instance()
        if app is None:
            return

        try:
            palette = self._build_palette(entry["path"])
        except Exception as e:
            print(f"Failed to read scheme '{name}':", e, file=sys.stderr)
            return

        app.setProperty("KDE_COLOR_SCHEME_PATH", str(entry["path"]))
        app.setPalette(palette)

        self._settings.setValue("theme/id", entry["id"])

    def restoreTheme(self):
        theme_id = self._settings.value("theme/id", "", str)

        if not theme_id:
            return

        entry = next(
            (t for t in self._themes if t["id"] == theme_id),
            None
        )

        if entry:
            self.applyTheme(entry["name"])

    @Slot(result=str)
    def currentTheme(self):
        theme_id = self._settings.value("theme/id", "", str)

        entry = next(
            (t for t in self._themes if t["id"] == theme_id),
            None
        )

        return entry["name"] if entry else ""
