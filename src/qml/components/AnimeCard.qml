import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: animeCard

    // Public API
    property string title
    property string mediaType
    property string nextEpisodeText
    property int    rating
    property int    watchedEpisodes
    property int    totalEpisodes   // 0 = still airing / unknown

    property string coverSource

    signal addEpisode()
    signal cardClicked()   // ← new: emitted when the card body is clicked

    // Helpers
    readonly property bool  knownTotal:    totalEpisodes > 0
    readonly property real  progressRatio: knownTotal
                                           ? watchedEpisodes / totalEpisodes
                                           : 0.5

    // Geometry
    width:           440
    implicitHeight:  Math.max(110, contentItem.implicitHeight + 10)

    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    // Make the whole card clickable (except the +1 EP button, handled separately)
    MouseArea {
        anchors.fill: parent
        z: 0
        cursorShape: Qt.PointingHandCursor
        onClicked: animeCard.cardClicked()
    }

    contentItem: RowLayout {
        anchors {
            fill:         parent
            bottomMargin: 5
        }
        spacing: 0

        // Cover image
        Rectangle {
            Layout.preferredWidth: 90
            Layout.fillHeight:     true
            color: Kirigami.ColorUtils.tintWithAlpha(
                       Kirigami.Theme.backgroundColor,
                       Kirigami.Theme.textColor,
                       0.05)
            clip: true

            Image {
                anchors.fill: parent
                source:       animeCard.coverSource
                fillMode:     Image.PreserveAspectCrop
                smooth:       true
                visible:      animeCard.coverSource !== ""
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:  "image-missing"
                width:   32; height: 32
                visible: animeCard.coverSource === ""
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
                text:  animeCard.title
                color: Kirigami.Theme.textColor
                font { bold: true; pixelSize: 15 }
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Controls.Label {
                Layout.fillWidth: true
                text:      animeCard.mediaType + " • " + animeCard.nextEpisodeText
                color:     Kirigami.Theme.highlightColor
                font.pixelSize:   12
                wrapMode:  Text.WordWrap
                maximumLineCount: 2
                elide:     Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    spacing: 5
                    Kirigami.Icon {
                        source: "starred-symbolic"
                        width:  18; height: 18
                        color:  Kirigami.Theme.highlightColor
                    }
                    Controls.Label {
                        text:  animeCard.rating
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 13
                    }
                }

                Item { Layout.fillWidth: true }

                // Episode counter — "?" when total is unknown
                Controls.Label {
                    text:  animeCard.watchedEpisodes + " / "
                           + (animeCard.knownTotal ? animeCard.totalEpisodes : "?")
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }

                // +1 EP button — z raised so it captures clicks above the card MouseArea
                Rectangle {
                    z:      1
                    width:  68; height: 28
                    radius: Kirigami.Units.smallSpacing
                    color:  "transparent"
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 2

                    Controls.Label {
                        anchors.centerIn: parent
                        text:  "+1 EP"
                        color: Kirigami.Theme.highlightColor
                        font { bold: true; pixelSize: 12 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius:       parent.radius
                        color:        Kirigami.Theme.highlightColor
                        opacity:      epArea.containsMouse ? 0.15 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id:           epArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    (mouse) => {
                            mouse.accepted = true   // stop propagation to card MouseArea
                            animeCard.addEpisode()
                        }
                    }
                }
            }
        }
    }

    // Progress bar — 50% wide when total is unknown, animated otherwise
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 4
        color:  Kirigami.ColorUtils.tintWithAlpha(
                    Kirigami.Theme.backgroundColor,
                    Kirigami.Theme.positiveTextColor,
                    0.3)

        Rectangle {
            width:  parent.width * animeCard.progressRatio
            height: parent.height
            color:  Kirigami.Theme.positiveTextColor

            Behavior on width {
                enabled: animeCard.knownTotal
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }
}
