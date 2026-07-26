import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// One row in NotificationsPage's list. Expects a flat notification object
// shaped like anilist_service.py's _flatten_notification output:
//   { id, kind, title, subtitle, image, createdAt, displayTime, activityId, mediaId }
//
// Structured like AnimeCard (AbstractCard, same 90px-wide/full-height cover
// image column) rather than a SwipeListItem.
Kirigami.AbstractCard {
    id: card

    property var notification: null
    visible: notification !== null

    signal cardClicked()
    signal imageClicked()

    // Geometry — matches AnimeCard's card sizing exactly.
    width:           440
    implicitHeight:  Math.max(150, contentItem.implicitHeight + 10)
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    TapHandler {
        enabled: card.notification !== null
        onTapped: card.cardClicked()
    }

    HoverHandler {
        enabled: card.notification !== null
        cursorShape: Qt.PointingHandCursor
    }

    contentItem: RowLayout {
        anchors {
            fill:         parent
            bottomMargin: 5
        }
        spacing: 0

        // Cover image — same 90px-wide, full-card-height column as AnimeCard.
        Rectangle {
            Layout.preferredWidth: 90
            Layout.fillHeight:     true
            color: Kirigami.ColorUtils.tintWithAlpha(
                       Kirigami.Theme.backgroundColor,
                       Kirigami.Theme.textColor,
                       0.05)
            clip: true

            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                onTapped: card.imageClicked()
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Image {
                id: notifImage
                anchors.fill: parent
                source:       card.notification ? (card.notification.image || "") : ""
                fillMode:     Image.PreserveAspectCrop
                asynchronous: true
                smooth:       true
                visible:      status === Image.Ready && card.notification && card.notification.image !== ""
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:  card.notification && card.notification.kind === "following"
                             ? "user-identity"
                             : "image-missing"
                width:   32; height: 32
                visible: notifImage.status !== Image.Ready || !card.notification || card.notification.image === ""
                color:   Kirigami.Theme.disabledTextColor
            }
        }

        // Text + controls
        ColumnLayout {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            Layout.leftMargin:  14
            Layout.rightMargin: 12
            Layout.topMargin:   10
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text:  card.notification ? card.notification.title : ""
                color: Kirigami.Theme.textColor
                font { bold: true; pixelSize: 15 }
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Controls.Label {
                Layout.fillWidth: true
                text:      card.notification ? card.notification.subtitle : ""
                color:     Kirigami.Theme.highlightColor
                font.pixelSize:   12
                wrapMode:  Text.WordWrap
                maximumLineCount: 2
                elide:     Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            Controls.Label {
                Layout.fillWidth: true
                text:  card.notification ? card.notification.displayTime : ""
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 13
            }
        }
    }
}
