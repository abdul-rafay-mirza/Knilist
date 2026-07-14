import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: followingPage
    title: "Following"

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
                followingPage.currentPage = 1
                anilistService.fetchFollowing(1)
            }
        }
    ]

    Component.onCompleted: anilistService.fetchFollowing(1)

    Connections {
        target: anilistService

        function onFollowingPageLoaded(json) {
            const data = JSON.parse(json)
            followingPage.isFetchingMore = false

            if (data.isError) {
                return
            }

            followingPage.users = data.page <= 1
                ? data.users
                : followingPage.users.concat(data.users)
            followingPage.currentPage = data.page
            followingPage.hasNextPage = data.hasNextPage
            errorMessage.visible = false

            // Freshly loaded content might still not fill the viewport —
            // atYEndChanged won't refire in that case, so check directly.
            if (grid.atYEnd) {
                followingPage.loadMore()
            }
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
            followingPage.isFetchingMore = false
        }
    }

    function loadMore() {
        if (!hasNextPage || isFetchingMore) return
        isFetchingMore = true
        anilistService.fetchFollowing(currentPage + 1)
    }

    Item {
        anchors.fill: parent

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            model: followingPage.users

            flickableDirection: Flickable.VerticalFlick
            interactive: true
            boundsBehavior: Flickable.DragAndOvershootBounds

            // FollowersAndFollowingCard's own footprint, plus breathing room
            // on each side (GridView has no `spacing` property, unlike
            // ListView — same cell-padding technique AllStaffPage uses for
            // StaffCard). Placeholder values — swap for the card's real size.
            readonly property int cardWidth:  300
            readonly property int cardHeight: 190
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
                    createdAt:   modelData.createdAt
                    updatedAt:   modelData.updatedAt

                    // No UserPage yet, so these are no-ops for now
                    onCardTapped: {}
                    onMoreRequested: {}
                }
            }

            footer: Item {
                width: grid.width
                height: followingPage.isFetchingMore ? Kirigami.Units.gridUnit * 3 : 0

                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    running: followingPage.isFetchingMore
                    visible: followingPage.isFetchingMore
                }
            }

            onAtYEndChanged: if (atYEnd) followingPage.loadMore()

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                visible: grid.count === 0 && !anilistService.loading && !errorMessage.visible
                text: "Not following anyone yet"
                icon.name: "im-user"
            }
        }

        // Loading overlay (first load / refresh only — anilistService.loading
        // stays false during "load more", since fetchFollowing only toggles
        // it for page 1)
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