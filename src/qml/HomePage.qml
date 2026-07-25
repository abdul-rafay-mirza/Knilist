import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.ScrollablePage {
    id: homePage
    title: "Home"

    // Same shape as ProfilePage's `profile` property ({name, avatar,
    // bannerImage, ...}), just populated from the lighter fetchHomeProfile()/
    // homeProfileLoaded round-trip instead of the full profile fetch, since
    // the header only needs name + avatar + banner.
    property var profile: ({})

    readonly property int bannerHeight: Kirigami.Units.gridUnit * 10
    readonly property int avatarSize: Kirigami.Units.gridUnit * 7
    property bool searchExpanded: false

    readonly property var searchTypes: ["Anime", "Manga", "Characters", "Staff", "Studios", "Users"]

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: anilistService.fetchHomeProfile()
        }
    ]

    Component.onCompleted: {
        anilistService.fetchHomeProfile()
        loadingOverlayComponent.createObject(homePage.overlay)
    }

    Connections {
        target: anilistService

        function onHomeProfileLoaded(json) {
            homePage.profile = JSON.parse(json)
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
        }
    }

    ColumnLayout {
        width: homePage.width
        spacing: 0

        Kirigami.InlineMessage {
            id: errorMessage
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            type: Kirigami.MessageType.Error
            showCloseButton: true
            visible: false
        }

        // ── Banner + left-aligned avatar + greeting ─────────────────────
        Item {
            id: headerArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(
                homePage.bannerHeight + homePage.avatarSize / 2,
                homePage.bannerHeight + Kirigami.Units.smallSpacing * 2 + greetingLabel.implicitHeight
            )

            Rectangle {
                id: bannerFallback
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: homePage.bannerHeight
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                    GradientStop { position: 1.0; color: Qt.darker(Kirigami.Theme.highlightColor, 1.6) }
                }
            }

            Image {
                id: bannerImage
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: homePage.bannerHeight
                source: homePage.profile.bannerImage || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                visible: status === Image.Ready
            }

            // Fallback disc behind the avatar, shown until the real image
            // loads — extends the same fallback-layer idea bannerFallback
            // above already uses for the banner.
            Rectangle {
                id: avatarFallback
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing * 2
                y: homePage.bannerHeight - height / 2
                width: homePage.avatarSize
                height: homePage.avatarSize
                radius: width / 2
                color: Kirigami.Theme.backgroundColor
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
                visible: avatarImage.status !== Image.Ready

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    source: "avatar-default"
                }
            }

            AnimatedImage {
                id: avatarImage

                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing * 2
                y: homePage.bannerHeight - height / 2

                width: homePage.avatarSize
                height: homePage.avatarSize

                source: homePage.profile.avatar || ""
                fillMode: Image.PreserveAspectCrop

                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
            }

            Kirigami.Heading {
                id: greetingLabel
                anchors.left: avatarImage.right
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.largeSpacing * 2
                anchors.top: bannerFallback.bottom
                anchors.topMargin: Kirigami.Units.smallSpacing * 2
                level: 1
                text: "Hello " + (homePage.profile.name || "there")
                elide: Text.ElideRight
            }
        }

        // ── Search ───────────────────────────────────────────────────────
        // Looks like a search field but isn't one — tapping it opens a menu
        // of searchable types instead of accepting text input. Picking a
        // type is what will push the dedicated search page later.
        Rectangle {
            id: fakeSearchBar
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing * 2
            Layout.topMargin: Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: searchBarHover.hovered
                ? Kirigami.Theme.highlightColor
                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: "search"
                    opacity: 0.6
                }

                Controls.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Search anime, manga, characters, staff, studios, users…"
                    color: Kirigami.Theme.textColor
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }

            TapHandler {
                onTapped: homePage.searchExpanded = !homePage.searchExpanded
            }

            HoverHandler {
                id: searchBarHover
                cursorShape: Qt.PointingHandCursor
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing * 2

            clip: true

            implicitHeight: homePage.searchExpanded
                ? dropdownContent.implicitHeight
                : 0

            opacity: homePage.searchExpanded ? 1 : 0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: Qt.rgba(
                    Kirigami.Theme.textColor.r,
                    Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b,
                    0.15
                )
                radius: Kirigami.Units.smallSpacing
            }

            Column {
                id: dropdownContent
                width: parent.width

                Repeater {
                    model: homePage.searchTypes

                    delegate: Controls.ItemDelegate {
                        width: parent.width
                        text: modelData

                        onClicked: {
                            homePage.searchExpanded = false
                            homePage.openSearchPage(modelData)
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
    }

    // ── Loading overlay (first load + refresh) ──────────────────────────
    // Built from a Component and instantiated with createObject() rather
    // than declared as a plain child of ScrollablePage. Any Item declared
    // directly under ScrollablePage is swept into its scroll content and
    // has anchors.left/right force-set onto it by ScrollablePage itself
    // (see ScrollablePage's Component.onCompleted), which would collide
    // with this overlay's own anchors.fill. Creating it via Component +
    // createObject(homePage.overlay, ...) — Kirigami.Page's built-in
    // "on top of everything" layer — sidesteps that mechanism entirely and
    // covers the whole page, matching what ProfilePage's overlay achieves
    // manually via its own dedicated Item root.
    Component {
        id: loadingOverlayComponent

        Rectangle {
            anchors.fill: parent
            visible: anilistService.loading
            color: Kirigami.Theme.backgroundColor
            opacity: 0.6
            z: 2

            MouseArea {
                anchors.fill: parent
                enabled: anilistService.loading
                hoverEnabled: true
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: true
            }
        }
    }

    function openSearchPage(searchType) {
        pageStack.layers.push(Qt.resolvedUrl("SearchPage.qml"), { searchType: searchType })
    }
}
