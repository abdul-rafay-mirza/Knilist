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
    // {id, label, subtitle, image} shape the delegate below renders — except
    // Anime, which now also carries the extra fields AnimeSearchCard needs
    // (averageScore, favourites, userStatus, plus mediaType/year already
    // split out rather than pre-joined into subtitle). label/subtitle/image
    // are kept anyway so the shape stays a superset; nothing about the
    // generic delegate path changes for Anime, it's just unused once the
    // delegate below picks AnimeSearchCard for this searchType instead.
    function normalizeResult(raw) {
        switch (searchPage.searchType) {
        case "Anime": {
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
        case "Manga": {
            const bits = []
            if (raw.format) bits.push(searchPage.formatLabel(raw.format))
            if (raw.year)   bits.push(String(raw.year))
            return { id: raw.id, label: raw.title, subtitle: bits.join(" · "), image: raw.coverImage || "" }
        }
        case "Characters":
        case "Staff":
            return { id: raw.id, label: raw.name, subtitle: "", image: raw.image || "" }
        case "Studios":
            return { id: raw.id, label: raw.name, subtitle: "Studio", image: "" }
        case "Users":
            return { id: raw.id, label: raw.name, subtitle: "", image: raw.avatar || "" }
        default:
            return { id: raw.id, label: raw.name || raw.title || "", subtitle: "", image: raw.image || raw.coverImage || raw.avatar || "" }
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

        // AnimeSearchCard has its own variable implicitHeight (the status
        // badge row collapses to nothing when userStatus is empty), which
        // doesn't fit a single delegate Component with the generic
        // delegate's fixed height — so the Anime tab gets routed to its own
        // Component via a Loader, and every other search type keeps using
        // the exact same ItemDelegate as before, untouched.
        delegate: Loader {
            width: resultsListView.width
            sourceComponent: searchPage.searchType === "Anime" ? animeCardDelegate : genericDelegate

            // Re-exposed so each Component below can read this delegate's
            // own model row via modelData/model the normal Loader way.
            property var modelData: model
        }

        Component {
            id: animeCardDelegate

            AnimeSearchCard {
                width: resultsListView.width
                title:         modelData.label
                mediaType:     modelData.mediaType || ""
                year:          modelData.year || 0
                averageScore:  modelData.averageScore || 0
                favourites:    modelData.favourites || 0
                coverSource:   modelData.image || ""
                anilistId:     modelData.id
                userStatus:    modelData.userStatus || ""

                onCardClicked:  searchPage.openResult(modelData.id, modelData.label)
                onImageClicked: searchPage.openResult(modelData.id, modelData.label)
            }
        }

        Component {
            id: genericDelegate

            Controls.ItemDelegate {
                width: resultsListView.width
                height: Kirigami.Units.gridUnit * 3.5
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing

                onClicked: searchPage.openResult(modelData.id, modelData.label)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                           Kirigami.Theme.textColor.b, 0.08)
                            visible: thumbImage.status !== Image.Ready

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: parent.width * 0.5
                                height: width
                                source: "search"
                                opacity: 0.5
                            }
                        }

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            source: modelData.image || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            visible: status === Image.Ready
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
