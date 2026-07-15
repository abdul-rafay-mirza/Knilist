import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: followersPage
    title: "Followers"

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
        followersModel.clear()
        anilistService.fetchFollowers(1)
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage) return
        isLoadingMore = true
        anilistService.fetchFollowers(currentPage + 1)
    }

    // In case the first page(s) don't fill the viewport, keep requesting
    // more until either the view is full or the server has nothing left.
    // Mirrors AllStaffPage.checkFillViewport().
    function checkFillViewport() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        if (grid.contentHeight <= grid.height)
            loadMore()
    }

    ListModel {
        id: followersModel
    }

    Connections {
        target: anilistService

        function onFollowersPageLoaded(json) {
            const data = JSON.parse(json)

            const isFirstPage = data.page <= 1
            if (isFirstPage)
                followersPage.isInitialLoading = false
            else
                followersPage.isLoadingMore = false

            if (data.isError) {
                return
            }

            // Append-only. Reassigning the whole backing array (the old
            // approach) hands GridView a brand-new model object, so it
            // rebuilds every delegate and resets contentY to 0. Appending
            // to a ListModel is an incremental insert the view can apply
            // without disturbing the items already on screen.
            for (let i = 0; i < data.users.length; i++) {
                const u = data.users[i]
                if (seenUserIds[u.id]) continue
                seenUserIds[u.id] = true
                followersModel.append({
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

            followersPage.currentPage = data.page
            followersPage.hasNextPage = data.hasNextPage
            errorMessage.visible = false

            Qt.callLater(checkFillViewport)
        }

        function onFollowToggled(userId, isFollowing, isFollower) {
            reload()
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
            followersPage.isInitialLoading = false
            followersPage.isLoadingMore = false
        }
    }

    Item {
        anchors.fill: parent

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            model: followersModel

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
                    context: "followers"

                    onCardTapped: {
                        console.log("FollowersAndFollowingCard Tapped from FollowersPage!")
                        pageStack.layers.push(
                            Qt.resolvedUrl("UsersPage.qml"),{
                                userId: userId,
                                userName: name
                            }
                        )
                    }

                    onActionRequested: (action) => {
                        switch (action) {
                            case "follow":
                            case "unfollow":
                                console.log(action, "requested for", name, "(userId:", userId + ")")
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
                height: followersPage.isLoadingMore ? Kirigami.Units.gridUnit * 3 : 0

                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    running: followersPage.isLoadingMore
                    visible: followersPage.isLoadingMore
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
                visible: grid.count === 0 && !followersPage.isInitialLoading && !errorMessage.visible
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