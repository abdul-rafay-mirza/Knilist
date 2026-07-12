import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    // Each entry: { value: <number>, label: <string> }
    property var stats: []
    property color accentColor: Kirigami.Theme.highlightColor

    Layout.fillWidth: true
    Layout.preferredHeight: statBarRow.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Kirigami.Theme.alternateBackgroundColor

    RowLayout {
        id: statBarRow
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: 0

        Repeater {
            model: root.stats

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: String(modelData.value || 0)
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        color: root.accentColor
                    }
                    Controls.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
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