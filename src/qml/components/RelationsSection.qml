import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var relations: []

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

    Flow {
        Layout.fillWidth:   true
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin:   Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: root.relations
            delegate: RelationCard {
                relationType: modelData.relationType
                mediaId:      modelData.mediaId
                mediaType:    modelData.mediaType
                format:       modelData.format
                title:        modelData.title
                coverImage:   modelData.coverImage
                status:       modelData.status
            }
        }
    }
}