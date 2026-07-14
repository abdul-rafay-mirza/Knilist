import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// The page representing any user
// Accessed form ProfilePage > Click on Followers and Following StatBar > Click on a FollowersAndFollowingCard

Kirigami.Page {
    id: usersPage
    title: userName

    property var userId: 0
    property var userName: "User Page"

    Controls.Label {
        text: "User ID: " + usersPage.userId
    }

}