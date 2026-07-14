import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    // ── Public API ───────────────────────────────────────────────────────
    // Field names match the JSON coming out of AniListService.fetchFollowing/
    // fetchFollowers (_flatten_user_list), so wiring this up later is a
    // straight property binding — no renaming needed.
    property int userId: 0
    property string name: ""
    property string avatar: ""
    property string bannerImage: ""
    property bool isFollowing: false
    property bool isFollower: false
    readonly property bool isMutual: isFollowing && isFollower

    property var createdAt: ""
    property var updatedAt: ""

    signal cardTapped()
    signal moreRequested()

    readonly property int bannerHeight: Kirigami.Units.gridUnit * 4
    readonly property int avatarSize: Kirigami.Units.gridUnit * 3.5
    readonly property int avatarLeftMargin: Kirigami.Units.largeSpacing * 2

    padding: 0

    contentItem: ColumnLayout {
        spacing: 0

        // ── Banner + overlapping avatar ─────────────────────────────────
        Item {
            id: headerArea
            Layout.fillWidth: true
            Layout.preferredHeight: root.bannerHeight + root.avatarSize / 2

            Rectangle {
                id: bannerFallback
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: root.bannerHeight
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                    GradientStop { position: 1.0; color: Qt.darker(Kirigami.Theme.highlightColor, 1.6) }
                }
            }

            Image {
                id: bannerImg
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: root.bannerHeight
                source: root.bannerImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                visible: status === Image.Ready
            }

            AnimatedImage {
                id: avatarImg
                x: root.avatarLeftMargin
                y: root.bannerHeight - height / 2
                width: root.avatarSize
                height: root.avatarSize
                source: root.avatar || ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.smooth: true
                asynchronous: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
            }
        }

        // ── Name · Mutual badge · overflow menu ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: root.name
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.isMutual
                radius: height / 2
                color: Kirigami.Theme.highlightColor
                height: mutualLabel.implicitHeight + Kirigami.Units.smallSpacing
                width: mutualLabel.implicitWidth + Kirigami.Units.largeSpacing

                Controls.Label {
                    id: mutualLabel
                    anchors.centerIn: parent
                    text: "Mutual"
                    color: Kirigami.Theme.highlightedTextColor
                    font.bold: true
                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
                }
            }

            Item { Layout.fillWidth: true }   // pushes the overflow button to the edge

            Controls.ToolButton {
                icon.name: "overflow-menu"
                onClicked: root.moreRequested()
            }
        }

        // ── Following / Follower since ──────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing * 2
            Layout.topMargin: Kirigami.Units.smallSpacing / 2
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing / 2

            Controls.Label {
                visible: root.createdAt !== ""
                text: "Date Created: " + root.createdAt
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Controls.Label {
                visible: root.updatedAt !== ""
                text: "Date Updated: " + root.updatedAt
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    TapHandler {
        onTapped: root.cardTapped()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}