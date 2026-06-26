import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var staff: []

    signal cardClicked(int staffId)

    visible: staff.length > 0
    spacing: 0

    Kirigami.Heading {
        Layout.fillWidth:   true
        Layout.topMargin:   Kirigami.Units.largeSpacing
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        level: 3
        text:  "Staff"
    }

    Flow {
        Layout.fillWidth:   true
        Layout.leftMargin:  Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin:   Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: root.staff
            delegate: StaffCard {
                staffId: modelData.id
                name:    modelData.name
                role:    modelData.role
                image:   modelData.image
                onCardClicked: (id) => root.cardClicked(id)
            }
        }
    }
}
