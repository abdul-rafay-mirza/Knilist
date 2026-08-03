import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animeListPage
    title: "Anime List"
    padding: 0

    // ── Status filters ────────────────────────────────────────────────────────
    readonly property var statusFilters: [
        { id: "ALL",       label: "All",       icon: "applications-all-symbolic"            },
        { id: "CURRENT",   label: "Watching",  icon: "media-playback-start-symbolic" },
        { id: "REPEATING", label: "Rewatching", icon: "media-playlist-repeat"     },
        { id: "COMPLETED", label: "Completed", icon: "emblem-ok-symbolic"            },
        { id: "PAUSED",    label: "Paused",    icon: "media-playback-pause-symbolic" },
        { id: "DROPPED",   label: "Dropped",   icon: "edit-delete-symbolic"          },
        { id: "PLANNING",  label: "Planning",  icon: "appointment-new-symbolic"      },
    ]

    AnimeScoreDialog {
        id: animeScoreDialog
    }

    property string selectedStatus: settings.animeListSelectedStatus
    property string searchQuery:    ""
    property var    animeData:      []

    ListModel { id: displayModel }

    function rebuildModel() {
        displayModel.clear()
        const q = searchQuery.toLowerCase().trim()
        for (let i = 0; i < animeData.length; i++) {
            const item = animeData[i]
            const statusMatch = selectedStatus === "ALL" || item.status === selectedStatus
            const searchMatch = q === ""
                || item.title.toLowerCase().includes(q)
                || (item.titleRomaji && item.titleRomaji.toLowerCase().includes(q))
            if (statusMatch && searchMatch)
                displayModel.append(item)
        }
    }

    function countForStatus(statusId) {
        if (statusId === "ALL") return animeData.length
        let n = 0
        for (let i = 0; i < animeData.length; i++)
            if (animeData[i].status === statusId) n++
        return n
    }

    function incrementProgress(anilistId) {
        let item = null
        for (let i = 0; i < animeData.length; i++) {
            if (animeData[i].anilistId === anilistId) { item = animeData[i]; break }
        }
        if (!item) return
        if (item.episodes > 0 && item.progress >= item.episodes) return

        const newProgress = item.progress + 1
        const newStatus = (item.episodes > 0 && newProgress === item.episodes)
            ? "COMPLETED" : "CURRENT"

        // animeData is left untouched — the list only refreshes once the mutation
        // succeeds and the resulting fetchAnime() comes back with real data.
        anilistService.saveAnimeProgress(anilistId, newProgress, newStatus)
    }

    // ── Open List Editor dialog ───────────────────────────────────────────────
    function openEditor(anilistId) {
        let entry = null
        for (let i = 0; i < animeData.length; i++) {
            if (animeData[i].anilistId === anilistId) { entry = animeData[i]; break }
        }
        if (!entry) return

        function parsePart(dateStr, part) {
            if (!dateStr || dateStr.length < 10) return 0
            const p = dateStr.split("-")
            if (part === "y") return parseInt(p[0]) || 0
            if (part === "m") return parseInt(p[1]) || 0
            if (part === "d") return parseInt(p[2]) || 0
            return 0
        }
        const sd = entry.startedAt   || ""
        const fd = entry.completedAt || ""

        listEditor.anilistId            = entry.anilistId
        listEditor.animeTitle           = entry.title
        listEditor.currentStatus        = entry.status
        listEditor.currentScore         = entry.score
        listEditor.currentProgress      = entry.progress
        listEditor.currentTotalEpisodes = entry.episodes
        listEditor.currentStartYear     = parsePart(sd, "y")
        listEditor.currentStartMonth    = parsePart(sd, "m")
        listEditor.currentStartDay      = parsePart(sd, "d")
        listEditor.currentFinishYear    = parsePart(fd, "y")
        listEditor.currentFinishMonth   = parsePart(fd, "m")
        listEditor.currentFinishDay     = parsePart(fd, "d")
        listEditor.currentRewatches     = entry.rewatches  || 0
        listEditor.currentNotes         = entry.notes      || ""
        listEditor.currentPriority      = entry.priority   || 0
        listEditor.currentHideFromLists = entry.hiddenFromStatusLists || false
        listEditor.currentPrivate       = entry.isPrivate  || false

        listEditor.open()
    }

    // ── List Editor dialog instance ───────────────────────────────────────────
    AnimeListEditorDialog {
        id: listEditor
        onEntrySaved:   anilistService.fetchAnime()
        onEntryRemoved: anilistService.fetchAnime()
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService
        function onAnimeLoaded(data) {
            animeListPage.animeData = data
            animeListPage.rebuildModel()
        }
        function onAnimeEntrySaved() {
            anilistService.fetchAnime()
        }
    }

    Connections {
        target: authManager
        function onLogoutDone() {
            animeListPage.animeData = []
            animeListPage.rebuildModel()
        }
    }

    Component.onCompleted: {
        if (authManager.isLoggedIn && animeData.length === 0)
            anilistService.fetchAnime()
    }

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
                    model: animeListPage.statusFilters
                    delegate: Controls.ItemDelegate {
                        id: navItem
                        Layout.fillWidth: true
                        highlighted: animeListPage.selectedStatus === modelData.id

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
                                readonly property int count: animeListPage.countForStatus(modelData.id)
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

                        onClicked: animeListPage.selectedStatus = modelData.id
                    }
                }

                Item { Layout.fillHeight: true }

                Controls.ToolButton {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.smallSpacing
                    Layout.rightMargin:  Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    icon.name: "view-refresh-symbolic"
                    text:      "Sync"
                    visible:   authManager.isLoggedIn
                    enabled:   !anilistService.loading
                    onClicked: anilistService.fetchAnime()
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ── Anime list ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth:    true
                Layout.leftMargin:   Kirigami.Units.largeSpacing
                Layout.rightMargin:  Kirigami.Units.largeSpacing
                Layout.topMargin:    Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                placeholderText: "Search anime…"
                onTextChanged: animeListPage.searchQuery = text
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
                    visible: !authManager.isLoggedIn && !anilistService.loading
                    width:   parent.width - Kirigami.Units.gridUnit * 4
                    icon.name:   "im-user-symbolic"
                    text:        "Not logged in"
                    explanation: "Log in to AniList from the Settings page to see your anime list."
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: authManager.isLoggedIn
                            && !anilistService.loading
                            && displayModel.count === 0
                    width:   parent.width - Kirigami.Units.gridUnit * 4
                    icon.name: "view-list-symbolic"
                    text:      "No anime here yet"
                }

                ListView {
                    id:           animeListView
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

                    delegate: AnimeCard {
                        width: ListView.view.width
                            - animeListView.leftMargin
                            - animeListView.rightMargin

                        title:           model.title
                        mediaType:       model.mediaType
                        nextEpisodeText: model.nextEpText
                        rating:          model.score
                        watchedEpisodes: model.progress
                        totalEpisodes:   model.episodes
                        coverSource:     model.cover
                        anilistId:       model.anilistId

                        onAddEpisode:  animeListPage.incrementProgress(model.anilistId)
                        onCardClicked: animeListPage.openEditor(model.anilistId)
                        onScoreClicked: {
                            animeScoreDialog.anilistId    = model.anilistId
                            animeScoreDialog.currentScore = model.score
                            animeScoreDialog.open()
                        }
                        onImageClicked: {
                            applicationWindow().pageStack.layers.push(
                                Qt.resolvedUrl("AnimePage.qml"),
                                { animeId: model.anilistId }
                            )
                        }
                    }
                }
            }
        }
    }
}
