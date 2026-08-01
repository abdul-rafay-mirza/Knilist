import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: activityPage
    title: "Activity"

    // Set by whoever pushes this page (NotificationsPage.qml, or in future
    // any other place an activityId shows up — profile feeds, media pages).
    required property int activityId

    // NOTE: user-avatar/name taps below navigate to UsersPage.qml with
    // { userId, userName } — that shape isn't verified against the actual
    // file (not available to check here), only against notes from an
    // earlier session that built UsersPage's navigation wiring with those
    // exact reserved property names. Worth a quick check against the real
    // file if the navigation doesn't work as expected. AnimePage.qml's
    // { animeId } shape below, by contrast, is copied directly from
    // NotificationsPage.qml's own onCardClicked handler, and MangaPage.qml's
    // { anilistId } shape (see openMedia() below) is confirmed directly
    // against MangaPage.qml's own `property int anilistId`.

    // { kind, activityId, user, text, mediaId, mediaTitle, mediaCover,
    //   mediaType, recipient, createdAt, displayTime, replyCount,
    //   likeCount, isLocked, siteUrl } — see anilist_service.py's
    // fetchActivity for the exact shape per activity kind ("list" / "text"
    // / "message").
    property var activity: null

    // Flat list of { id, activityId, text, createdAt, displayTime,
    // likeCount, user } — see _flatten_activity_replies.
    property var replies: []

    property bool isInitialLoading: true
    property bool isLoadingMoreReplies: false
    property bool hasNextRepliesPage: false
    property int  currentRepliesPage: 1

    function reload() {
        isInitialLoading   = true
        hasNextRepliesPage = false
        currentRepliesPage = 1
        anilistService.fetchActivity(activityPage.activityId)
    }

    function loadMoreReplies() {
        if (isLoadingMoreReplies || isInitialLoading || !hasNextRepliesPage)
            return
        isLoadingMoreReplies = true
        anilistService.fetchActivityReplies(activityPage.activityId, currentRepliesPage + 1)
    }

    // Shared by the cover-image click and the title-text click below, so
    // the ANIME/MANGA branch lives in one place. Same branching NotificationsPage.qml
    // uses for its airing/relatedMedia notifications.
    function openMedia() {
        if (!activityPage.activity || activityPage.activity.mediaId <= 0)
            return
        if (activityPage.activity.mediaType === "MANGA") {
            pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: activityPage.activity.mediaId })
        } else {
            pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: activityPage.activity.mediaId })
        }
    }

    // Local avatar-circle component, defined once and reused by the header
    // and each reply row — deliberately built from plain Rectangle+Image
    // rather than a Kirigami Avatar component, since this project's other
    // pages (per NotificationsPage.qml, the only other page available to
    // check against) don't demonstrate any kirigami-addons dependency, and
    // introducing one here isn't safe to assume will resolve.
    component RoundAvatar: Rectangle {
        id: avatarRoot
        property alias source: avatarImage.source
        radius: width / 2
        clip:   true
        color:  Kirigami.Theme.disabledTextColor   // shows while the image loads / if it's missing

        Image {
            id: avatarImage
            anchors.fill: parent
            fillMode:     Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: activityPage.reload()
        }
    ]

    Component.onCompleted: reload()

    Connections {
        target: anilistService

        function onActivityPageLoaded(json) {
            var payload = JSON.parse(json)
            activityPage.isInitialLoading = false

            if (payload.isError) {
                errorMessage.text = "Failed to load activity."
                errorMessage.visible = true
                return
            }

            activityPage.activity           = payload.activity
            activityPage.replies            = payload.replies
            activityPage.currentRepliesPage = payload.repliesPage
            activityPage.hasNextRepliesPage = payload.hasNextPage

            // The page title starts generic ("Activity") since we don't
            // know the kind until the fetch returns; once it does, reflect
            // it in the title bar.
            if (payload.activity) {
                if (payload.activity.kind === "message")
                    activityPage.title = "Message"
                else
                    activityPage.title = payload.activity.user.name + "'s Activity"
            }
        }

        function onActivityRepliesLoaded(json) {
            var payload = JSON.parse(json)
            activityPage.isLoadingMoreReplies = false

            if (payload.isError) {
                errorMessage.text = "Failed to load more replies."
                errorMessage.visible = true
                return
            }

            activityPage.replies            = activityPage.replies.concat(payload.replies)
            activityPage.currentRepliesPage = payload.repliesPage
            activityPage.hasNextRepliesPage = payload.hasNextPage
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        Flickable {
            id: activityFlickable
            anchors.fill:  parent
            contentWidth:  parent.width
            contentHeight: mainColumn.implicitHeight
            clip:          true

            flickableDirection: Flickable.VerticalFlick
            interactive:        true
            boundsBehavior:     Flickable.DragAndOvershootBounds

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            onContentYChanged: {
                if (activityPage.isLoadingMoreReplies || activityPage.isInitialLoading || !activityPage.hasNextRepliesPage)
                    return
                if (contentY + height >= contentHeight - Kirigami.Units.gridUnit * 8)
                    activityPage.loadMoreReplies()
            }

            ColumnLayout {
                id:      mainColumn
                width:   parent.width
                spacing: 0

                Kirigami.InlineMessage {
                    id: errorMessage
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    type: Kirigami.MessageType.Error
                    showCloseButton: true
                    visible: false
                }

                Kirigami.PlaceholderMessage {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.gridUnit * 4
                    visible: !activityPage.isInitialLoading && !activityPage.activity
                    icon.name: "notifications-disabled"
                    text: "This activity is no longer available"
                }

                // Activity header card ───────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins:   Kirigami.Units.smallSpacing
                    visible:          activityPage.activity !== null
                    radius:           Kirigami.Units.smallSpacing
                    color:            Kirigami.Theme.backgroundColor
                    Kirigami.Theme.colorSet: Kirigami.Theme.View
                    implicitHeight:   headerLayout.implicitHeight + Kirigami.Units.largeSpacing * 2

                    ColumnLayout {
                        id: headerLayout
                        anchors {
                            left:    parent.left
                            right:   parent.right
                            top:     parent.top
                            margins: Kirigami.Units.largeSpacing
                        }
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            // Media cover, only shown for list-activity updates
                            Rectangle {
                                visible: activityPage.activity && activityPage.activity.kind === "list" && activityPage.activity.mediaCover !== ""
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 3.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                                Layout.alignment: Qt.AlignTop
                                radius: Kirigami.Units.smallSpacing
                                clip:   true
                                color:  "transparent"

                                Image {
                                    anchors.fill: parent
                                    source:       activityPage.activity ? activityPage.activity.mediaCover : ""
                                    fillMode:     Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: activityPage.openMedia()
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing / 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    RoundAvatar {
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.6
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                                        source: activityPage.activity ? activityPage.activity.user.avatar : ""

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:  Qt.PointingHandCursor
                                            onClicked: {
                                                if (activityPage.activity && activityPage.activity.user.id > 0)
                                                    pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: activityPage.activity.user.id, userName: activityPage.activity.user.name })
                                            }
                                        }
                                    }

                                    Controls.Label {
                                        text: activityPage.activity ? activityPage.activity.user.name : ""
                                        font.bold: true
                                        color: Kirigami.Theme.linkColor

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:  Qt.PointingHandCursor
                                            onClicked: {
                                                if (activityPage.activity && activityPage.activity.user.id > 0)
                                                    pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: activityPage.activity.user.id, userName: activityPage.activity.user.name })
                                            }
                                        }
                                    }

                                    // Message activities are addressed to a
                                    // second person — show that inline
                                    // ("Alice → Bob") the way AniList's own
                                    // message rows do.
                                    Controls.Label {
                                        visible: activityPage.activity && activityPage.activity.kind === "message" && activityPage.activity.recipient !== null
                                        text: "→ " + (activityPage.activity && activityPage.activity.recipient ? activityPage.activity.recipient.name : "")
                                        color: Kirigami.Theme.linkColor
                                    }

                                    Item { Layout.fillWidth: true }

                                    Controls.Label {
                                        text: activityPage.activity ? activityPage.activity.displayTime : ""
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    }
                                }

                                // "Rewatched Show Name" / free-text post,
                                // with the media title (if any) appended
                                Controls.Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    text: {
                                        if (!activityPage.activity)
                                            return ""
                                        if (activityPage.activity.kind === "list" && activityPage.activity.mediaTitle !== "")
                                            return activityPage.activity.text + " " + activityPage.activity.mediaTitle
                                        return activityPage.activity.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled:      activityPage.activity && activityPage.activity.kind === "list" && activityPage.activity.mediaId > 0
                                        cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: activityPage.openMedia()
                                    }
                                }
                            }
                        }

                        // Like / reply counts
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.largeSpacing

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                visible: activityPage.activity && activityPage.activity.replyCount > 0
                                spacing: Kirigami.Units.smallSpacing / 2
                                Kirigami.Icon { source: "im-message-new"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                                Controls.Label { text: activityPage.activity ? activityPage.activity.replyCount : 0 }
                            }

                            RowLayout {
                                visible: activityPage.activity && activityPage.activity.likeCount > 0
                                spacing: Kirigami.Units.smallSpacing / 2
                                Kirigami.Icon { source: "emblem-favorite"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                                Controls.Label { text: activityPage.activity ? activityPage.activity.likeCount : 0 }
                            }
                        }
                    }
                }

                // Replies ──────────────────────────────────────────────
                Repeater {
                    model: activityPage.replies

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin:  Kirigami.Units.smallSpacing * 2
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        Layout.topMargin:   Kirigami.Units.smallSpacing / 2
                        radius: Kirigami.Units.smallSpacing
                        color:  Kirigami.Theme.backgroundColor
                        Kirigami.Theme.colorSet: Kirigami.Theme.View
                        implicitHeight: replyLayout.implicitHeight + Kirigami.Units.largeSpacing * 1.5

                        ColumnLayout {
                            id: replyLayout
                            anchors {
                                left:    parent.left
                                right:   parent.right
                                top:     parent.top
                                margins: Kirigami.Units.largeSpacing * 0.75
                            }
                            spacing: Kirigami.Units.smallSpacing / 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                RoundAvatar {
                                    Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                    source: modelData.user.avatar

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.user.id > 0)
                                                pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: modelData.user.id, userName: modelData.user.name })
                                        }
                                    }
                                }

                                Controls.Label {
                                    text: modelData.user.name
                                    font.bold: true
                                    color: Kirigami.Theme.linkColor

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.user.id > 0)
                                                pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: modelData.user.id, userName: modelData.user.name })
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    visible: modelData.likeCount > 0
                                    spacing: Kirigami.Units.smallSpacing / 2
                                    Kirigami.Icon { source: "emblem-favorite"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                                    Controls.Label { text: modelData.likeCount; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                                }

                                Controls.Label {
                                    text: modelData.displayTime
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.gridUnit * 1.4 + Kirigami.Units.smallSpacing
                                wrapMode: Text.Wrap
                                text: modelData.text
                            }
                        }
                    }
                }

                Controls.BusyIndicator {
                    Layout.alignment:    Qt.AlignHCenter
                    Layout.topMargin:    Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    running: activityPage.isLoadingMoreReplies
                    visible: running
                }

                // Reply input ──────────────────────────────────────────
                // TODO: read-only for now — posting a reply (SaveActivityReply
                // mutation) and liking (ToggleLike mutation) are not wired up
                // yet. This box mirrors the screenshot's placement but is
                // disabled until those mutations are implemented.
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: activityPage.activity !== null
                }

                Controls.TextField {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    visible: activityPage.activity !== null
                    placeholderText: "Write a reply…"
                    enabled: false
                }

                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
            }
        }

        // Dimming overlay during loading
        Rectangle {
            anchors.fill: parent
            visible:      anilistService.loading
            color:        Kirigami.Theme.backgroundColor
            opacity:      0.6
            z:            2

            MouseArea {
                anchors.fill: parent
                enabled:      anilistService.loading
                hoverEnabled: true
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running:          true
            }
        }
    }
}
