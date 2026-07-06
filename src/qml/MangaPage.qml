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
    property var mangaTitle
    property var mangaBannerImage
    property var mangaCoverImage
    property var mangaDescription
    property bool mangaIsFavourite: false

    property bool _ready: false

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
        }
    }

    // ── Live data ─────────────────────────────────────────────────────────────
    Connections {
        target: anilistService

        // mangaPageLoaded emits 11 fields total; only the ones Header needs
        // are picked up here — relations/characters/recommendations/staff/
        // information get added to the signature once those sections exist.
        function onMangaPageLoaded(_id, _title, _bannerImage, _coverImage,
                                   _description, _relationsJson, _isFavourite) {
            if (_id !== mangaPage.anilistId) return

            mangaPage.mangaTitle       = _title
            mangaPage.mangaBannerImage = _bannerImage
            mangaPage.mangaCoverImage  = _coverImage
            mangaPage.mangaDescription = _description
            mangaPage.mangaIsFavourite = _isFavourite
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
                    totalProgress: 0
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
                        // TODO: no manga list editor dialog yet — mirror AnimeListEditorDialog
                        console.log("[MangaPage] edit requested — editor dialog not implemented")
                    }
                    onFavouriteToggled: {
                        // TODO: backend has no toggleMangaFavourite slot yet (only anime/character/staff/studio)
                        console.log("[MangaPage] favourite toggle requested — backend slot not implemented")
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