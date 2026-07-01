import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Generic — works for both anime and manga.
    // Each entry: { site: string, url: string }
    property var links: []
    readonly property var safeLinks: links || []

    visible: safeLinks.length > 0

    // Let the parent layout size us vertically by content
    implicitHeight: visible ? (layout.implicitHeight + Kirigami.Units.largeSpacing * 2) : 0

    // ── Themed sidebar background ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.alternateBackgroundColor
    }

    // ── Right-edge separator ──────────────────────────────────────────────────
    Kirigami.Separator {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    ColumnLayout {
        id: layout
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   Kirigami.Units.largeSpacing
            leftMargin:  Kirigami.Units.largeSpacing
            rightMargin: Kirigami.Units.largeSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            text:        "External Links"
            font.weight: Font.DemiBold
            color:       Kirigami.Theme.textColor
        }

        Repeater {
            model: root.safeLinks

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight:   Kirigami.Units.gridUnit * 2
                radius:           Kirigami.Units.cornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b,
                               linkMouseArea.containsMouse ? 0.1 : 0.06)

                MouseArea {
                    id:           linkMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    Qt.openUrlExternally(modelData.url || "")
                    z: 1
                }

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  Kirigami.Units.largeSpacing
                    anchors.rightMargin: Kirigami.Units.largeSpacing

                    Controls.Label {
                        Layout.fillWidth: true
                        text:             modelData.site || ""
                        color:            Kirigami.Theme.textColor
                        elide:            Text.ElideRight
                    }

                    Controls.Label {
                        text:    "↗"
                        color:   Kirigami.Theme.textColor
                        opacity: 0.6
                    }
                }
            }
        }

        Item { implicitHeight: Kirigami.Units.largeSpacing }
    }
}
