import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: mangaPage
    title: "Manga List"
    padding: 0

    // ── Status filters ────────────────────────────────────────────────────────
    readonly property var statusFilters: [
        { id: "ALL",       label: "All",       icon: "view-list-symbolic"            },
        { id: "CURRENT",   label: "Reading",   icon: "media-playback-start-symbolic" },
        { id: "REPEATING", label: "Rereading", icon: "media-playlist-repeat"         },
        { id: "COMPLETED", label: "Completed", icon: "emblem-ok-symbolic"            },
        { id: "PAUSED",    label: "Paused",    icon: "media-playback-pause-symbolic" },
        { id: "DROPPED",   label: "Dropped",   icon: "edit-delete-symbolic"          },
        { id: "PLANNING",  label: "Planning",  icon: "appointment-new-symbolic"      },
    ]

    ScoreDialog {
        id: scoreDialog
    }

    property string selectedStatus: "ALL"
    property string searchQuery:    ""
    property var    mangaData:      []

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

    function incrementChapter(anilistId) {
        let newChapters = 0
        let newStatus   = ""
        for (let i = 0; i < mangaData.length; i++) {
            const item = mangaData[i]
            if (item.anilistId !== anilistId) continue
            if (item.chapters > 0 && item.progress >= item.chapters) return

            item.progress++
            item.updatedAt = Math.floor(Date.now() / 1000)
            newChapters    = item.progress

            if (item.chapters > 0 && item.progress === item.chapters) {
                item.status = "COMPLETED"
                newStatus   = "COMPLETED"
            } else {
                newStatus = "CURRENT"
            }
            break
        }
        mangaData.sort((a, b) => b.updatedAt - a.updatedAt)
        rebuildModel()
        if (newChapters > 0)
            anilistService.saveMangaProgress(anilistId, newChapters, newStatus)
    }

    function incrementVolume(anilistId) {
        let newVolumes = 0
        for (let i = 0; i < mangaData.length; i++) {
            const item = mangaData[i]
            if (item.anilistId !== anilistId) continue
            if (item.volumes > 0 && item.progressVolumes >= item.volumes) return

            item.progressVolumes++
            item.updatedAt = Math.floor(Date.now() / 1000)
            newVolumes     = item.progressVolumes
            break
        }
        mangaData.sort((a, b) => b.updatedAt - a.updatedAt)
        rebuildModel()
        if (newVolumes > 0)
            anilistService.saveMangaVolumeProgress(anilistId, newVolumes)
    }

    // ── Open List Editor dialog ───────────────────────────────────────────────
    function openEditor(anilistId) {
        let entry = null
        for (let i = 0; i < mangaData.length; i++) {
            if (mangaData[i].anilistId === anilistId) { entry = mangaData[i]; break }
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
        listEditor.mangaTitle           = entry.title
        listEditor.currentStatus        = entry.status
        listEditor.currentScore         = entry.score
        listEditor.currentChapters      = entry.progress
        listEditor.currentVolumes       = entry.progressVolumes
        listEditor.currentTotalChapters = entry.chapters
        listEditor.currentTotalVolumes  = entry.volumes
        listEditor.currentStartYear     = parsePart(sd, "y")
        listEditor.currentStartMonth    = parsePart(sd, "m")
        listEditor.currentStartDay      = parsePart(sd, "d")
        listEditor.currentFinishYear    = parsePart(fd, "y")
        listEditor.currentFinishMonth   = parsePart(fd, "m")
        listEditor.currentFinishDay     = parsePart(fd, "d")
        listEditor.currentRereads       = entry.rewatches  || 0
        listEditor.currentNotes         = entry.notes      || ""
        listEditor.currentPriority      = entry.priority   || 0
        listEditor.currentHideFromLists = entry.hiddenFromStatusLists || false
        listEditor.currentPrivate       = entry.isPrivate  || false

        listEditor.open()
    }

    // ── List Editor dialog instance ───────────────────────────────────────────
    MangaListEditorDialog {
        id: listEditor
        onEntrySaved:   anilistService.fetchManga()
        onEntryRemoved: anilistService.fetchManga()
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService
        function onMangaLoaded(data) {
            mangaPage.mangaData = data
            mangaPage.rebuildModel()
        }
        function onMangaEntrySaved() {
            anilistService.fetchManga()
        }
        function onEntrySaved() {
            anilistService.fetchManga()
        }
    }

    Component.onCompleted: {
        if (authManager.isLoggedIn && mangaData.length === 0)
            anilistService.fetchManga()
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
                    model: mangaPage.statusFilters
                    delegate: Controls.ItemDelegate {
                        id: navItem
                        Layout.fillWidth: true
                        highlighted: mangaPage.selectedStatus === modelData.id

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
                                readonly property int count: mangaPage.countForStatus(modelData.id)
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

                        onClicked: mangaPage.selectedStatus = modelData.id
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
                    onClicked: anilistService.fetchManga()
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ── Manga list ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // Search bar
            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth:    true
                Layout.leftMargin:   Kirigami.Units.largeSpacing
                Layout.rightMargin:  Kirigami.Units.largeSpacing
                Layout.topMargin:    Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                placeholderText: "Search manga…"
                onTextChanged: mangaPage.searchQuery = text
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // Content area
            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                // Dimming overlay
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
                    explanation: "Log in to AniList from the Settings page to see your manga list."
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: authManager.isLoggedIn
                             && !anilistService.loading
                             && displayModel.count === 0
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

                        title:         model.title
                        mediaType:     model.mediaType
                        rating:        model.score
                        readChapters:  model.progress
                        totalChapters: model.chapters
                        readVolumes:   model.progressVolumes
                        totalVolumes:  model.volumes
                        coverSource:   model.cover
                        anilistId:     model.anilistId

                        onAddChapter:  mangaPage.incrementChapter(model.anilistId)
                        onAddVolume:   mangaPage.incrementVolume(model.anilistId)
                        onCardClicked: mangaPage.openEditor(model.anilistId)
                        onScoreClicked: {
                            scoreDialog.anilistId    = model.anilistId
                            scoreDialog.currentScore = model.score
                            scoreDialog.open()
                        }
                    }
                }
            }   // Item (content area)
        }       // ColumnLayout (manga list column)
    }
}
