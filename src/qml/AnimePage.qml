import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animePage
    title: "Anime Page"

    property var anilistId

    Controls.Label {
        text: "Anime ID: " + anilistId
    }
}