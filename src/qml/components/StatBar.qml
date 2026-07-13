import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    // Each entry: { value: <number>, label: <string>, target: <string> }
    // target is a page filename Main.qml's switchToPage() can resolve, e.g.
    // "AnimeListPage.qml". Leave target === "" (or omit it) for a
    // non-interactive entry — matches Following/Followers, which have no
    // destination page yet.
    property var stats: []

    // Emitted on tap of any entry whose target is non-empty. This component
    // only reports intent — the caller decides what to do with it, same
    // division of responsibility as CharactersSection.onCharacterClicked.
    signal entryActivated(string target)

    Layout.preferredWidth: statBarRow.implicitWidth + Kirigami.Units.largeSpacing * 4
    Layout.preferredHeight: statBarRow.implicitHeight + Kirigami.Units.largeSpacing * 2

    radius: Kirigami.Units.cornerRadius
    color: Kirigami.Theme.alternateBackgroundColor

    RowLayout {
        id: statBarRow
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing * 2

        Repeater {
            model: root.stats

            delegate: RowLayout {
                id: statDelegate
                spacing: Kirigami.Units.largeSpacing

                readonly property bool interactive: !!(modelData.target && modelData.target.length > 0)

                ColumnLayout {
                    spacing: 0

                    Controls.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: String(modelData.value || 0)
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        color: statHover.hovered && statDelegate.interactive
                               ? Kirigami.Theme.linkColor
                               : Kirigami.Theme.highlightColor
                    }
                    Controls.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }

                    TapHandler {
                        enabled: statDelegate.interactive
                        onTapped: root.entryActivated(modelData.target)
                    }

                    HoverHandler {
                        id: statHover
                        enabled: statDelegate.interactive
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Kirigami.Separator {
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    visible: index < root.stats.length - 1
                }
            }
        }
    }
}
