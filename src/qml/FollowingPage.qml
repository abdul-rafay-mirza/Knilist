import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: followingPage
    title: "Following"

    property bool isInitialLoading: true
    property bool isLoadingMore:    false
    property bool hasNextPage:      true
    property int  currentPage:      1
    property var  seenUserIds:      ({})   // dedupe guard

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: reload()
        }
    ]

    Component.onCompleted: reload()

    function reload() {
        isInitialLoading = true
        isLoadingMore     = false
        hasNextPage       = true
        currentPage       = 1
        seenUserIds       = ({})
        followingModel.clear()
        anilistService.fetchFollowing(1)
    }
    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage) return
        isLoadingMore = true
        anilistService.fetchFollowing(currentPage + 1)
    }

    function checkFillViewport() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        if (grid.contentHeight <= grid.height)
            loadMore()
    }

    ListModel {
        id: followingModel
    }

    Connections {
        target: anilistService

        function onFollowingPageLoaded(json) {
            const data = JSON.parse(json)

            const isFirstPage = data.page <= 1
            if (isFirstPage)
                followingPage.isInitialLoading = false
            else
                followingPage.isLoadingMore = false

            if (data.isError) {
                return
            }

            for (let i = 0; i < data.users.length; i++) {
                const u = data.users[i]
                if (seenUserIds[u.id]) continue
                seenUserIds[u.id] = true
                followingModel.append({
                    userId:      u.id,
                    name:        u.name,
                    avatar:      u.avatar,
                    bannerImage: u.bannerImage,
                    isFollowing: u.isFollowing,
                    isFollower:  u.isFollower,
                    createdAt:   u.createdAt,
                    updatedAt:   u.updatedAt
                })
            }

            followingPage.currentPage = data.page
            followingPage.hasNextPage = data.hasNextPage
            errorMessage.visible = false

            Qt.callLater(checkFillViewport)
        }

        function onFollowToggled(userId, isFollowing, isFollower) {
            reload()
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
            followingPage.isInitialLoading = false
            followingPage.isLoadingMore = false
        }
    }

    Item {
        anchors.fill: parent

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            model: followingModel

            flickableDirection: Flickable.VerticalFlick
            interactive: true
            boundsBehavior: Flickable.DragAndOvershootBounds

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
                    userId:      model.userId
                    name:        model.name
                    avatar:      model.avatar
                    bannerImage: model.bannerImage
                    isFollowing: model.isFollowing
                    isFollower:  model.isFollower
                    createdAt:   model.createdAt
                    updatedAt:   model.updatedAt
                    context: "following"

                    onCardTapped: {
                        console.log("FollowersAndFollowingCard Tapped from FollowingPage!")
                        pageStack.layers.push(
                            Qt.resolvedUrl("UsersPage.qml"),{
                                userId: userId,
                                userName: name
                            }
                        )
                    }

                    onActionRequested: (action) => {
                        switch (action) {
                            case "unfollow":
                                console.log("Unfollow requested for", name, "(userId:", userId + ")")
                                anilistService.toggleFollow(userId)
                                break
                            case "viewOnAnilist":
                                Qt.openUrlExternally("https://anilist.co/user/" + userId)
                                break
                        }
                    }
                }
            }

            footer: Item {
                width: grid.width
                height: followingPage.isLoadingMore ? Kirigami.Units.gridUnit * 3 : 0

                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    running: followingPage.isLoadingMore
                    visible: followingPage.isLoadingMore
                }
            }

            onContentYChanged: {
                if (isLoadingMore || isInitialLoading || !hasNextPage)
                    return
                if (contentY + height >= contentHeight - Kirigami.Units.gridUnit * 8)
                    loadMore()
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                visible: grid.count === 0 && !followingPage.isInitialLoading && !errorMessage.visible
                text: "Not following anyone yet"
                icon.name: "im-user"
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