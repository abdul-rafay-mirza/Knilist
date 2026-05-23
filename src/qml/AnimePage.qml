import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animePage
    title: "Anime List"
    padding: 0

    // AniList-compatible status filters
    // id matches the AniList MediaListStatus enum exactly.
    readonly property var statusFilters: [
        { id: "ALL",       label: "All",       icon: "view-list-symbolic"           },
        { id: "CURRENT",   label: "Watching",  icon: "media-playback-start-symbolic"},
        { id: "COMPLETED", label: "Completed", icon: "emblem-ok-symbolic"           },
        { id: "PAUSED",    label: "Paused",    icon: "media-playback-pause-symbolic"},
        { id: "DROPPED",   label: "Dropped",   icon: "edit-delete-symbolic"         },
        { id: "PLANNING",  label: "Planning",  icon: "appointment-new-symbolic"     },
    ]

    property string selectedStatus: "ALL"

    // Master data store.
    // Shape mirrors what the AniList API returns after
    // normalisation in your future anilistService.js:
    //   anilistId   → media.id
    //   title       → media.title.userPreferred
    //   mediaType   → media.format  ("TV", "MOVIE", …)
    //   status      → MediaListStatus enum string
    //   score       → score  (0–100 or 0–10 depending on user setting)
    //   progress    → progress
    //   episodes    → media.episodes  (null = airing/unknown)
    //   nextAiringEp→ media.nextAiringEpisode (object or null)
    //   cover       → media.coverImage.large
    property var animeData: [
        {
            anilistId:    180745,
            title:        "Classroom of the Elite 4th Season: Second Year, First Semester",
            mediaType:    "TV",
            status:       "CURRENT",
            score:        0,
            progress:     11,
            episodes:     16,
            nextAiringEp: { episode: 12, timeUntilAiring: 432000 },   // seconds
            cover:        "https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/bx180745-OEZaBeEdWozn.png"
        },
        {
            anilistId:    154587,
            title:        "Frieren: Beyond Journey's End",
            mediaType:    "TV",
            status:       "COMPLETED",
            score:        9,
            progress:     28,
            episodes:     28,
            nextAiringEp: null,
            cover:        "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg"
        },
        {
            anilistId:    176496,
            title:        "Solo Leveling Season 2 -Arise from the Shadow-",
            mediaType:    "TV",
            status:       "CURRENT",
            score:        7,
            progress:     7,
            episodes:     13,
            nextAiringEp: { episode: 8, timeUntilAiring: 259200 },
            cover:        "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx176496-9BDMjAZGEbq4.png"
        },
        {
            anilistId:    101922,
            title:        "Mob Psycho 100 III",
            mediaType:    "TV",
            status:       "COMPLETED",
            score:        10,
            progress:     13,
            episodes:     13,
            nextAiringEp: null,
            cover:        "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx110277-qBFPLlKBaGgB.jpg"
        },
        {
            anilistId:    113415,
            title:        "Dragon Ball Super: Broly",
            mediaType:    "MOVIE",
            status:       "PLANNING",
            score:        0,
            progress:     0,
            episodes:     1,
            nextAiringEp: null,
            cover:        "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx107731-NHjkz0BNFtSr.jpg"
        }
    ]

    // Filtered display model – rebuilt on status change.
    // Call rebuildModel() after replacing animeData
    // with live AniList results.
    ListModel { id: displayModel }

    function rebuildModel() {
        displayModel.clear()
        for (let i = 0; i < animeData.length; i++) {
            const item = animeData[i]
            if (selectedStatus === "ALL" || item.status === selectedStatus) {
                displayModel.append(item)
            }
        }
    }

    // Count helper used by sidebar badges
    function countForStatus(statusId) {
        if (statusId === "ALL") return animeData.length
        let n = 0
        for (let i = 0; i < animeData.length; i++)
            if (animeData[i].status === statusId) n++
        return n
    }

    // Converts nextAiringEp object → human-readable string
    function nextEpText(entry) {
        if (entry.status === "COMPLETED") return "Finished"
        if (!entry.nextAiringEp)         return "TBA"
        const days  = Math.floor(entry.nextAiringEp.timeUntilAiring / 86400)
        const hours = Math.floor((entry.nextAiringEp.timeUntilAiring % 86400) / 3600)
        const ep    = entry.nextAiringEp.episode
        if (days > 0)  return `Ep. ${ep} in ${days}d`
        if (hours > 0) return `Ep. ${ep} in ${hours}h`
        return `Ep. ${ep} airing soon`
    }

    // Mutates the local JS array and refreshes the model.
    // Replace this body with a PATCH to the AniList API
    // (SaveMediaListEntry mutation) when you add networking.
    function incrementProgress(anilistId) {
        for (let i = 0; i < animeData.length; i++) {
            if (animeData[i].anilistId === anilistId) {
                if (animeData[i].progress >= animeData[i].episodes) return
                animeData[i].progress++
                // Auto-complete when last episode is watched
                if (animeData[i].progress === animeData[i].episodes)
                    animeData[i].status = "COMPLETED"
                break
            }
        }
        rebuildModel()
    }

    Component.onCompleted: rebuildModel()
    onSelectedStatusChanged: rebuildModel()

    // Layout: sidebar | separator | scrollable list
    RowLayout {
        anchors.fill: parent
        spacing:      0

        // Sidebar
        Rectangle {
            id: sidebar
            Layout.fillHeight:    true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            color: Kirigami.Theme.backgroundColor

            Kirigami.Theme.colorSet:   Kirigami.Theme.View
            Kirigami.Theme.inherit:    false

            ColumnLayout {
                anchors {
                    fill: parent
                    topMargin:    Kirigami.Units.smallSpacing
                    bottomMargin: Kirigami.Units.smallSpacing
                }
                spacing: 2

                Repeater {
                    model: animePage.statusFilters

                    delegate: Controls.ItemDelegate {
                        id: navItem
                        Layout.fillWidth: true

                        // Highlight the active filter
                        highlighted: animePage.selectedStatus === modelData.id

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: modelData.icon
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
                                font.weight: navItem.highlighted
                                             ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            // Count badge
                            Rectangle {
                                readonly property int count: animePage.countForStatus(modelData.id)
                                visible: count > 0
                                width:  Math.max(Kirigami.Units.gridUnit * 1.4,
                                                 badgeLabel.implicitWidth
                                                 + Kirigami.Units.smallSpacing * 2)
                                height: Kirigami.Units.gridUnit * 1.1
                                radius: height / 2
                                color:  navItem.highlighted
                                        ? Qt.rgba(1, 1, 1, 0.25)
                                        : Kirigami.Theme.highlightColor

                                Controls.Label {
                                    id: badgeLabel
                                    anchors.centerIn: parent
                                    text:  parent.count
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: navItem.highlighted
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Kirigami.Theme.highlightedTextColor
                                }
                            }
                        }

                        background: Rectangle {
                            color: navItem.highlighted
                                   ? Kirigami.Theme.highlightColor
                                   : navItem.hovered
                                     ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                               Kirigami.Theme.highlightColor.g,
                                               Kirigami.Theme.highlightColor.b, 0.15)
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

                // Push everything to the top
                Item { Layout.fillHeight: true }

                // ── Future: AniList sync button ───────────
                Controls.ToolButton {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    icon.name: "view-refresh-symbolic"
                    text: "Sync AniList"
                    // onClicked: anilistService.fetchList(userId)
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // Anime list
        Controls.ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth: availableWidth          // prevents horizontal scroll

            ListView {
                id: animeListView
                model:        displayModel
                spacing:      Kirigami.Units.largeSpacing
                topMargin:    Kirigami.Units.largeSpacing
                bottomMargin: Kirigami.Units.largeSpacing
                leftMargin:   Kirigami.Units.largeSpacing
                rightMargin:  Kirigami.Units.largeSpacing

                // Empty-state placeholder
                Controls.Label {
                    anchors.centerIn: parent
                    visible: displayModel.count === 0
                    text:    "No anime in this list yet."
                    opacity: 0.5
                }

                delegate: AnimeCard {
                    // Subtract list margins so cards don't clip
                    width: ListView.view.width
                           - animeListView.leftMargin
                           - animeListView.rightMargin

                    title:           model.title
                    mediaType:       model.mediaType
                    nextEpisodeText: animePage.nextEpText(model)
                    rating:          model.score
                    watchedEpisodes: model.progress
                    totalEpisodes:   model.episodes

                    // Cover source unchanged – will work with AniList CDN URLs
                    coverSource: model.cover

                    onAddEpisode: animePage.incrementProgress(model.anilistId)
                }
            }
        }
    }
}
