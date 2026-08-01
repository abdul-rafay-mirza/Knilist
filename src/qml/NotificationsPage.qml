import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: notificationsPage
    title: "Notifications"

    // Flat list of {id, kind, title, subtitle, image, createdAt,
    // displayTime, activityId, mediaId} — see anilist_service.py's
    // _flatten_notification for the exact shape per notification kind.
    property var notifications: []

    property bool isInitialLoading: true
    property bool isLoadingMore:    false
    property bool hasNextPage:      false
    property int  currentPage:      1

    // AniList only exposes a single aggregate unread count, not a per-item
    // read flag (see graphql_queries.py's _NOTIFICATIONS_QUERY docstring).
    // The "first N are unread" highlight below is a client-side inference
    // from that count, not something the server tells us directly.
    property int unreadCount: 0

    function reload() {
        isInitialLoading = true
        hasNextPage       = false
        currentPage       = 1
        anilistService.fetchNotifications(1)
        // Refresh the count too, since this page may be opened without
        // Main.qml's own startup fetch having run recently (e.g. the app
        // has been open a while and new notifications have since arrived).
        anilistService.fetchHomeProfile()
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        isLoadingMore = true
        anilistService.fetchNotifications(currentPage + 1)
    }

    actions: [
        Kirigami.Action {
            icon.name: "mail-mark-read"
            text: "Read All"
            enabled: !anilistService.loading && notificationsPage.notifications.length > 0
            onTriggered: anilistService.markAllNotificationsRead()
        },
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: notificationsPage.reload()
        }
    ]

    Component.onCompleted: reload()

    Connections {
        target: anilistService

        function onNotificationsPageLoaded(json) {
            var payload = JSON.parse(json)
            var isFirstPage = payload.page <= 1

            if (isFirstPage)
                notificationsPage.isInitialLoading = false
            else
                notificationsPage.isLoadingMore = false

            if (payload.isError) {
                errorMessage.text = "Failed to load notifications."
                errorMessage.visible = true
                return
            }

            notificationsPage.hasNextPage = payload.hasNextPage
            notificationsPage.currentPage = payload.page

            var updated = isFirstPage
                ? payload.notifications
                : notificationsPage.notifications.concat(payload.notifications)

            // AniList's schema doesn't document a guaranteed default order
            // for the notifications field, so this sorts explicitly rather
            // than assume newest-first — the highlight below depends on it.
            updated.sort(function (a, b) { return b.createdAt - a.createdAt })
            notificationsPage.notifications = updated
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
        }

        function onHomeProfileLoaded(json) {
            var payload = JSON.parse(json)
            notificationsPage.unreadCount = payload.unreadNotificationCount || 0
        }

        function onUnreadNotificationCountChanged(count) {
            notificationsPage.unreadCount = count
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        Flickable {
            id: notificationsFlickable
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
                if (notificationsPage.isLoadingMore || notificationsPage.isInitialLoading || !notificationsPage.hasNextPage)
                    return
                if (contentY + height >= contentHeight - Kirigami.Units.gridUnit * 8)
                    notificationsPage.loadMore()
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
                    visible: !notificationsPage.isInitialLoading && notificationsPage.notifications.length === 0
                    icon.name: "notifications-disabled"
                    text: "No notifications yet"
                }

                Repeater {
                    model: notificationsPage.notifications

                    delegate: NotificationCard {
                        Layout.fillWidth: true
                        notification: modelData
                        // Position-based inference: the first unreadCount
                        // items (in newest-first order, enforced by the
                        // sort in onNotificationsPageLoaded) are treated as
                        // unread. This is a client-side guess built from
                        // the one real signal AniList gives us
                        // (unreadNotificationCount) — not a per-item flag
                        // the server actually returns.
                        unread: index < notificationsPage.unreadCount

                        // "airing" (episode released) and "relatedMedia"
                        // (new related anime/manga added) both carry a real
                        // mediaId. "activity" covers all 6 activity-style
                        // notification kinds (like/reply/reply-like/mention/
                        // message/reply-subscribed) — _flatten_notification
                        // collapses them to this one kind and carries the
                        // target in activityId instead of a per-type kind,
                        // so one branch handles all 6. "following" carries
                        // the new follower's userId/userName.
                        onCardClicked: {
                            if ((modelData.kind === "airing" || modelData.kind === "relatedMedia") && modelData.mediaId > 0) {
                                pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: modelData.mediaId })
                            } else if (modelData.kind === "activity" && modelData.activityId > 0) {
                                pageStack.layers.push(Qt.resolvedUrl("ActivityPage.qml"), { activityId: modelData.activityId })
                            } else if (modelData.kind === "following" && modelData.userId > 0) {
                                pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: modelData.userId, userName: modelData.userName })
                            }
                        }
                    }
                }

                Controls.BusyIndicator {
                    Layout.alignment:    Qt.AlignHCenter
                    Layout.topMargin:    Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    running: notificationsPage.isLoadingMore
                    visible: running
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
