import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var relations: []
    property real cardMinWidth: Kirigami.Units.gridUnit * 24
    signal cardClicked(int mediaId, string mediaType)

    visible: relations.length > 0
    spacing: 0

    Kirigami.Heading {
        Layout.fillWidth:   true
        Layout.topMargin:   Kirigami.Units.largeSpacing
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        level: 3
        text:  "Relations"
    }

    ColumnLayout {
        id: cardGrid
        Layout.fillWidth:   true
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin:   Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        // How many cards fit per row at cardMinWidth, given the current
        // available width — then chunk relations into rows of that size.
        readonly property var _rows: {
            const list = root.relations
            if (cardGrid.width <= 0 || !list || list.length === 0)
                return []

            const perRow = Math.max(1, Math.floor(
                (cardGrid.width + cardGrid.spacing) / (root.cardMinWidth + cardGrid.spacing)
            ))

            const rows = []
            for (let i = 0; i < list.length; i += perRow)
                rows.push(list.slice(i, i + perRow))
            return rows
        }

        Repeater {
            model: cardGrid._rows

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: cardGrid.spacing

                Repeater {
                    model: modelData

                    delegate: RelationCard {
                        Layout.fillWidth:      true
                        Layout.minimumWidth:   root.cardMinWidth
                        Layout.preferredWidth: root.cardMinWidth

                        relationType: modelData.relationType
                        mediaId:      modelData.mediaId
                        mediaType:    modelData.mediaType
                        format:       modelData.format
                        title:        modelData.title
                        coverImage:   modelData.coverImage
                        status:       modelData.status

                        onCardClicked: (mediaId, mediaType) => root.cardClicked(mediaId, mediaType)
                    }
                }
            }
        }
    }
}