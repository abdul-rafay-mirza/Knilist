import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: followersPage
    title: "Followers"

    property var users: []
    property int currentPage: 1
    property bool hasNextPage: false
    property bool isFetchingMore: false

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: {
                followersPage.currentPage = 1
                anilistService.fetchFollowers(1)
            }
        }
    ]

    Component.onCompleted: anilistService.fetchFollowers(1)

    Connections {
        target: anilistService

        function onFollowersPageLoaded(json) {
            const data = JSON.parse(json)
            followersPage.isFetchingMore = false

            if (data.isError) {
                return
            }

            followersPage.users = data.page <= 1
                ? data.users
                : followersPage.users.concat(data.users)
            followersPage.currentPage = data.page
            followersPage.hasNextPage = data.hasNextPage
            errorMessage.visible = false

            if (grid.atYEnd) {
                followersPage.loadMore()
            }
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
            followersPage.isFetchingMore = false
        }
    }

    function loadMore() {
        if (!hasNextPage || isFetchingMore) return
        isFetchingMore = true
        anilistService.fetchFollowers(currentPage + 1)
    }

    Item {
        anchors.fill: parent

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            model: followersPage.users

            flickableDirection: Flickable.VerticalFlick
            interactive: true
            boundsBehavior: Flickable.DragAndOvershootBounds

            // Same placeholder sizing as FollowingPage — see note there.
            readonly property int cardWidth:  300
            readonly property int cardHeight: 150
            readonly property int minCellWidth: cardWidth + Kirigami.Units.largeSpacing * 2
            readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
            cellWidth:  width / columns
            cellHeight: cardHeight + Kirigami.Units.largeSpacing * 2

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            header: Kirigami.InlineMessage {
                id: errorMessage
                width: grid.width
                type: Kirigami.MessageType.Error
                showCloseButton: true
                visible: false
            }

            delegate: Item {
                width:  grid.cellWidth
                height: grid.cellHeight

                FollowersAndFollowingCard {
                    anchors.centerIn: parent
                    width: grid.cardWidth
                    height: grid.cardHeight
                    userId:      modelData.id
                    name:        modelData.name
                    avatar:      modelData.avatar
                    bannerImage: modelData.bannerImage
                    isFollowing: modelData.isFollowing
                    isFollower:  modelData.isFollower

                    onCardTapped: {}
                    onMoreRequested: {}
                }
            }

            footer: Item {
                width: grid.width
                height: followersPage.isFetchingMore ? Kirigami.Units.gridUnit * 3 : 0

                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    running: followersPage.isFetchingMore
                    visible: followersPage.isFetchingMore
                }
            }

            onAtYEndChanged: if (atYEnd) followersPage.loadMore()

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                visible: grid.count === 0 && !anilistService.loading && !errorMessage.visible
                text: "No followers yet"
                icon.name: "user-identity"
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: anilistService.loading
            color: Kirigami.Theme.backgroundColor
            opacity: 0.6
            z: 2

            MouseArea {
                anchors.fill: parent
                enabled: anilistService.loading
                hoverEnabled: true
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: true
            }
        }
    }
}