import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as Addons

Controls.AbstractButton {
    id: characterCard

    property int characterId: -1
    property string name: ""
    property string image: ""
    property string role: ""

    signal characterClicked(int characterId, string name)

    implicitWidth: 96
    implicitHeight: contentColumn.implicitHeight

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: characterCard.hovered ? Kirigami.Theme.hoverColor : "transparent"
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: Kirigami.Units.smallSpacing

        Addons.Avatar {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            Layout.alignment: Qt.AlignHCenter
            source: characterCard.image
            name: characterCard.name
        }

        Controls.Label {
            Layout.preferredWidth: 96
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: characterCard.name
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Controls.Label {
            Layout.preferredWidth: 96
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: characterCard.role
            opacity: 0.7
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideRight
        }
    }

    onClicked: {
        characterCard.characterClicked(characterCard.characterId, characterCard.name)
    }
}