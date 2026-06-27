import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: staffPage
    title: "Staff Page"

    property var staffId

    Controls.Label {
        text: "Staff ID: " + staffId
    }
}