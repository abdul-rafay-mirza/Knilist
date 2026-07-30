from PySide6.QtCore import QObject, Property


class About(QObject):
    """Static application metadata exposed to QML for Kirigami.AboutPage.

    aboutData holds a dict shaped like KAboutData (displayName, authors,
    licenses, etc.) -- Kirigami.AboutPage documents that its aboutData
    property accepts any object with this shape, not just a real
    KAboutData instance, so a plain dict is enough:
    https://api.kde.org/qml-org-kde-kirigami-aboutpage.html
    """

    def __init__(self):
        super().__init__()
        self._about_data = {
            "displayName": "Knilist",
            "productName": "knilist",
            "componentName": "knilist",
            "version": "0.1.0",
            "shortDescription": "A native AniList desktop client built with Python, Qt and Kirigami.",
            "homepage": "https://github.com/abdul-rafay-mirza/Knilist",
            "bugAddress": "https://github.com/abdul-rafay-mirza/Knilist/issues",
            "otherText": (
                "Knilist is an unofficial AniList client and is not "
                "affiliated with or endorsed by AniList."
            ),
            "authors": [
                {
                    "name": "Abdul Rafay",
                    "task": "Developer",
                    "emailAddress": "abdulrafey79@yahoo.com",
                    "webAddress": "",
                    "ocsUsername": "",
                }
            ],
            "credits": [],
            "translators": [],
            "licenses": [
                {
                    "name": "GPL-3.0-or-later",
                    "spdx": "GPL-3.0-or-later",
                }
            ],
            "copyrightStatement": "© 2026 Abdul Rafay",
            "desktopFileName": "com.github.abdul-rafay-mirza.knilist",
            "programIconName": "com.github.abdul-rafay-mirza.knilist",
        }

    def getAboutData(self):
        return self._about_data

    # constant=True: this never changes after construction, so no notify
    # signal is needed.
    aboutData = Property("QVariantMap", getAboutData, constant=True)
