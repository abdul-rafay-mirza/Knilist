import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: mediaCoverCard

    property int    mediaId:  0
    property string title:    ""
    property string imageURL: ""

    signal tapped()

    implicitWidth:  Kirigami.Units.gridUnit * 9
    implicitHeight: cardColumn.implicitHeight

    ColumnLayout {
        id:      cardColumn
        width:   parent.width
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.preferredWidth:  parent.width
            Layout.preferredHeight: Kirigami.Units.gridUnit * 13
            radius: Kirigami.Units.cornerRadius
            clip:   true
            color:  Kirigami.Theme.alternateBackgroundColor

            Image {
                anchors.fill: parent
                source:       mediaCoverCard.imageURL
                fillMode:     Image.PreserveAspectCrop
                asynchronous: true
                mipmap:       true
            }
        }

        Controls.Label {
            Layout.fillWidth:    true
            text:                mediaCoverCard.title
            wrapMode:            Text.WordWrap
            maximumLineCount:    3
            elide:               Text.ElideRight
            font.pointSize:      Kirigami.Theme.defaultFont.pointSize * 0.85
            color:               Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
        }
    }

    TapHandler {
        onTapped: mediaCoverCard.tapped()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
