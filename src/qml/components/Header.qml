import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var title
    property var bannerImage
    property var coverImage
    property var description

    spacing: 0

    // Banner
    Rectangle {
        id: banner
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14
        clip: true
        color: Kirigami.Theme.alternateBackgroundColor

        Image {
            anchors.fill: parent
            source: bannerImage || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            mipmap: true
        }

        // Fade the banner into the page background instead of
        // cutting off sharply into the content below
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Kirigami.Theme.backgroundColor }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.ShadowedImage {
            id: cover
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.preferredHeight: Kirigami.Units.gridUnit * 17
            Layout.alignment: Qt.AlignTop

            source: coverImage || ""
            fillMode: Image.PreserveAspectCrop // Prevents image distortion
            color: Kirigami.Theme.alternateBackgroundColor

            radius: Kirigami.Units.smallSpacing
            border.width: 1
            border.color: Kirigami.Theme.separatorColor

            shadow.size: Kirigami.Units.largeSpacing
            shadow.yOffset: 2
            shadow.color: Qt.rgba(0, 0, 0, 0.4)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                id: titleLabel
                Layout.fillWidth: true
                level: 1
                text: title || "Loading..."
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Controls.Label {
                id: descriptionLabel
                Layout.fillWidth: true
                text: description || "Loading..."
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}