import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Generic — works for both anime and manga.
    // Each entry: { name: string, rank: int, isMediaSpoiler: bool }
    property var tags: []

    property bool _spoilersRevealed: false

    readonly property var sortedTags: {
        const arr = (tags || []).slice()
        arr.sort((a, b) => (b.rank || 0) - (a.rank || 0))
        return arr
    }
    readonly property var visibleTags: sortedTags.filter(t => !t.isMediaSpoiler)
    readonly property var spoilerTags: sortedTags.filter(t => t.isMediaSpoiler)

    visible: sortedTags.length > 0

    // Different media's tags come in via the same instance — don't leak reveal state
    onTagsChanged: _spoilersRevealed = false

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

    // ── Shared row look for a single tag ────────────────────────────────────
    Component {
        id: tagRowDelegate

        Rectangle {
            Layout.fillWidth: true
            implicitHeight:   Kirigami.Units.gridUnit * 2
            radius:           Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b,
                           0.06)

            RowLayout {
                anchors.fill:        parent
                anchors.leftMargin:  Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing

                Controls.Label {
                    Layout.fillWidth: true
                    text:             modelData.name || ""
                    color:            Kirigami.Theme.textColor
                    elide:            Text.ElideRight
                }

                Controls.Label {
                    text:    `${modelData.rank || 0}%`
                    color:   Kirigami.Theme.textColor
                    opacity: 0.6
                }
            }
        }
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
            text:        "Tags"
            font.weight: Font.DemiBold
            color:       Kirigami.Theme.textColor
        }

        Repeater {
            model:    root.visibleTags
            delegate: tagRowDelegate
        }

        // Spoiler tags — collapsed behind a single hint until clicked
        Rectangle {
            Layout.fillWidth: true
            visible:          !root._spoilersRevealed && root.spoilerTags.length > 0
            implicitHeight:   Kirigami.Units.gridUnit * 2
            radius:           Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b,
                           0.06)

            MouseArea {
                id:           spoilerHint
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root._spoilersRevealed = true
                z: 1
            }

            Controls.Label {
                anchors.centerIn: parent
                text: `Click to Show ${root.spoilerTags.length} Spoiler Tag${root.spoilerTags.length === 1 ? "" : "s"}`
                color: spoilerHint.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }
        }

        Repeater {
            model:    root._spoilersRevealed ? root.spoilerTags : []
            delegate: tagRowDelegate
        }

        Item { implicitHeight: Kirigami.Units.largeSpacing }
    }
}
