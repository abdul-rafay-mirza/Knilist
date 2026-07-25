import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: mangaPage
    title: "Manga Page"

    // ── Public properties ─────────────────────────────────────────────────────
    property int anilistId:         0
    property var mangaEntry:        null
    property var mangaTitle: ""
    property var mangaBannerImage
    property var mangaCoverImage
    property var mangaDescription
    property var mangaRelations:     []
    property int mangaTotalChapters: 0
    property int mangaTotalVolumes: 0
    property bool mangaIsFavourite: false
    property var mangaCharacters:    []
    property var mangaRecommendations: []
    property var mangaStaff:         []
    property var mangaInformation:   ({})
    property var informationSidebarMaxWidth: 250

    property bool _ready: false

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: mangaPage._loadMangaData()
        }
    ]

    Component.onCompleted: {
        _ready = true
        _loadMangaData()
    }

    onAnilistIdChanged: {
        if (_ready) _loadMangaData()
    }

    function _loadMangaData() {
        if (anilistId > 0) {
            anilistService.fetchMangaPage(anilistId)
            anilistService.fetchMangaEntry(anilistId)
        }
    }

    // ── List editor ───────────────────────────────────────────────────────────
    MangaListEditorDialog {
        id: listEditor
        onEntrySaved: {
            anilistService.fetchManga()
            anilistService.fetchMangaPage(mangaPage.anilistId)
            anilistService.fetchMangaEntry(mangaPage.anilistId)
        }
        onEntryRemoved: {
            anilistService.fetchManga()
            anilistService.fetchMangaPage(mangaPage.anilistId)
            anilistService.fetchMangaEntry(mangaPage.anilistId)
        }
    }

    function openEditor(anilistId) {
        const e = mangaPage.mangaEntry
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

        listEditor.anilistId            = mangaPage.anilistId
        listEditor.mangaTitle           = mangaPage.mangaTitle || ""
        listEditor.currentStatus        = (onList && e.status) || "PLANNING"
        listEditor.currentScore         = (onList && e.score) || 0
        listEditor.currentChapters      = (onList && e.progress) || 0
        listEditor.currentVolumes       = (onList && e.progressVolumes) || 0
        listEditor.currentTotalChapters = mangaPage.mangaTotalChapters
        listEditor.currentTotalVolumes  = mangaPage.mangaTotalVolumes
        listEditor.currentStartYear     = parsePart(sd, "y")
        listEditor.currentStartMonth    = parsePart(sd, "m")
        listEditor.currentStartDay      = parsePart(sd, "d")
        listEditor.currentFinishYear    = parsePart(fd, "y")
        listEditor.currentFinishMonth   = parsePart(fd, "m")
        listEditor.currentFinishDay     = parsePart(fd, "d")
        listEditor.currentRereads       = (onList && e.rewatches) || 0
        listEditor.currentNotes         = (onList && e.notes)            || ""
        listEditor.currentPriority      = (onList && e.priority)         || 0
        listEditor.currentHideFromLists = (onList && e.hiddenFromStatusLists) || false
        listEditor.currentPrivate       = (onList && e.isPrivate)        || false

        listEditor.open()
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService

        // mangaPageLoaded emits 11 fields total; only the ones Header needs
        // are picked up here — relations/characters/recommendations/staff/
        // information get added to the signature once those sections exist.
        function onMangaPageLoaded(_id, _title, _bannerImage, _coverImage, _description, _relationsJson, _isFavourite, _charactersJson, _recommendationsJson, _staffJson, _informationJson) {
            if (_id !== mangaPage.anilistId) return

            mangaPage.mangaTitle       = _title
            mangaPage.mangaBannerImage = _bannerImage
            mangaPage.mangaCoverImage  = _coverImage
            mangaPage.mangaDescription = _description
            mangaPage.mangaRelations   = JSON.parse(_relationsJson)
            mangaPage.mangaIsFavourite = _isFavourite
            mangaPage.mangaCharacters = JSON.parse(_charactersJson)
            mangaPage.mangaRecommendations = JSON.parse(_recommendationsJson)
            mangaPage.mangaStaff = JSON.parse(_staffJson)
            mangaPage.mangaInformation = JSON.parse(_informationJson)
        }

        function onMangaEntryLoaded(_id, _entryJson) {
            if (_id !== mangaPage.anilistId) return
            mangaPage.mangaEntry = JSON.parse(_entryJson)
            console.log("Manga Status: " + mangaPage.mangaEntry.status)
        }

        function onMangaEntrySaved() {
            anilistService.fetchManga()
        }

        function onMangaLoaded() {
            anilistService.fetchMangaEntry(mangaPage.anilistId)
        }

        function onMangaFavouriteToggled(anilistId, newState) {
            if (anilistId === mangaPage.anilistId) {
                mangaPage.mangaIsFavourite = newState
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
                    title:         mangaPage.mangaTitle
                    bannerImage:   mangaPage.mangaBannerImage
                    coverImage:    mangaPage.mangaCoverImage
                    description:   mangaPage.mangaDescription
                    entry:         mangaPage.mangaEntry
                    totalProgress: mangaPage.mangaTotalChapters
                    isFavourite:   mangaPage.mangaIsFavourite
                    statusLabels: ({
                        "CURRENT":   "Reading",
                        "COMPLETED": "Completed",
                        "PAUSED":    "Paused",
                        "DROPPED":   "Dropped",
                        "PLANNING":  "Planning",
                        "REPEATING": "Rereading",
                    })
                    onEditRequested: {
                        mangaPage.openEditor()
                    }
                    onFavouriteToggled: {
                        anilistService.toggleMangaFavourite(mangaPage.anilistId, mangaPage.mangaIsFavourite)
                    }
                }

                // ── Two-column body ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Left: information sidebar
                    ColumnLayout {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        Layout.alignment: Qt.AlignTop
                        spacing: Kirigami.Units.largeSpacing

                        InformationSection {
                            Layout.fillWidth: true
                            information:      mangaPage.mangaInformation
                            mediaType:        "MANGA"
                            Layout.maximumWidth: mangaPage.informationSidebarMaxWidth
                        }

                        TagsSection {
                            Layout.fillWidth: true
                            tags: mangaPage.mangaInformation.tags
                            Layout.maximumWidth: mangaPage.informationSidebarMaxWidth
                        }

                        ExternalLinksSection {
                            Layout.fillWidth: true
                            links: mangaPage.mangaInformation.externalLinks
                            Layout.maximumWidth: mangaPage.informationSidebarMaxWidth
                        }
                    }

                    // Right: relations, characters, staff
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RelationsSection {
                            Layout.fillWidth: true
                            relations: mangaPage.mangaRelations
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
                            characters: mangaPage.mangaCharacters
                            onCharacterClicked: (characterId, name, image, role) => {
                                pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                                    characterId: characterId
                                })
                            }
                            onCharacterHeadingClicked: {
                                console.log("Character Heading Clicked!")
                                pageStack.layers.push(Qt.resolvedUrl("AllCharactersPage.qml"), {
                                    anilistId: mangaPage.anilistId,
                                    mediaTitle: mangaPage.mangaTitle
                                })
                            }
                        }

                        StaffSection {
                            Layout.fillWidth: true
                            staff: mangaPage.mangaStaff
                            onCardClicked: (id) => {
                                console.log("Clicked StaffCard", id)
                                pageStack.layers.push(Qt.resolvedUrl("StaffPage.qml"), {
                                    staffId: id
                                })
                            }
                            onStaffHeadingClicked: {
                                console.log("Staff Heading Clicked!")
                                pageStack.layers.push(Qt.resolvedUrl("AllStaffPage.qml"), {
                                    anilistId: mangaPage.anilistId,
                                    mediaTitle: mangaPage.mangaTitle
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
                    mediaCardContent:  mangaPage.mangaRecommendations
                    headingText: "Recommendations"
                    onCardClicked: (mediaId, mediaType) => {
                        pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: mediaId })
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