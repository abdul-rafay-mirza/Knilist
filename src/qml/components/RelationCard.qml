import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string relationType
    property int mediaId
    property string mediaType
    property string format
    property string title
    property string coverImage
    property string status

    signal cardClicked(int mediaId, string mediaType)

    implicitWidth:  Kirigami.Units.gridUnit * 25
    implicitHeight: Kirigami.Units.gridUnit * 8

    Kirigami.ShadowedRectangle {
        id: card
        anchors.fill: parent
        radius:       Kirigami.Units.smallSpacing
        color:        Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.separatorColor

        shadow.size:    Kirigami.Units.smallSpacing
        shadow.yOffset: 1
        shadow.color:   Qt.rgba(0, 0, 0, 0.2)

        RowLayout {
            anchors.fill: parent
            spacing:      0

            // Cover image, flush with the card's left edge
            Kirigami.ShadowedImage {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                Layout.fillHeight:     true
                Layout.rightMargin: Kirigami.Units.smallSpacing

                source:   root.coverImage
                fillMode: Image.PreserveAspectCrop
                color:    Kirigami.Theme.alternateBackgroundColor

                corners {
                    topLeftRadius:     card.radius
                    bottomLeftRadius:  card.radius
                    topRightRadius:    0
                    bottomRightRadius: 0
                }
            }

            // Relation type + title + format/status
            ColumnLayout {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                Layout.margins:    Kirigami.Units.smallSpacing
                spacing:           2

                Controls.Label {
                    Layout.fillWidth: true
                    text:      root.relationType.charAt(0) + root.relationType.slice(1).toLowerCase()
                    color:     Kirigami.Theme.linkColor
                }

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

        // Click handler
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                root.cardClicked(root.mediaId, root.mediaType)
            }

            HoverHandler {}
        }
    }
}