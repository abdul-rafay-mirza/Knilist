import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string relationType: "OTHER"
    property int    mediaId:      0
    property string mediaType:    "ANIME"
    property string format:       "MUSIC"
    property string title:        ""
    property string coverImage:   ""
    property string status:       "FINISHED"

    signal cardClicked(int mediaId)

    implicitWidth:  Kirigami.Units.gridUnit * 25
    implicitHeight: Kirigami.Units.gridUnit * 8

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius:       Kirigami.Units.smallSpacing
        color:        Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.separatorColor

        shadow.size:    Kirigami.Units.smallSpacing
        shadow.yOffset: 1
        shadow.color:   Qt.rgba(0, 0, 0, 0.2)

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing:         Kirigami.Units.smallSpacing

            // Relation type label
            Controls.Label {
                Layout.fillWidth: true
                text:      root.relationType.charAt(0) + root.relationType.slice(1).toLowerCase()
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color:     Kirigami.Theme.disabledTextColor
            }

            // Cover + info row
            RowLayout {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                // Cover image
                Kirigami.ShadowedImage {
                    Layout.preferredWidth:  Kirigami.Units.gridUnit * 3.5
                    Layout.fillHeight:      true
                    Layout.alignment:       Qt.AlignTop

                    source:    root.coverImage
                    fillMode:  Image.PreserveAspectCrop
                    color:     Kirigami.Theme.alternateBackgroundColor
                    radius:    Kirigami.Units.smallSpacing / 2

                    shadow.size:    Kirigami.Units.smallSpacing
                    shadow.yOffset: 1
                    shadow.color:   Qt.rgba(0, 0, 0, 0.3)
                }

                // Title + format/status
                ColumnLayout {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    spacing: 2

                    Controls.Label {
                        Layout.fillWidth: true
                        text:      root.title
                        wrapMode:  Text.WordWrap
                        font.weight: Font.Medium
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: {
                            const fmt = root.format.charAt(0) + root.format.slice(1).toLowerCase()
                            const st  = root.status.charAt(0) + root.status.slice(1).replace(/_/g, " ").toLowerCase()
                            return fmt + " · " + st
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color:     Kirigami.Theme.disabledTextColor
                        wrapMode:  Text.WordWrap
                    }
                }
            }
        }

        // Click handler
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.cardClicked(root.mediaId)

            HoverHandler {}
        }
    }
}