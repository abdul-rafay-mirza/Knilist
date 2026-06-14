import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: mediaPage
    title: "Manga Page"

    property var anilistId

    Controls.Label {
        text: "Manga ID: " + anilistId
    }
}