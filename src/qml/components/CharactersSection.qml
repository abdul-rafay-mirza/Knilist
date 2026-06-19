import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var characters: []

    visible: characters.length > 0
    spacing: 0

    Kirigami.Heading {
        Layout.fillWidth:   true
        Layout.topMargin:   Kirigami.Units.largeSpacing
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        level: 3
        text:  "Characters"
    }

    Flow {
        Layout.fillWidth:   true
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin:   Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: root.characters
            delegate: CharacterCard {
                characterId: modelData.characterId
                name:        modelData.name
                image:       modelData.image
                role:        modelData.role
            }
        }
    }
}