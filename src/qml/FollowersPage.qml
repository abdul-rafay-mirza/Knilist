import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: followersPage
    title: "Followers"

    ColumnLayout {
        Controls.Label {
            text: "Hello from FollowersPage.qml!"
        }
    }
}