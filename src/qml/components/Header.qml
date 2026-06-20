import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var title
    property var bannerImage
    property var coverImage
    property var description
    property var entry:         null   // JS object from animeEntryLoaded, or null
    property int totalProgress: 0
    property bool isFavourite:  false

    signal editRequested()
    signal favouriteToggled()

    spacing: 0

    // ── Status label helper ───────────────────────────────────────────────────
    property var statusLabels: ({
        "CURRENT":   "CURRENT",
        "COMPLETED": "COMPLETED",
        "PAUSED":    "PAUSED",
        "DROPPED":   "DROPPED",
        "PLANNING":  "PLANNING",
        "REPEATING": "REPEATING",
    })

    readonly property string _statusText: {
        if (!root.entry || !root.entry.onList) return "Add to List"
        return root.statusLabels[root.entry.status] || "Add to List"
    }

    // ── Banner ────────────────────────────────────────────────────────────────
    Rectangle {
        id: banner
        Layout.fillWidth:        true
        Layout.preferredHeight:  Kirigami.Units.gridUnit * 14
        clip:  true
        color: Kirigami.Theme.alternateBackgroundColor

        Image {
            anchors.fill: parent
            source:       bannerImage || ""
            fillMode:     Image.PreserveAspectCrop
            asynchronous: true
            mipmap:       true
        }

        // Fade banner into page background
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent"                  }
                GradientStop { position: 1.0; color: Kirigami.Theme.backgroundColor }
            }
        }
    }

    // ── Cover + info row ──────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.margins:   Kirigami.Units.largeSpacing
        spacing:          Kirigami.Units.largeSpacing

        // ── Cover image + action buttons ──────────────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing:          Kirigami.Units.smallSpacing

            Kirigami.ShadowedImage {
                id: cover
                Layout.preferredWidth:  Kirigami.Units.gridUnit * 12   // fixed, untouched
                Layout.preferredHeight: Kirigami.Units.gridUnit * 17

                source:   coverImage || ""
                fillMode: Image.PreserveAspectCrop
                color:    Kirigami.Theme.alternateBackgroundColor

                radius:       Kirigami.Units.smallSpacing
                border.width: 1
                border.color: Kirigami.Theme.separatorColor

                shadow.size:    Kirigami.Units.largeSpacing
                shadow.yOffset: 2
                shadow.color:   Qt.rgba(0, 0, 0, 0.4)
            }

            // Status + favourite buttons
            RowLayout {
                Layout.preferredWidth: cover.width   // bound to cover's actual rendered width
                Layout.maximumWidth:   cover.width   // hard clamp so children can't push it wider
                spacing:               Kirigami.Units.smallSpacing

                Controls.Button {
                    Layout.fillWidth: true
                    text:             root._statusText
                    onClicked:        root.editRequested()
                }

                Controls.Button {
                    onClicked: {
                        console.log("Favorites Clicked!")
                        root.favouriteToggled()
                    }

                    flat: true

                    contentItem: Kirigami.Icon {
                        source:         "love"
                        isMask:         true
                        color:          root.isFavourite ? "#e05562" : Kirigami.Theme.textColor
                        implicitWidth:  Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small

                        onColorChanged: console.log("icon color changed:", color)
                    }
                }
            }
        }

        // ── Title + description ───────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.alignment:  Qt.AlignTop
            spacing:           Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level:            1
                text:             title || "Loading..."
                wrapMode:         Text.WordWrap
                maximumLineCount: 2
                elide:            Text.ElideRight
            }

            Controls.Label {
                Layout.fillWidth: true
                text:             description || "Loading..."
                wrapMode:         Text.WordWrap
                color:            Kirigami.Theme.disabledTextColor
                textFormat:       Text.RichText
            }
        }
    }
}
