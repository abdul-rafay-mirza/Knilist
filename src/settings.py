from PySide6.QtCore import Property, QObject, Slot, Signal, QStandardPaths, QSettings

class Settings(QObject):
    aboutExpandedChanged = Signal()

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

    aboutExpanded = Property(
        bool,
        getAboutExpanded,
        setAboutExpanded,
        notify=aboutExpandedChanged
    )