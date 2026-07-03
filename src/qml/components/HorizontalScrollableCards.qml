import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var mediaCardContent: []
    property string headingText: "Default Heading Text"

    signal cardClicked(int mediaId, string mediaType)

    visible:             mediaCardContent && mediaCardContent.length > 0
    spacing:             Kirigami.Units.smallSpacing
    Layout.fillWidth:    true
    Layout.leftMargin:   Kirigami.Units.largeSpacing
    Layout.rightMargin:  Kirigami.Units.largeSpacing
    Layout.bottomMargin: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        level: 3
        text:  headingText
    }

    Kirigami.Separator { Layout.fillWidth: true }

    ListView {
        id:               recListView
        Layout.fillWidth: true
        implicitHeight:   contentItem.childrenRect.height
        orientation:      ListView.Horizontal
        spacing:          Kirigami.Units.largeSpacing
        clip:             true
        model:            root.mediaCardContent

        delegate: MediaCoverCard {
            required property var modelData

            mediaId:  modelData.mediaId
            title:    modelData.title || ""
            imageURL: modelData.coverImage || ""
            onTapped: root.cardClicked(modelData.mediaId, modelData.type || "")
        }
    }

    Controls.ScrollBar {
        Layout.fillWidth: true
        orientation:      Qt.Horizontal
        policy:           Controls.ScrollBar.AsNeeded
        size:             recListView.visibleArea.widthRatio
        position:         recListView.visibleArea.xPosition
        onPositionChanged: if (pressed) recListView.contentX = position * recListView.contentWidth
    }
}