import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// MediaPage.qml
// A generic page which shows media details

Kirigami.Page {
    id: mediaPage
    title: "Media Page"

    property var anilistId

    Controls.Label {
        text: "Media ID: " + anilistId
    }
}