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
    property real   rating          // raw 0-100 from AniList
    property int    watchedEpisodes
    property int    totalEpisodes   // 0 = still airing / unknown
    property string coverSource

    signal addEpisode()
    signal cardClicked()

    // Helpers
    readonly property bool  knownTotal:    totalEpisodes > 0
    readonly property real  progressRatio: knownTotal
                                           ? watchedEpisodes / totalEpisodes
                                           : 0.5

    // Formatted score string — delegates to the service so the format is
    // always consistent with whatever AniList says the user's format is
    readonly property string formattedScore: anilistService.formatScore(rating)

    // Geometry
    width:           440
    implicitHeight:  Math.max(110, contentItem.implicitHeight + 10)
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

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

                // Score — always visible; shows "—" when unrated
                RowLayout {
                    spacing: 4

                    Kirigami.Icon {
                        source: "starred-symbolic"
                        width:  16; height: 16
                        color:  animeCard.rating > 0
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.disabledTextColor
                    }
                    Controls.Label {
                        text:  animeCard.rating > 0
                               ? animeCard.formattedScore
                               : "—"
                        color: animeCard.rating > 0
                               ? Kirigami.Theme.textColor
                               : Kirigami.Theme.disabledTextColor
                        font.pixelSize: 13
                    }
                }

                Item { Layout.fillWidth: true }

                Controls.Label {
                    text:  animeCard.watchedEpisodes + " / "
                           + (animeCard.knownTotal ? animeCard.totalEpisodes : "?")
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }

                // +1 EP button
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
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            animeCard.addEpisode()
                        }
                    }
                }
            }
        }
    }

    // Progress bar
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
