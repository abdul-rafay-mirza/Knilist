import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    property string label: ""
    property string value: ""

    spacing:  1
    visible:  value !== ""

    Controls.Label {
        text:         label
        font.weight:  Font.DemiBold
        color:        Kirigami.Theme.textColor
        Layout.fillWidth: true
    }

    Controls.Label {
        text:         value
        color:        Kirigami.Theme.textColor
        opacity:      0.85
        wrapMode:     Text.WordWrap
        Layout.fillWidth: true
    }
}
