#!/usr/bin/env python3

import os
import sys
import signal
from importlib.resources import files

from PySide6.QtGui import QGuiApplication
from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine

def main():
    """Needed to get proper KDE style outside of Plasma"""
    # This MUST happen before QGuiApplication is initialized!
    if not os.environ.get("QT_QUICK_CONTROLS_STYLE"):
        os.environ["QT_QUICK_CONTROLS_STYLE"] = "org.kde.desktop"

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    app.setDesktopFileName("com.github.abdul-rafay-mirza.knilist")

    """Needed to close the app with Ctrl+C"""
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    base_path = files('knilist').joinpath('qml', 'Main.qml')
    url = QUrl(f"{base_path}")
    engine.load(url)

    app.exec()

if __name__ == "__main__":
    main()