import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: card

    property var notification: null
    visible: notification !== null

    // Client-side inference only — see NotificationsPage.qml's Repeater for
    // how this is computed (position vs. unreadNotificationCount). AniList
    // itself has no per-notification read flag.
    property bool unread: false

    signal cardClicked()
    signal imageClicked()
    signal titleClicked()

    // Geometry — matches AnimeCard's card sizing exactly.
    width:           440
    implicitHeight:  Math.max(150, contentItem.implicitHeight + 10)
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    background: Rectangle {
        color: card.unread
                   ? Kirigami.ColorUtils.tintWithAlpha(
                         Kirigami.Theme.backgroundColor,
                         Kirigami.Theme.highlightColor,
                         0.12)
                   : Kirigami.Theme.backgroundColor
    }

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
                onTapped: {
                    console.log("Image Clicked!")
                    card.imageClicked()
                }
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

            Item {
                Layout.fillWidth: true
                implicitHeight: titleLabel.implicitHeight

                TapHandler {
                    gesturePolicy: TapHandler.WithinBounds
                    onTapped: {
                        console.log("Title Clicked!")
                        card.titleClicked()
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Controls.Label {
                    id: titleLabel
                    anchors.fill: parent

                    text: card.notification ? card.notification.title : ""
                    color: Kirigami.Theme.textColor
                    font {
                        bold: true
                        pixelSize: 15
                    }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    verticalAlignment: Text.AlignVCenter
                }
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
