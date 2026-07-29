from PySide6.QtCore import Property, QObject, Slot, Signal, QSettings

class Settings(QObject):
    aboutExpandedChanged = Signal()
    animeListSelectedStatusChanged = Signal()
    mangaListSelectedStatusChanged = Signal()

    def __init__(self):
        super().__init__()
        self._settings = QSettings()

    def getAboutExpanded(self):
        return self._settings.value("profile/aboutExpanded", False, bool)

    def setAboutExpanded(self, value):
        if value == self.getAboutExpanded():
            return
        self._settings.setValue("profile/aboutExpanded", value)
        self.aboutExpandedChanged.emit()

    def getAnimeListSelectedStatus(self):
        return self._settings.value("listStatus/anime", "ALL", str)

    def setAnimeListSelectedStatus(self, value):
        if value == self.getAnimeListSelectedStatus():
            return
        self._settings.setValue("listStatus/anime", value)
        self.animeListSelectedStatusChanged.emit()

    def getMangaListSelectedStatus(self):
        return self._settings.value("listStatus/manga", "ALL", str)

    def setMangaListSelectedStatus(self, value):
        if value == self.getMangaListSelectedStatus():
            return
        self._settings.setValue("listStatus/manga", value)
        self.mangaListSelectedStatusChanged.emit()

    aboutExpanded = Property(
        bool,
        getAboutExpanded,
        setAboutExpanded,
        notify=aboutExpandedChanged
    )

    animeListSelectedStatus = Property(
        str,
        getAnimeListSelectedStatus,
        setAnimeListSelectedStatus,
        notify=animeListSelectedStatusChanged
    )

    mangaListSelectedStatus = Property(
        str,
        getMangaListSelectedStatus,
        setMangaListSelectedStatus,
        notify=mangaListSelectedStatusChanged
    )