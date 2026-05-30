import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: mangaCard

    // Public API — matches manga normalised data
    property string title
    property string mediaType
    property real   rating
    property int    readChapters
    property int    totalChapters   // 0 = unknown / still publishing
    property int    readVolumes
    property int    totalVolumes    // 0 = unknown
    property string coverSource
    property int    anilistId

    signal addChapter()
    signal addVolume()
    signal cardClicked()
    signal scoreClicked()
    signal imageClicked()

    // Helpers
    readonly property bool  knownChapters:    totalChapters > 0
    readonly property bool  knownVolumes:     totalVolumes  > 0
    readonly property real  progressRatio:    knownChapters
                                              ? readChapters / totalChapters
                                              : 0.5
    readonly property string formattedScore:  anilistService.formatScore(rating)

    // Geometry
    implicitHeight: Math.max(150, contentItem.implicitHeight + 10)
    leftPadding:   0
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    TapHandler {
        onTapped: mangaCard.cardClicked()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    contentItem: RowLayout {
        anchors {
            fill:         parent
            bottomMargin: 5
        }
        spacing: 0

        // ── Cover image ───────────────────────────────────────────────────────
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
                onTapped: mangaCard.imageClicked()
            }

            Image {
                anchors.fill: parent
                source:       mangaCard.coverSource
                fillMode:     Image.PreserveAspectCrop
                smooth:       true
                visible:      mangaCard.coverSource !== ""
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:  "image-missing"
                width:   32; height: 32
                visible: mangaCard.coverSource === ""
                color:   Kirigami.Theme.disabledTextColor
            }
        }

        // ── Text + controls ───────────────────────────────────────────────────
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
                text:  mangaCard.title
                color: Kirigami.Theme.textColor
                font { bold: true; pixelSize: 15 }
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Format
            Controls.Label {
                Layout.fillWidth: true
                text:  mangaCard.mediaType
                color: Kirigami.Theme.highlightColor
                font.pixelSize: 12
            }

            Item { Layout.fillHeight: true }

            // ── Volume row ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item { Layout.fillWidth: true }

                Controls.Label {
                    text:  mangaCard.readVolumes + " / "
                           + (mangaCard.knownVolumes ? mangaCard.totalVolumes : "?")
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }

                // +1 VO button
                IncrementButton {
                    label: "+1 VO"
                    onClicked: mangaCard.addVolume()
                }
            }

            // ── Chapter row (score + chapters + +1 CH) ────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Score
                RowLayout {
                    spacing: 4

                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: mangaCard.scoreClicked()
                    }

                    Kirigami.Icon {
                        source: "starred-symbolic"
                        width:  16; height: 16
                        color:  mangaCard.rating > 0
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.disabledTextColor
                    }
                    Controls.Label {
                        text:  mangaCard.rating > 0
                               ? mangaCard.formattedScore
                               : "—"
                        color: mangaCard.rating > 0
                               ? Kirigami.Theme.textColor
                               : Kirigami.Theme.disabledTextColor
                        font.pixelSize: 13
                    }
                }

                Item { Layout.fillWidth: true }

                Controls.Label {
                    text:  mangaCard.readChapters + " / "
                           + (mangaCard.knownChapters ? mangaCard.totalChapters : "?")
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 13
                }

                // +1 CH button
                IncrementButton {
                    label: "+1 CH"
                    onClicked: mangaCard.addChapter()
                }
            }
        }
    }

    // ── Progress bar ──────────────────────────────────────────────────────────
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
            width:  parent.width * mangaCard.progressRatio
            height: parent.height
            color:  Kirigami.Theme.positiveTextColor

            Behavior on width {
                enabled: mangaCard.knownChapters
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }

    // ── Inline reusable button component ─────────────────────────────────────
    component IncrementButton: Rectangle {
        property string label: ""
        signal clicked()

        z:      1
        width:  68; height: 28
        radius: Kirigami.Units.smallSpacing
        color:  "transparent"
        border.color: Kirigami.Theme.highlightColor
        border.width: 2

        Controls.Label {
            anchors.centerIn: parent
            text:  parent.label
            color: Kirigami.Theme.highlightColor
            font { bold: true; pixelSize: 12 }
        }

        Rectangle {
            anchors.fill: parent
            radius:       parent.radius
            color:        Kirigami.Theme.highlightColor
            opacity:      btnArea.containsMouse ? 0.15 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id:           btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            propagateComposedEvents: false
            onClicked: (mouse) => {
                mouse.accepted = true
                parent.clicked()
            }
        }
    }
}
