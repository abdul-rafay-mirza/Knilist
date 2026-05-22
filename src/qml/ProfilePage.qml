import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: animePage
    title: "Anime List"

    ColumnLayout {
        Controls.Label {
            text: "Hello from ProfilePage.qml!"
        }
    }
}