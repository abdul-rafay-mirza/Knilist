import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: studioPage
    title: "Studio"

    property int studioId: 0

    Controls.Label {
        anchors.centerIn: parent
        text: "Studio ID: " + studioId
    }
}
