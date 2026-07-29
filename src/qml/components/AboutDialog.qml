import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    title: "About Knilist"

    standardButtons: Kirigami.Dialog.Close

    implicitWidth: Kirigami.Units.gridUnit * 28

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "com.github.abdul-rafay-mirza.knilist"
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 72
            implicitHeight: 72
        }

        Kirigami.Heading {
            text: "Knilist"
            level: 1
            Layout.alignment: Qt.AlignHCenter
        }

        Controls.Label {
            text: "Version 0.1.0"
            opacity: 0.65
            Layout.alignment: Qt.AlignHCenter
        }

        Controls.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap

            text: "A native AniList desktop client built with Python, Qt and Kirigami."
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing

            Controls.Label { text: "Author" }
            Controls.Label { text: "Abdul Rafay" }

            Controls.Label { text: "License" }
            Controls.Label { text: "GPL-3.0-or-later" }

            Controls.Label { text: "Built with" }
            Controls.Label { text: "Python • Qt 6 • Kirigami" }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Controls.Button {
                text: "GitHub"
                icon.name: "internet-web-browser-symbolic"

                onClicked: Qt.openUrlExternally(
                    "https://github.com/abdul-rafay-mirza/Knilist")
            }

            Controls.Button {
                text: "Report Issue"
                icon.name: "tools-report-bug-symbolic"

                onClicked: Qt.openUrlExternally(
                    "https://github.com/abdul-rafay-mirza/Knilist/issues")
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.55

            text: "Knilist is an unofficial AniList client and is not affiliated with or endorsed by AniList."
        }
    }
}