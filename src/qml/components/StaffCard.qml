import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.AbstractButton {
    id: root

    property int    staffId: 0
    property string name:    ""
    property string role:    ""
    property string image:   ""

    signal cardClicked(int staffId)

    implicitWidth: 260
    padding:       Kirigami.Units.smallSpacing

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color:  root.hovered ? Kirigami.Theme.hoverColor : "transparent"
        border.width: 1
        border.color: Kirigami.Theme.separatorColor
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        // Thumbnail
        Rectangle {
            Layout.preferredWidth:  100
            Layout.preferredHeight: 100
            radius: Kirigami.Units.cornerRadius
            clip:   true
            color:  Kirigami.Theme.backgroundColor

            Image {
                anchors.fill: parent
                source:       root.image
                fillMode:     Image.PreserveAspectCrop
                smooth:       true
                asynchronous: true
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:           "actor"
                visible:          root.image === ""
                implicitWidth:    50
                implicitHeight:   50
                color:            Kirigami.Theme.disabledTextColor
            }
        }

        // Name + role
        ColumnLayout {
            Layout.fillWidth: true
            spacing:          2

            Controls.Label {
                Layout.fillWidth: true
                text:             root.name
                elide:            Text.ElideRight
                color:            Kirigami.Theme.textColor
                font.weight:      Font.Medium
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            Controls.Label {
                Layout.fillWidth: true
                text:             root.role
                opacity: 0.7
                font.pointSize:   Kirigami.Theme.smallFont.pointSize
                elide:            Text.ElideRight
            }
        }
    }

    onClicked: root.cardClicked(root.staffId)
}
