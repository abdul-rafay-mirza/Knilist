import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: animeCard

    // Public API
    property string title:           "Classroom of the Elite 4th Season: Second Cours"
    property string mediaType:       "TV"
    property string nextEpisodeText: "Ep. 12 in 5 days."
    property int    rating:          0
    property int    watchedEpisodes: 11
    property int    totalEpisodes:   16
    property string coverSource:     ""

    signal addEpisode()

    // Geometry
    width:  440
    height: 110

    // Kirigami.AbstractCard has its own padding — zero it out
    // so our layout fills the card edge-to-edge
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

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
            // Slightly darker shade of the card background
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

            // Placeholder when no cover
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

            // Title
            Controls.Label {
                Layout.fillWidth: true
                text:  animeCard.title
                color: Kirigami.Theme.textColor
                font { bold: true; pixelSize: 15 }
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Media type • next-episode info
            Controls.Label {
                text:  animeCard.mediaType + " • " + animeCard.nextEpisodeText
                color: Kirigami.Theme.highlightColor
                font.pixelSize: 12
            }

            Item { Layout.fillHeight: true }

            // Bottom row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // ★ Rating
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

                // Episode counter
                Controls.Label {
                    text:  animeCard.watchedEpisodes + " / " + animeCard.totalEpisodes
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }

                // +1 EP button
                Rectangle {
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
                        onClicked:    animeCard.addEpisode()
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
            width:  parent.width * (animeCard.watchedEpisodes / Math.max(animeCard.totalEpisodes, 1))
            height: parent.height
            color:  Kirigami.Theme.positiveTextColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }
}