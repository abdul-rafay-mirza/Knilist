import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var recommendations: []

    signal cardClicked(int mediaId, string mediaType)

    visible:             recommendations && recommendations.length > 0
    spacing:             Kirigami.Units.smallSpacing
    Layout.fillWidth:    true
    Layout.leftMargin:   Kirigami.Units.largeSpacing
    Layout.rightMargin:  Kirigami.Units.largeSpacing
    Layout.bottomMargin: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        level: 3
        text:  "Recommendations"
    }

    Kirigami.Separator { Layout.fillWidth: true }

    Flickable {
        Layout.fillWidth:   true
        implicitHeight:     cardRow.implicitHeight
        contentWidth:       cardRow.implicitWidth
        contentHeight:      cardRow.implicitHeight
        flickableDirection: Flickable.HorizontalFlick
        clip:               true

        Row {
            id:      cardRow
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.recommendations

                MediaCoverCard {
                    mediaId:  modelData.mediaId
                    title:    modelData.title || ""
                    imageURL: modelData.coverImage || ""
                    onTapped: root.cardClicked(modelData.mediaId, modelData.type || "")
                }
            }
        }

        Controls.ScrollBar.horizontal: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
        }
    }
}
