import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: homePage
    title: "Home"

    ColumnLayout {
        Controls.Label {
            text: "Hello from HomePage.qml!"
        }
    }
}