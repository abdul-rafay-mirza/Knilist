import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animePage
    title: "Anime Page"

    // ── Public properties ─────────────────────────────────────────────────────
    property int animeId:            0
    property var animeEntry:         null   // null until onAnimeEntryLoaded fires
    property var animeTitle
    property var animeBannerImage
    property var animeCoverImage
    property var animeDescription
    property var animeRelations:     []
    property int animeTotalEpisodes: 0
    property bool animeIsFavourite:  false
    property var animeCharacters: []
    property var animeRecommendations: []

    property bool _ready: false

    Component.onCompleted: {
        _ready = true
        _loadAnimeData()
    }

    onAnimeIdChanged: {
        if (_ready) _loadAnimeData()
    }

    function _loadAnimeData() {
        if (animeId > 0) {
            anilistService.fetchAnimePage(animeId)
            anilistService.fetchAnimeEntry(animeId)
        }
    }

    // ── List editor ───────────────────────────────────────────────────────────
    AnimeListEditorDialog {
        id: listEditor
        onEntrySaved: {
            anilistService.fetchAnime()
            anilistService.fetchAnimePage(animePage.animeId)
            anilistService.fetchAnimeEntry(animePage.animeId)
        }
        onEntryRemoved: {
            anilistService.fetchAnime()
            anilistService.fetchAnimePage(animePage.animeId)
            anilistService.fetchAnimeEntry(animePage.animeId)
        }
    }

    // ── Open editor with current entry data ───────────────────────────────────
    function openEditor() {
        const e      = animePage.animeEntry
        const onList = e && e.onList

        function parsePart(dateStr, part) {
            if (!dateStr || dateStr.length < 10) return 0
            const p = dateStr.split("-")
            if (part === "y") return parseInt(p[0]) || 0
            if (part === "m") return parseInt(p[1]) || 0
            if (part === "d") return parseInt(p[2]) || 0
            return 0
        }

        const sd = (onList && e.startedAt)   || ""
        const fd = (onList && e.completedAt) || ""

        listEditor.anilistId            = animePage.animeId
        listEditor.animeTitle           = animePage.animeTitle           || ""
        listEditor.currentStatus        = (onList && e.status)           || "PLANNING"
        listEditor.currentScore         = (onList && e.score)            || 0
        listEditor.currentProgress      = (onList && e.progress)         || 0
        listEditor.currentTotalEpisodes = animePage.animeTotalEpisodes
        listEditor.currentStartYear     = parsePart(sd, "y")
        listEditor.currentStartMonth    = parsePart(sd, "m")
        listEditor.currentStartDay      = parsePart(sd, "d")
        listEditor.currentFinishYear    = parsePart(fd, "y")
        listEditor.currentFinishMonth   = parsePart(fd, "m")
        listEditor.currentFinishDay     = parsePart(fd, "d")
        listEditor.currentRewatches     = (onList && e.rewatches)        || 0
        listEditor.currentNotes         = (onList && e.notes)            || ""
        listEditor.currentPriority      = (onList && e.priority)         || 0
        listEditor.currentHideFromLists = (onList && e.hiddenFromStatusLists) || false
        listEditor.currentPrivate       = (onList && e.isPrivate)        || false

        listEditor.open()
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService

        function onAnimePageLoaded(_id, _title, _bannerImage, _coverImage, _description, _relationsJson, _isFavourite, _charactersJson, _recommendationsJson) {
            if (_id !== animePage.animeId) return

            animePage.animeTitle       = _title
            animePage.animeBannerImage = _bannerImage
            animePage.animeCoverImage  = _coverImage
            animePage.animeDescription = _description
            animePage.animeRelations   = JSON.parse(_relationsJson)
            animePage.animeIsFavourite = _isFavourite
            animePage.animeCharacters  = JSON.parse(_charactersJson)
            animePage.animeRecommendations = JSON.parse(_recommendationsJson)

            console.log("depth:", pageStack.layers.depth)
            console.log("ID of anime:", animePage.animeId)
            console.log(JSON.stringify(animePage.animeRecommendations, null, 2))
        }

        function onAnimeEntryLoaded(_id, _entryJson) {
            console.log("onAnimeEntryLoaded fired — _id:", _id, "animePage.animeId:", animePage.animeId)
            if (_id !== animePage.animeId) return
            console.log("entry payload:", _entryJson)
            animePage.animeEntry = JSON.parse(_entryJson)
        }

        // After a save, fetchAnime re-populates the cache; fetchAnimeEntry
        // then re-emits the updated entry so the button label refreshes.
        function onEntrySaved() {
            anilistService.fetchAnime()
        }

        function onAnimeLoaded() {
            // Cache is now fresh — re-emit entry for this page
            anilistService.fetchAnimeEntry(animePage.animeId)
        }

        function onFavouriteToggled(anilistId, newState) {
            if (anilistId === animePage.animeId) {
                animePage.animeIsFavourite = newState
                applicationWindow().showPassiveNotification(
                    newState ? "Added to Favorites" : "Removed from Favorites"
                )
            }
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        Flickable {
            anchors.fill:  parent
            contentWidth:  parent.width
            contentHeight: mainColumn.implicitHeight
            clip:          true

            flickableDirection: Flickable.VerticalFlick
            interactive:        true

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            ColumnLayout {
                id:    mainColumn
                width: parent.width

                Header {
                    Layout.fillWidth: true
                    title:         animePage.animeTitle
                    bannerImage:   animePage.animeBannerImage
                    coverImage:    animePage.animeCoverImage
                    description:   animePage.animeDescription
                    entry:         animePage.animeEntry
                    totalProgress: animePage.animeTotalEpisodes
                    isFavourite:   animePage.animeIsFavourite
                    statusLabels: ({
                        "CURRENT":   "Watching",
                        "COMPLETED": "Completed",
                        "PAUSED":    "Paused",
                        "DROPPED":   "Dropped",
                        "PLANNING":  "Planning",
                        "REPEATING": "Rewatching",
                    })

                    onEditRequested:    animePage.openEditor()
                    onFavouriteToggled: anilistService.toggleFavourite(animePage.animeId, animePage.animeIsFavourite)
                }

                RelationsSection {
                    Layout.fillWidth: true
                    relations: animePage.animeRelations

                    onCardClicked: (mediaId, mediaType) => {
                        if (mediaType === "ANIME") {
                            pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: mediaId })
                        } else if (mediaType === "MANGA") {
                            pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: mediaId })
                        }
                    }
                }

                CharactersSection {
                    Layout.fillWidth: true
                    characters: animePage.animeCharacters 
                    onCharacterClicked: (characterId, name, image, role) => {
                        console.log(name + " Clicked!")
                        pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                            characterId: characterId
                        })
                    }
                }

                RecommendationsSection {
                    Layout.fillWidth: true
                    recommendations:  animePage.animeRecommendations

                    onCardClicked: (mediaId, mediaType) => {
                        pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: mediaId })
                    }
                }

                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: Kirigami.Units.largeSpacing
                }
            }
        }

        // Dimming overlay — shown during any loading operation
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
                running:          true
            }
        }
    }
}
