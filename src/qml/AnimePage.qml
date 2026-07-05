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
    property var animeEntry:         null
    property var animeTitle
    property var animeBannerImage
    property var animeCoverImage
    property var animeDescription
    property var animeRelations:     []
    property int animeTotalEpisodes: 0
    property bool animeIsFavourite:  false
    property var animeCharacters:    []
    property var animeRecommendations: []
    property var animeStaff:         []
    property var animeInformation:   ({})

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

    // ── Open editor ───────────────────────────────────────────────────────────
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

        function onAnimePageLoaded(_id, _title, _bannerImage, _coverImage, _description,
                                   _relationsJson, _isFavourite, _charactersJson,
                                   _recommendationsJson, _staffJson, _informationJson) {
            if (_id !== animePage.animeId) return

            animePage.animeTitle          = _title
            animePage.animeBannerImage    = _bannerImage
            animePage.animeCoverImage     = _coverImage
            animePage.animeDescription    = _description
            animePage.animeRelations      = JSON.parse(_relationsJson)
            animePage.animeIsFavourite    = _isFavourite
            animePage.animeCharacters     = JSON.parse(_charactersJson)
            animePage.animeRecommendations = JSON.parse(_recommendationsJson)
            animePage.animeStaff          = JSON.parse(_staffJson)
            animePage.animeInformation    = JSON.parse(_informationJson)

            // console.log(JSON.stringify(animePage.animeInformation, null, 2))
        }

        function onAnimeEntryLoaded(_id, _entryJson) {
            if (_id !== animePage.animeId) return
            animePage.animeEntry = JSON.parse(_entryJson)
        }

        function onAnimeEntrySaved() {
            anilistService.fetchAnime()
        }

        function onAnimeLoaded() {
            anilistService.fetchAnimeEntry(animePage.animeId)
        }

        function onAnimeFavouriteToggled(anilistId, newState) {
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
                id:      mainColumn
                width:   parent.width
                spacing: 0

                // ── Full-width header ─────────────────────────────────────────
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
                    onFavouriteToggled: anilistService.toggleAnimeFavourite(animePage.animeId, animePage.animeIsFavourite)
                }

                // ── Two-column body ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          0

                    // Left: information sidebar
                    ColumnLayout {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        Layout.alignment:      Qt.AlignTop
                        spacing:               Kirigami.Units.largeSpacing

                        AnimeInformationSection {
                            Layout.fillWidth: true
                            information:      animePage.animeInformation
                        }

                        TagsSection {
                            Layout.fillWidth: true
                            tags:             animePage.animeInformation.tags
                        }

                        ExternalLinksSection {
                            Layout.fillWidth: true
                            links: animePage.animeInformation.externalLinks
                        }
                    }

                    // Right: relations, characters, staff
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing:          0

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
                                pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                                    characterId: characterId
                                })
                            }
                            onCharacterHeadingClicked: {
                                console.log("Character Heading Clicked!")
                            }
                        }

                        StaffSection {
                            Layout.fillWidth: true
                            staff: animePage.animeStaff
                            onCardClicked: (id) => {
                                console.log("Clicked StaffCard", id)
                                pageStack.layers.push(Qt.resolvedUrl("StaffPage.qml"), {
                                    staffId: id
                                })
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }

                // ── Full-width recommendations section ────────────────────────────────
                HorizontalScrollableMediaCoverCards {
                    Layout.fillWidth: true
                    mediaCardContent:  animePage.animeRecommendations
                    headingText: "Recommendations"
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
                running:          true
            }
        }
    }
}
