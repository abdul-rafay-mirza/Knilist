#!/usr/bin/env python3
import os
import sys
import signal
from importlib.resources import files

from PySide6.QtGui  import QGuiApplication
from PySide6.QtCore import QUrl
from PySide6.QtQml  import QQmlApplicationEngine

from .auth                import AuthManager
from .anilist_service      import AniListService
from .anime_themes_service import AnimeThemesService


def main():
    if not os.environ.get("QT_QUICK_CONTROLS_STYLE"):
        os.environ["QT_QUICK_CONTROLS_STYLE"] = "org.kde.desktop"

    app = QGuiApplication(sys.argv)
    app.setDesktopFileName("com.github.abdul-rafay-mirza.knilist")
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    engine = QQmlApplicationEngine()

    auth    = AuthManager()
    service = AniListService(auth)
    auth.loginSuccess.connect(service.fetchAnime)
    auth.loginSuccess.connect(service.fetchManga)
    auth.loginSuccess.connect(service.fetchHomeProfile)
    auth.loginSuccess.connect(service.fetchProfile)

    anime_themes_service = AnimeThemesService()

    engine.rootContext().setContextProperty("authManager",       auth)
    engine.rootContext().setContextProperty("anilistService",    service)
    engine.rootContext().setContextProperty("animeThemesService", anime_themes_service)

    base_path = files("knilist").joinpath("qml", "Main.qml")
    engine.load(QUrl(str(base_path)))

    if not engine.rootObjects():
        sys.exit(-1)

    if auth.isLoggedIn:
        service.fetchAnime()
        service.fetchManga()
        service.fetchHomeProfile()
        service.fetchProfile()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
