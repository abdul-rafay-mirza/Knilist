import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: searchPage
    title: "Search " + searchType

    // Push with:
    // pageStack.layers.push(Qt.resolvedUrl("SearchPage.qml"), { searchType: "Anime" })
    // searchType must be one of HomePage's searchTypes strings — it picks
    // both which anilistService.search() call is made and which detail
    // page a tapped result opens.
    property string searchType: "Anime"

    property bool   isInitialLoading: false
    property bool   isLoadingMore:    false
    property bool   hasNextPage:      false
    property bool   hasSearched:      false
    property bool   lastSearchFailed: false
    property int    currentPage:      1
    property string committedQuery:  ""

    // id -> true, for every result already placed into resultsModel this
    // session — mirrors StudioPage.qml's seenMediaIds, since the same
    // entry could plausibly reappear across pages of one search.
    property var seenResultIds: ({})

    Component.onCompleted: queryField.forceActiveFocus()

    Timer {
        id: debounceTimer
        interval: 400
        repeat: false
        onTriggered: searchPage.runSearch()
    }

    // Same abbreviation AnimeAndMangaSearchCard.qml's _formatCount uses for
    // its favourites row, duplicated here rather than shared because
    // genericDelegate is a sibling of that card, not a child of it.
    function formatFavourites(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(n % 1000000 === 0 ? 0 : 1) + "M"
        if (n >= 1000)    return (n / 1000).toFixed(n % 1000 === 0 ? 0 : 1) + "k"
        return String(n)
    }

    // "TV_SHORT" -> "TV Short", "ONE_SHOT" -> "One Shot", but keeps known
    // acronyms fully upper-cased rather than "Tv"/"Ova".
    function formatLabel(fmt) {
        if (!fmt)
            return ""
        const keepUpper = { "TV": true, "OVA": true, "ONA": true }
        return String(fmt).split("_").map(function (w) {
            return keepUpper[w] ? w : (w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        }).join(" ")
    }

    // Reshapes anilistService.search()'s per-type result shape into the one
    // {id, label, subtitle, image} shape the delegate below renders.
    // Anime and Manga also carry the extra fields AnimeAndMangaSearchCard
    // needs (averageScore, favourites, userStatus, plus mediaType/year
    // already split out rather than pre-joined into subtitle) —
    // label/subtitle/image are kept anyway so the shape stays a superset;
    // nothing about the generic delegate path changes for either type,
    // it's just unused once the delegate below picks AnimeAndMangaSearchCard
    // for this searchType instead.
    // Characters, Staff, and Studios carry a favourites count too (AniList
    // supports favouriting all three), which genericDelegate renders
    // directly. Users has no such field — AniList doesn't let you
    // favourite another user, only anime/manga/characters/staff/studios.
    function normalizeResult(raw) {
        switch (searchPage.searchType) {
        case "Anime":
        case "Manga": {
            const bits = []
            if (raw.format) bits.push(searchPage.formatLabel(raw.format))
            if (raw.year)   bits.push(String(raw.year))
            return {
                id: raw.id, label: raw.title, subtitle: bits.join(" · "), image: raw.coverImage || "",
                mediaType:     searchPage.formatLabel(raw.format),
                year:          raw.year || 0,
                averageScore:  raw.averageScore || 0,
                favourites:    raw.favourites || 0,
                userStatus:    raw.userStatus || "",
            }
        }
        case "Characters":
        case "Staff":
            return { id: raw.id, label: raw.name, subtitle: "", image: raw.image || "", favourites: raw.favourites || 0 }
        case "Studios":
            return { id: raw.id, label: raw.name, subtitle: "Studio", image: "", favourites: raw.favourites || 0 }
        case "Users":
            // AniList doesn't expose a favourites count for User (only
            // Anime/Manga/Character/Staff/Studio can be favourited). -1 is
            // the "not applicable" sentinel genericDelegate's visible check
            // looks for — 0 is reserved for "zero favourites", a real value
            // Characters/Staff/Studios can have.
            return { id: raw.id, label: raw.name, subtitle: "", image: raw.avatar || "", favourites: -1 }
        default:
            return { id: raw.id, label: raw.name || raw.title || "", subtitle: "", image: raw.image || raw.coverImage || raw.avatar || "", favourites: -1 }
        }
    }

    function runSearch() {
        const text = queryField.text
        resultsModel.clear()
        seenResultIds    = ({})
        currentPage      = 1
        hasNextPage      = false
        isLoadingMore    = false
        lastSearchFailed = false

        if (text.length === 0) {
            isInitialLoading = false
            hasSearched      = false
            return
        }

        hasSearched      = true
        isInitialLoading = true
        anilistService.search(searchPage.searchType, text, 1)
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        isLoadingMore = true
        anilistService.search(searchPage.searchType, queryField.text, currentPage + 1)
    }

    // In case the first page doesn't fill the viewport, keep requesting
    // more until either the page is full or the server has nothing left —
    // same idea as StudioPage.qml's checkFillViewport.
    function checkFillViewport() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        if (resultsListView.contentHeight <= resultsListView.height)
            loadMore()
    }

    function openResult(id, label) {
        switch (searchPage.searchType) {
        case "Anime":
            pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: id })
            break
        case "Manga":
            pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: id })
            break
        case "Characters":
            pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), { characterId: id })
            break
        case "Staff":
            pageStack.layers.push(Qt.resolvedUrl("StaffPage.qml"), { staffId: id })
            break
        case "Studios":
            pageStack.layers.push(Qt.resolvedUrl("StudioPage.qml"), { studioId: id, studioName: label })
            break
        case "Users":
            pageStack.layers.push(Qt.resolvedUrl("UsersPage.qml"), { userId: id, userName: label })
            break
        }
    }

    ListModel {
        id: resultsModel
    }

    Connections {
        target: anilistService

        // Fires for both the initial search and every "load more" page —
        // Python always emits this, success or failure, so this is the one
        // place that needs to clear the loading flags.
        function onSearchResultsLoaded(payloadJson) {
            const data = JSON.parse(payloadJson)
            if (data.searchType !== searchPage.searchType)
                return   // some other SearchPage instance's response

            const isFirstPage = data.page <= 1
            if (isFirstPage)
                searchPage.isInitialLoading = false
            else
                searchPage.isLoadingMore = false

            searchPage.committedQuery   = data.query
            searchPage.lastSearchFailed = data.isError

            if (data.isError)
                return

            searchPage.currentPage = data.page
            searchPage.hasNextPage = data.hasNextPage

            for (let i = 0; i < data.results.length; i++) {
                const raw = data.results[i]
                if (searchPage.seenResultIds[raw.id])
                    continue
                searchPage.seenResultIds[raw.id] = true
                resultsModel.append(searchPage.normalizeResult(raw))
            }

            Qt.callLater(searchPage.checkFillViewport)
        }
    }

    header: Controls.ToolBar {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.alignment: Qt.AlignVCenter
                width: Kirigami.Units.iconSizes.smallMedium
                height: width
                source: "search"
                opacity: 0.6
            }

            Controls.TextField {
                id: queryField
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                placeholderText: "Search " + searchPage.searchType.toLowerCase() + "…"
                onTextChanged: debounceTimer.restart()
                onAccepted: {
                    debounceTimer.stop()
                    searchPage.runSearch()
                }
            }

            Controls.ToolButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Kirigami.Units.smallSpacing
                icon.name: "edit-clear"
                visible: queryField.text.length > 0
                onClicked: {
                    debounceTimer.stop()
                    queryField.clear()
                    searchPage.runSearch()
                }
            }
        }
    }

    ListView {
        id: resultsListView
        anchors.fill: parent
        clip: true

        flickableDirection: Flickable.VerticalFlick
        interactive: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
        }

        model: resultsModel
        spacing: 0

        onContentYChanged: {
            if (isLoadingMore || isInitialLoading || !hasNextPage)
                return
            if (resultsListView.contentY + resultsListView.height
                    >= resultsListView.contentHeight - Kirigami.Units.gridUnit * 8)
                searchPage.loadMore()
        }

        // AnimeAndMangaSearchCard has its own variable implicitHeight (the
        // status badge row collapses to nothing when userStatus is empty),
        // which doesn't fit a single delegate Component with the generic
        // delegate's fixed height — so the Anime and Manga tabs get routed
        // to the same Component via a Loader, and every other search type
        // keeps using the exact same ItemDelegate as before, untouched.
        delegate: Loader {
            width: resultsListView.width
            sourceComponent: (searchPage.searchType === "Anime" || searchPage.searchType === "Manga")
                              ? mediaCardDelegate : genericDelegate

            // Re-exposed so each Component below can read this delegate's
            // own model row via modelData/model the normal Loader way.
            property var modelData: model
        }

        Component {
            id: mediaCardDelegate

            AnimeAndMangaSearchCard {
                width: resultsListView.width
                title:         modelData.label
                mediaType:     modelData.mediaType || ""
                year:          modelData.year || 0
                averageScore:  modelData.averageScore || 0
                favourites:    modelData.favourites || 0
                coverSource:   modelData.image || ""
                anilistId:     modelData.id
                userStatus:    modelData.userStatus || ""
                isManga:       searchPage.searchType === "Manga"

                onCardClicked:  searchPage.openResult(modelData.id, modelData.label)
                onImageClicked: searchPage.openResult(modelData.id, modelData.label)
            }
        }

        Component {
            id: genericDelegate

            Controls.ItemDelegate {
                width: resultsListView.width
                // Same sizing rule AnimeAndMangaSearchCard.qml uses on
                // itself (Math.max(150, mainLayout.implicitHeight + 10)) —
                // duplicated here against this delegate's own contentItem
                // rather than bound to the card, so this stays correct even
                // if the card's internals change later.
                height: Math.max(150, rowContent.implicitHeight + 10)
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing

                onClicked: searchPage.openResult(modelData.id, modelData.label)

                contentItem: RowLayout {
                    id: rowContent
                    spacing: Kirigami.Units.largeSpacing

                    Item {
                        Layout.preferredWidth: 90
                        Layout.fillHeight: true

                        // True once whichever image element is active for
                        // this delegate's searchType has finished loading.
                        // Deliberately not a reference to "the active
                        // element" typed as Item — Item itself has no
                        // .status property (only its Image/AnimatedImage
                        // subtypes do), so a generically-typed property
                        // would fail QML's static property lookup. A plain
                        // bool sidesteps that.
                        readonly property bool thumbReady: searchPage.searchType === "Users"
                                                             ? animatedThumbImage.status === Image.Ready
                                                             : thumbImage.status === Image.Ready

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                           Kirigami.Theme.textColor.b, 0.08)
                            visible: !parent.thumbReady

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: parent.width * 0.5
                                height: width
                                source: "search"
                                opacity: 0.5
                            }
                        }

                        // Static path — Characters, Staff, Studios. AniList
                        // images for these are never animated, so a plain
                        // Image avoids AnimatedImage's per-frame decode/cache
                        // cost for types that could never use it.
                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            source: searchPage.searchType !== "Users" ? (modelData.image || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            visible: searchPage.searchType !== "Users" && status === Image.Ready
                        }

                        AnimatedImage {
                            id: animatedThumbImage
                            anchors.fill: parent
                            source: searchPage.searchType === "Users" ? (modelData.image || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            visible: searchPage.searchType === "Users" && status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            visible: modelData.subtitle.length > 0
                            elide: Text.ElideRight
                            opacity: 0.6
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
                        }

                        // Only Characters, Staff, and Studios carry a real
                        // favourites count (see normalizeResult) — Users
                        // has no such field on AniList, so it's normalized
                        // to the -1 "not applicable" sentinel and this row
                        // stays hidden.
                        RowLayout {
                            spacing: 4
                            visible: modelData.favourites >= 0

                            Kirigami.Icon {
                                source: "love"
                                width:  15
                                height: 15
                                color:  "#e05562"
                            }
                            Controls.Label {
                                text: searchPage.formatFavourites(modelData.favourites)
                                color: Kirigami.Theme.textColor
                                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
                            }
                        }
                    }
                }
            }
        }

        footer: ColumnLayout {
            width: resultsListView.width
            spacing: 0

            Controls.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.gridUnit * 4
                running: searchPage.isInitialLoading || searchPage.isLoadingMore
                visible: running
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                type: Kirigami.MessageType.Error
                visible: searchPage.lastSearchFailed && !searchPage.isInitialLoading
                         && resultsModel.count === 0
                text: "Something went wrong. Please try again."
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 4
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                icon.name: "search"
                visible: !searchPage.isInitialLoading && !searchPage.lastSearchFailed
                         && resultsModel.count === 0 && !searchPage.hasSearched
                text: "Search for " + searchPage.searchType.toLowerCase()
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 4
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                icon.name: "search"
                visible: !searchPage.isInitialLoading && !searchPage.lastSearchFailed
                         && resultsModel.count === 0 && searchPage.hasSearched
                text: "No results for \u201c" + searchPage.committedQuery + "\u201d"
            }
        }
    }
}
