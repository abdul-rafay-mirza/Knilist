import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: animeSearchCard

    // Public API
    property string title
    property string mediaType     // "TV", "ONA", "MOVIE", etc. — already display-formatted by the caller (see SearchPage.qml's formatLabel)
    property int    year          // 0 = unknown
    property real   averageScore  // 0-100 raw AniList score, 0 = unrated/no votes yet
    property int    favourites
    property string coverSource
    property int    anilistId

    // MediaListStatus enum string: "CURRENT", "COMPLETED", "DROPPED",
    // "PAUSED", "PLANNING", "REPEATING" — or "" when this media isn't
    // on the viewer's list. Anything falsy hides the whole relation row.
    property string userStatus: ""

    signal cardClicked()
    signal imageClicked()

    // Helpers
    readonly property bool   hasScore:  averageScore > 0
    readonly property bool   hasStatus: userStatus.length > 0

    readonly property string formattedScore: hasScore
                                               ? (averageScore / 10).toFixed(1)
                                               : "—"

    readonly property string formattedFavourites: _formatCount(favourites)

    function _formatCount(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(n % 1000000 === 0 ? 0 : 1) + "M"
        if (n >= 1000)    return (n / 1000).toFixed(n % 1000 === 0 ? 0 : 1) + "k"
        return String(n)
    }

    // MediaListStatus -> { label, color }. Not an AniList concept —
    // AniList only gives us the raw enum, so the human label and the
    // semantic color are both invented here. Kept local to this
    // component rather than pushed into anilist_service.py since it's
    // pure presentation, same reasoning as AnimeCard's formattedScore
    // delegating to the service only for things the service actually
    // owns (score format).
    readonly property var _statusMeta: ({
        "CURRENT":   { label: "Watching",  color: Kirigami.Theme.highlightColor },
        "COMPLETED": { label: "Completed", color: Kirigami.Theme.positiveTextColor },
        "PAUSED":    { label: "Paused",    color: Kirigami.Theme.neutralTextColor },
        "DROPPED":   { label: "Dropped",   color: Kirigami.Theme.negativeTextColor },
        "PLANNING":  { label: "Planning",  color: Kirigami.Theme.disabledTextColor },
        "REPEATING": { label: "Rewatching", color: Kirigami.Theme.highlightColor },
    })
    readonly property var statusMeta: _statusMeta[userStatus] || { label: userStatus, color: Kirigami.Theme.disabledTextColor }

    width:           440
    implicitHeight:  Math.max(150, mainLayout.implicitHeight + 10)
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    TapHandler {
        onTapped: animeSearchCard.cardClicked()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    contentItem: RowLayout {
        id: mainLayout
        anchors {
            fill: parent
            bottomMargin: 5
        }
        spacing: 0

        // Cover image
        Rectangle {
            Layout.preferredWidth:  90
            Layout.fillHeight: true
            color: Kirigami.ColorUtils.tintWithAlpha(
                        Kirigami.Theme.backgroundColor,
                        Kirigami.Theme.textColor,
                        0.05)
            clip: true

            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                onTapped: animeSearchCard.imageClicked()
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Image {
                anchors.fill: parent
                source:       animeSearchCard.coverSource
                fillMode:     Image.PreserveAspectCrop
                smooth:       true
                visible:      animeSearchCard.coverSource !== ""
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:  "image-missing"
                width:   32; height: 32
                visible: animeSearchCard.coverSource === ""
                color:   Kirigami.Theme.disabledTextColor
            }
        }

        // Text
        ColumnLayout {
            Layout.fillWidth:   true
            Layout.alignment:   Qt.AlignTop
            Layout.leftMargin:  14
            Layout.rightMargin: 12
            Layout.topMargin:   10
            spacing: 4

            Controls.Label {
                Layout.fillWidth: true
                text:  animeSearchCard.title
                color: Kirigami.Theme.textColor
                font { bold: true; pixelSize: 15 }
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Controls.Label {
                Layout.fillWidth: true
                text: animeSearchCard.year > 0
                        ? (animeSearchCard.mediaType + " • " + animeSearchCard.year)
                        : animeSearchCard.mediaType
                color: Kirigami.Theme.highlightColor
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Rating — shows "—" when the show has no votes yet,
                // same "always visible, dash for empty" convention
                // AnimeCard uses for the viewer's own score.
                Kirigami.Icon {
                    source: "starred-symbolic"
                    width:  16
                    height: 16
                    color:  animeSearchCard.hasScore
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.disabledTextColor
                }
                Controls.Label {
                    text:  animeSearchCard.formattedScore
                    color: animeSearchCard.hasScore
                            ? Kirigami.Theme.textColor
                            : Kirigami.Theme.disabledTextColor
                    font.pixelSize: 13
                }

                Item { Layout.preferredWidth: 10 }

                Kirigami.Icon {
                    source: "love"
                    width:  15
                    height: 15
                    color:  "#e05562"
                }
                Controls.Label {
                    text:  animeSearchCard.formattedFavourites
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                visible: animeSearchCard.statusMeta.label !== ""

                Kirigami.Icon {
                    source: "draw-circle-symbolic"
                    width: 8
                    height: 8
                    color: animeSearchCard.statusMeta.color
                }
                Controls.Label {
                    id: statusLabel
                    text: animeSearchCard.statusMeta.label
                    color: animeSearchCard.statusMeta.color
                    font {
                        bold: true
                        pixelSize: 13
                    }
                }
            }
        }
    }
}
