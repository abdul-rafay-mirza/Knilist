import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    title: "About Knilist"

    standardButtons: Kirigami.Dialog.Close

    implicitWidth:  Kirigami.Units.gridUnit * 28
    implicitHeight: Kirigami.Units.gridUnit * 32

    Kirigami.AboutPage {
        anchors.fill: parent
        aboutData: about.aboutData
    }
}
