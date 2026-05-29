#!/usr/bin/env python3
import os
import sys
import signal
from importlib.resources import files

from PySide6.QtGui  import QGuiApplication
from PySide6.QtCore import QUrl
from PySide6.QtQml  import QQmlApplicationEngine

from .auth            import AuthManager
from .anilist_service import AniListService


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

    engine.rootContext().setContextProperty("authManager",    auth)
    engine.rootContext().setContextProperty("anilistService", service)

    base_path = files("knilist").joinpath("qml", "Main.qml")
    engine.load(QUrl(str(base_path)))

    if not engine.rootObjects():
        sys.exit(-1)

    if auth.isLoggedIn:
        service.fetchAnime()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
