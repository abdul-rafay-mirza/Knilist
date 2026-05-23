import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animePage
    title: "Anime List"
    padding: 0

    // ── Status filters (AniList enum strings) ─────────────────────────────────
    readonly property var statusFilters: [
        { id: "ALL",       label: "All",       icon: "view-list-symbolic"            },
        { id: "CURRENT",   label: "Watching",  icon: "media-playback-start-symbolic" },
        { id: "COMPLETED", label: "Completed", icon: "emblem-ok-symbolic"            },
        { id: "PAUSED",    label: "Paused",    icon: "media-playback-pause-symbolic" },
        { id: "DROPPED",   label: "Dropped",   icon: "edit-delete-symbolic"          },
        { id: "PLANNING",  label: "Planning",  icon: "appointment-new-symbolic"      },
    ]

    property string selectedStatus: "ALL"

    // ── Master data (set by onAnimeLoaded; stays a mutable JS array) ──────────
    property var animeData: []

    // ── Filtered display model ────────────────────────────────────────────────
    ListModel { id: displayModel }

    function rebuildModel() {
        displayModel.clear()
        for (let i = 0; i < animeData.length; i++) {
            const item = animeData[i]
            if (selectedStatus === "ALL" || item.status === selectedStatus)
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

    // Optimistic local increment; API call persists it in the background.
    function incrementProgress(anilistId) {
        let newProgress = 0
        let newStatus   = ""
        for (let i = 0; i < animeData.length; i++) {
            const item = animeData[i]
            if (item.anilistId !== anilistId) continue
            if (item.episodes > 0 && item.progress >= item.episodes) return

            item.progress++
            newProgress = item.progress

            // Auto-complete when last episode is watched
            if (item.episodes > 0 && item.progress === item.episodes) {
                item.status     = "COMPLETED"
                item.nextEpText = "Finished"
                newStatus       = "COMPLETED"
            } else {
                newStatus = "CURRENT"
            }
            break
        }

        rebuildModel()

        // Persist to AniList (fire-and-forget)
        if (newProgress > 0)
            anilistService.saveProgress(anilistId, newProgress, newStatus)
    }

    // ── Receive live data from Python ─────────────────────────────────────────
    Connections {
        target: anilistService

        function onAnimeLoaded(data) {
            animePage.animeData = data
            animePage.rebuildModel()
        }
    }

    // Trigger fetch if already logged in when page loads
    Component.onCompleted: {
        if (authManager.isLoggedIn && animeData.length === 0)
            anilistService.fetchAll()
    }

    onSelectedStatusChanged: rebuildModel()

    // ═══════════════════════════════════════════════════════════════════════════
    // Layout: sidebar | separator | list
    // ═══════════════════════════════════════════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        spacing:      0

        // ── Sidebar ───────────────────────────────────────────────────────────
        Rectangle {
            id:   sidebar
            Layout.fillHeight:     true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            color: Kirigami.Theme.backgroundColor
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit:  false

            ColumnLayout {
                anchors {
                    fill:        parent
                    topMargin:   Kirigami.Units.smallSpacing
                    bottomMargin: Kirigami.Units.smallSpacing
                }
                spacing: 2

                Repeater {
                    model: animePage.statusFilters

                    delegate: Controls.ItemDelegate {
                        id: navItem
                        Layout.fillWidth: true
                        highlighted: animePage.selectedStatus === modelData.id

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

                            // Count badge
                            Rectangle {
                                readonly property int count: animePage.countForStatus(modelData.id)
                                visible: count > 0
                                width:  Math.max(
                                    Kirigami.Units.gridUnit * 1.4,
                                    badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                                )
                                height: Kirigami.Units.gridUnit * 1.1
                                radius: height / 2
                                color:  navItem.highlighted
                                        ? Qt.rgba(1, 1, 1, 0.25)
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

                        onClicked: animePage.selectedStatus = modelData.id
                    }
                }

                Item { Layout.fillHeight: true }

                // Sync button at the bottom of the sidebar
                Controls.ToolButton {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.smallSpacing
                    Layout.rightMargin:  Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    icon.name: "view-refresh-symbolic"
                    text:      "Sync"
                    visible:   authManager.isLoggedIn
                    enabled:   !anilistService.loading
                    onClicked: anilistService.fetchAll()
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ── Anime list ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // Loading overlay
            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: anilistService.loading && displayModel.count === 0
                visible: running
                z: 1
            }

            // Login prompt
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: !authManager.isLoggedIn && !anilistService.loading
                width:   parent.width - Kirigami.Units.gridUnit * 4
                icon.name: "im-user-symbolic"
                text:      "Not logged in"
                explanation: "Log in to AniList from the Settings page to see your anime list."
            }

            // Empty list (logged in but no results for this filter)
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: authManager.isLoggedIn
                         && !anilistService.loading
                         && displayModel.count === 0
                width:   parent.width - Kirigami.Units.gridUnit * 4
                icon.name: "view-list-symbolic"
                text:      "No anime here yet"
            }

            Controls.ScrollView {
                anchors.fill:  parent
                contentWidth:  availableWidth

                ListView {
                    id:           animeListView
                    model:        displayModel
                    spacing:      Kirigami.Units.largeSpacing
                    topMargin:    Kirigami.Units.largeSpacing
                    bottomMargin: Kirigami.Units.largeSpacing
                    leftMargin:   Kirigami.Units.largeSpacing
                    rightMargin:  Kirigami.Units.largeSpacing

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

                        onAddEpisode: animePage.incrementProgress(model.anilistId)
                    }
                }
            }
        }
    }
}
