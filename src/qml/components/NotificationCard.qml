import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// One row in NotificationsPage's list. Expects a flat notification object
// shaped like anilist_service.py's _flatten_notification output:
//   { id, kind, title, subtitle, image, createdAt, displayTime, activityId, mediaId }
Kirigami.SwipeListItem {
    id: card

    property var notification: null
    visible: notification !== null

    readonly property int imageSize: Kirigami.Units.iconSizes.enormous

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing * 1.5

        Item {
            Layout.preferredWidth: card.imageSize
            Layout.preferredHeight: card.imageSize

            Rectangle {
                id: imageFallback
                anchors.fill: parent
                radius: card.notification.kind === "airing" ? Kirigami.Units.smallSpacing : width / 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: Qt.rgba(
                    Kirigami.Theme.textColor.r,
                    Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b,
                    0.2
                )
                visible: notifImage.status !== Image.Ready

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.55
                    height: width
                    source: card.notification.kind === "airing" ? "video-television-symbolic"
                        : card.notification.kind === "following" ? "user-identity"
                        : "notifications"
                }
            }

            Image {
                id: notifImage
                anchors.fill: parent
                source: card.notification.image || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                visible: status === Image.Ready

                // Anime/manga cover art reads as a small poster (square-ish
                // rounded rect); user avatars read as a circle — matches
                // imageFallback's radius logic above so the loaded and
                // not-yet-loaded states don't visibly swap shape.
                layer.enabled: card.notification.kind !== "airing"
                layer.smooth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                Layout.fillWidth: true
                text: card.notification.title
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                font.bold: true
                elide: Text.ElideRight
            }

            Controls.Label {
                Layout.fillWidth: true
                text: card.notification.subtitle
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            Controls.Label {
                Layout.fillWidth: true
                text: card.notification.displayTime
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
            }
        }
    }
}
