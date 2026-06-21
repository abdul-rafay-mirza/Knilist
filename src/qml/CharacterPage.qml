import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: characterPage
    title: "Character Page"

    property var characterId
    property var name
    property var image
    property var role

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            id: characterImage
            // Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            clip: true
            color: Kirigami.Theme.alternateBackgroundColor

            Image {
                anchors.fill: parent
                source: characterPage.image || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin:  Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing

            Controls.Label { text: "Character ID: " + characterPage.characterId }
            Controls.Label { text: "name: " + characterPage.name }
            Controls.Label { text: "role: " + characterPage.role }
        }
    }
}