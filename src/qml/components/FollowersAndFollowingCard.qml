import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property int userId: 0
    property string name: ""
    property string avatar: ""
    property string bannerImage: ""
    property bool isFollowing: false
    property bool isFollower: false
    readonly property bool isMutual: isFollowing && isFollower
    // Whether this card represents the logged-in viewer. Comes straight off
    // fetchFollowing/fetchFollowers' isSelf field (_flatten_user_list), which
    // mirrors fetchUserProfile's isSelf on UsersPage.qml, a person can't
    // follow/unfollow themselves there, and can't from here either.
    property bool isSelf: false

    property var createdAt: ""
    property var updatedAt: ""

    // Which page this card is displayed on — "followers" or "following".
    property string context: "followers"

    property bool viewingOwnList: true   // false when this card is shown inside another user's followers/following

    readonly property bool showsUnfollow: root.viewingOwnList
        ? (root.context === "following" || root.isFollowing)
        : root.isFollowing   // someone else's list: only isFollowing tells us the viewer's actual relationship
    readonly property string followMenuLabel: root.showsUnfollow ? "Unfollow" : "Follow"
    readonly property string followMenuAction: root.showsUnfollow ? "unfollow" : "follow"

    signal cardTapped()
    // action: "unfollow" | "follow" | "viewOnAnilist"
    signal actionRequested(string action)

    readonly property int bannerHeight: Kirigami.Units.gridUnit * 4
    readonly property int avatarSize: Kirigami.Units.gridUnit * 3.5
    readonly property int avatarLeftMargin: Kirigami.Units.largeSpacing * 2

    padding: 0

    contentItem: ColumnLayout {
        spacing: 0

        // ── Banner + overlapping avatar ─────────────────────────────────
        Item {
            id: headerArea
            Layout.fillWidth: true
            Layout.preferredHeight: root.bannerHeight + root.avatarSize / 2

            Rectangle {
                id: bannerFallback
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: root.bannerHeight
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                    GradientStop { position: 1.0; color: Qt.darker(Kirigami.Theme.highlightColor, 1.6) }
                }
            }

            Image {
                id: bannerImg
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: root.bannerHeight
                source: root.bannerImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                visible: status === Image.Ready
            }

            AnimatedImage {
                id: avatarImg
                x: root.avatarLeftMargin
                y: root.bannerHeight - height / 2
                width: root.avatarSize
                height: root.avatarSize
                source: root.avatar || ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.smooth: true
                asynchronous: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
            }
        }

        // ── Name · Mutual badge · overflow menu ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: root.name
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                elide: Text.ElideRight
            }

            Rectangle {
                id: relationBadge
                visible: root.viewingOwnList ? root.isMutual : (root.isFollowing || root.isMutual)
                radius: height / 2
                color: Kirigami.Theme.highlightColor
                height: relationLabel.implicitHeight + Kirigami.Units.smallSpacing
                width: relationLabel.implicitWidth + Kirigami.Units.largeSpacing

                Controls.Label {
                    id: relationLabel
                    anchors.centerIn: parent
                    text: root.viewingOwnList
                        ? "Mutual"
                        : (root.isMutual ? "Mutual" : "Following")
                    color: Kirigami.Theme.highlightedTextColor
                    font.bold: true
                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
                }
            }

            Item { Layout.fillWidth: true }   // pushes the overflow button to the edge

            Controls.ToolButton {
                id: overflowButton
                icon.name: "overflow-menu"
                onClicked: overflowMenu.popup()

                Controls.Menu {
                    id: overflowMenu

                    Controls.MenuItem {
                        text: root.followMenuLabel
                        icon.name: root.showsUnfollow ? "list-remove-user" : "list-add-user"
                        // Can't follow/unfollow yourself — same guard as
                        // UsersPage's Follow button gating on profile.isSelf.
                        enabled: !root.isSelf
                        onTriggered: root.actionRequested(root.followMenuAction)
                    }

                    Controls.MenuItem {
                        text: "View on AniList"
                        icon.name: "internet-services"
                        onTriggered: root.actionRequested("viewOnAnilist")
                    }
                }
            }
        }

        // ── Following / Follower since ──────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing * 2
            Layout.topMargin: Kirigami.Units.smallSpacing / 2
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing / 2

            Controls.Label {
                visible: root.createdAt !== ""
                text: "Date Created: " + root.createdAt
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Controls.Label {
                visible: root.updatedAt !== ""
                text: "Date Updated: " + root.updatedAt
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    TapHandler {
        onTapped: root.cardTapped()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}