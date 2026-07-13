import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: followingPage
    title: "Following"

    ColumnLayout {
        Controls.Label {
            text: "Hello from FollowingPage.qml!"
        }
    }
}