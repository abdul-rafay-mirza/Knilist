import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// The page representing another Anilist user's Manga list (read-only).
// Accessed from UsersPage > Click on the Manga cell in StatBar.
//
// Mirrors MangaListPage's sidebar/status-filter/search layout exactly, but
// the data source is this user's list (fetchUserManga), not the viewer's own
// (fetchManga), and the MangaCard delegate has every interaction disabled
// except imageClicked - editing status/score/progress only makes sense for
// the viewer's own list, so those actions (and the editor/score dialogs
// MangaListPage wires up for them) are intentionally left out here.

Kirigami.Page {
    id: usersMangaListPage
    title: userName + "'s Manga List"
    padding: 0

    property var userId: 0
    property var userName: "User"

    // ── Status filters ────────────────────────────────────────────────────────
    readonly property var statusFilters: [
        { id: "ALL",       label: "All",       icon: "applications-all-symbolic"     },
        { id: "CURRENT",   label: "Reading",   icon: "media-playback-start-symbolic" },
        { id: "REPEATING", label: "Rereading", icon: "media-playlist-repeat"         },
        { id: "COMPLETED", label: "Completed", icon: "emblem-ok-symbolic"            },
        { id: "PAUSED",    label: "Paused",    icon: "media-playback-pause-symbolic" },
        { id: "DROPPED",   label: "Dropped",   icon: "edit-delete-symbolic"          },
        { id: "PLANNING",  label: "Planning",  icon: "appointment-new-symbolic"      },
    ]

    property string selectedStatus: "ALL"
    property string searchQuery:    ""
    property var    mangaData:      []

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: anilistService.fetchUserManga(usersMangaListPage.userId)
        }
    ]

    ListModel { id: displayModel }

    function rebuildModel() {
        displayModel.clear()
        const q = searchQuery.toLowerCase().trim()
        for (let i = 0; i < mangaData.length; i++) {
            const item = mangaData[i]
            const statusMatch = selectedStatus === "ALL" || item.status === selectedStatus
            const searchMatch = q === ""
                || item.title.toLowerCase().includes(q)
                || (item.titleRomaji && item.titleRomaji.toLowerCase().includes(q))
            if (statusMatch && searchMatch)
                displayModel.append(item)
        }
    }

    function countForStatus(statusId) {
        if (statusId === "ALL") return mangaData.length
        let n = 0
        for (let i = 0; i < mangaData.length; i++)
            if (mangaData[i].status === statusId) n++
        return n
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService

        function onUserMangaLoaded(loadedUserId, data) {
            // userMangaLoaded is shared by every UsersMangaListPage instance
            // that might be stacked in pageStack.layers (e.g. drilling from
            // one user's followers into another user's page) - only react if
            // it's this instance's own user, same guard style UsersPage uses
            // for followToggled.
            if (loadedUserId !== usersMangaListPage.userId)
                return
            usersMangaListPage.mangaData = data
            usersMangaListPage.rebuildModel()
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
        }
    }

    Component.onCompleted: anilistService.fetchUserManga(usersMangaListPage.userId)

    onSelectedStatusChanged: rebuildModel()
    onSearchQueryChanged:    rebuildModel()

    // ═══════════════════════════════════════════════════════════════════════════
    // Layout
    // ═══════════════════════════════════════════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        spacing:      0

        // ── Sidebar ───────────────────────────────────────────────────────────
        Rectangle {
            id: sidebar
            Layout.fillHeight:     true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            color: Kirigami.Theme.backgroundColor
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit:  false

            ColumnLayout {
                anchors {
                    fill:         parent
                    topMargin:    Kirigami.Units.smallSpacing
                    bottomMargin: Kirigami.Units.smallSpacing
                }
                spacing: 2

                Repeater {
                    model: usersMangaListPage.statusFilters
                    delegate: Controls.ItemDelegate {
                        id: navItem
                        Layout.fillWidth: true
                        highlighted: usersMangaListPage.selectedStatus === modelData.id

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source:         modelData.icon
                                implicitWidth:  Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                color: navItem.highlighted
                                       ? Kirigami.Theme.highlightedTextColor
                                       : Kirigami.Theme.textColor
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                text:  modelData.label
                                color: navItem.highlighted
                                       ? Kirigami.Theme.highlightedTextColor
                                       : Kirigami.Theme.textColor
                                font.weight: navItem.highlighted ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                readonly property int count: usersMangaListPage.countForStatus(modelData.id)
                                visible: count > 0
                                width:  Math.max(
                                    Kirigami.Units.gridUnit * 1.4,
                                    badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2)
                                height: Kirigami.Units.gridUnit * 1.1
                                radius: height / 2
                                color:  navItem.highlighted
                                        ? Qt.rgba(1,1,1,0.25)
                                        : Kirigami.Theme.highlightColor
                                Controls.Label {
                                    id:               badgeLabel
                                    anchors.centerIn: parent
                                    text:             parent.count
                                    font.pointSize:   Kirigami.Theme.smallFont.pointSize
                                    color:            Kirigami.Theme.highlightedTextColor
                                }
                            }
                        }

                        background: Rectangle {
                            color: navItem.highlighted
                                   ? Kirigami.Theme.highlightColor
                                   : navItem.hovered
                                     ? Qt.rgba(
                                           Kirigami.Theme.highlightColor.r,
                                           Kirigami.Theme.highlightColor.g,
                                           Kirigami.Theme.highlightColor.b,
                                           0.15)
                                     : "transparent"
                            radius: Kirigami.Units.smallSpacing
                            anchors {
                                fill:        parent
                                leftMargin:  Kirigami.Units.smallSpacing
                                rightMargin: Kirigami.Units.smallSpacing
                            }
                        }

                        onClicked: usersMangaListPage.selectedStatus = modelData.id
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ── Manga list ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            Kirigami.InlineMessage {
                id: errorMessage
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                type: Kirigami.MessageType.Error
                showCloseButton: true
                visible: false
            }

            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth:    true
                Layout.leftMargin:   Kirigami.Units.largeSpacing
                Layout.rightMargin:  Kirigami.Units.largeSpacing
                Layout.topMargin:    Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                placeholderText: "Search manga…"
                onTextChanged: usersMangaListPage.searchQuery = text
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                Rectangle {
                    anchors.fill: parent
                    visible:      anilistService.loading
                    color:        Kirigami.Theme.backgroundColor
                    opacity:      0.6
                    z:            2

                    MouseArea {
                        anchors.fill: parent
                        enabled:      anilistService.loading
                        hoverEnabled: true
                    }

                    Controls.BusyIndicator {
                        anchors.centerIn: parent
                        running:  true
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: !anilistService.loading && displayModel.count === 0
                    width:   parent.width - Kirigami.Units.gridUnit * 4
                    icon.name: "view-list-symbolic"
                    text:      "No manga here yet"
                }

                ListView {
                    id:           mangaListView
                    anchors.fill: parent
                    model:        displayModel
                    spacing:      Kirigami.Units.largeSpacing
                    topMargin:    Kirigami.Units.largeSpacing
                    bottomMargin: Kirigami.Units.largeSpacing
                    leftMargin:   Kirigami.Units.largeSpacing
                    rightMargin:  Kirigami.Units.largeSpacing
                    clip:         true

                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        policy:      Controls.ScrollBar.AsNeeded
                        minimumSize: 0.05
                    }

                    delegate: MangaCard {
                        width: ListView.view.width
                            - mangaListView.leftMargin
                            - mangaListView.rightMargin

                        interactive: false

                        title:         model.title
                        mediaType:     model.mediaType
                        rating:        model.score
                        readChapters:  model.progress
                        totalChapters: model.chapters
                        readVolumes:   model.progressVolumes
                        totalVolumes:  model.volumes
                        coverSource:   model.cover
                        anilistId:     model.anilistId

                        onImageClicked: {
                            applicationWindow().pageStack.layers.push(
                                Qt.resolvedUrl("MangaPage.qml"),
                                { anilistId: model.anilistId }
                            )
                        }
                    }
                }
            }
        }
    }
}
