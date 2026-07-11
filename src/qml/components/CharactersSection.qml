import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var characters: []
    property bool headingVisible: true

    signal characterClicked(int characterId, string name, string image, string role)
    signal characterHeadingClicked()

    visible: characters.length > 0
    spacing: 0

    Kirigami.Heading {
        // Layout.fillWidth:   true
        Layout.topMargin:   Kirigami.Units.largeSpacing
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        level: 3
        text:  "Characters"
        visible: headingVisible

        opacity: producerHover.hovered ? 1.0 : 0.85
        color: producerHover.hovered ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor

        TapHandler {
            onTapped: {
                root.characterHeadingClicked()
            }
        }

        HoverHandler {
            id: producerHover
            cursorShape: Qt.PointingHandCursor
        }
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
                onCharacterClicked: (id, name) => {
                    root.characterClicked(characterId, name, image, role)
                }
            }
        }
    }
}