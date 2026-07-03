import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.ScrollablePage {
    id: root

    // Push with:
    // pageStack.push(Qt.resolvedUrl("StudioPage.qml"), { studioId: 5, studioName: "Kyoto Animation" })
    property int    studioId:   0
    property string studioName: ""

    // Connect this wherever StudioPage is pushed to navigate to your anime detail page.
    signal mediaSelected(int mediaId)

    title: studioName

    property bool isInitialLoading: true
    property bool isLoadingMore:    false
    property bool hasNextPage:      true
    property int  currentPage:      1

    // mediaId -> true, for every card already placed into yearGroupsModel this
    // session. AniList's Studio.media connection can (and does — see the real
    // Kyoto Animation response) return the same media more than once within a
    // page, and there's no guarantee a duplicate can't straddle a page boundary
    // either, so this has to live for the whole page's lifetime, not just be
    // deduped per-response.
    property var seenMediaIds: ({})

    Component.onCompleted: reload()

    function reload() {
        isInitialLoading = true
        hasNextPage       = true
        currentPage        = 1
        seenMediaIds        = {}
        yearGroupsModel.clear()
        anilistService.fetchStudioPage(studioId, 1)
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        isLoadingMore = true
        anilistService.fetchStudioPage(studioId, currentPage + 1)
    }

    // In case the first page(s) don't fill the viewport, keep requesting more
    // until either the page is full or the server says there's nothing left.
    function checkFillViewport() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        if (groupsListView.contentHeight <= groupsListView.height)
            loadMore()
    }

    // TBA (unknown year) always sorts first; everything else is descending by year,
    // regardless of what order items happen to arrive in from pagination.
    function yearKeyFor(item) {
        return (item.year && item.year > 0) ? String(item.year) : "TBA"
    }

    function groupIndexFor(key) {
        for (let i = 0; i < yearGroupsModel.count; i++) {
            if (yearGroupsModel.get(i).year === key)
                return i
        }
        return -1
    }

    function insertionIndexFor(key) {
        if (key === "TBA")
            return 0
        const yearNum = parseInt(key)
        for (let i = 0; i < yearGroupsModel.count; i++) {
            const rowYear = yearGroupsModel.get(i).year
            if (rowYear === "TBA")
                continue
            if (parseInt(rowYear) < yearNum)
                return i
        }
        return yearGroupsModel.count
    }

     // HorizontalScrollableMediaCoverCards expects a plain JS array (it checks
     // .length for visibility and reads modelData.* per delegate) — model.items
     // is a nested ListModel, which has neither. Materialise a real array.
     function toArray(listModel) {
         let arr = []
         for (let i = 0; i < listModel.count; i++)
             arr.push(listModel.get(i))
         return arr
     }
 

    function mergeMedia(mediaList) {
        for (let i = 0; i < mediaList.length; i++) {
            const item = mediaList[i]

            // Same media can come back more than once (duplicate credit records
            // on AniList's side) — possibly on a different page than the first
            // time we saw it, so this check has to be against the whole
            // session, not just the current batch.
            if (seenMediaIds[item.mediaId])
                continue
            seenMediaIds[item.mediaId] = true

            const key = yearKeyFor(item)
            const idx = groupIndexFor(key)
            
            if (idx === -1) {
                // Brand new year (or TBA) group — insert a new row in sorted position.
                // QML will automatically convert the 'items: [item]' array into a nested ListModel.
                yearGroupsModel.insert(insertionIndexFor(key), { year: key, items: [item] })
            } else {
                // Existing group. Because QML converted the array into a QQmlListModel,
                // we can just call append() directly. The view will automatically update.
                yearGroupsModel.get(idx).items.append(item)
            }
        }
    }

    ListModel {
        id: yearGroupsModel
    }

    Connections {
        target: anilistService

        // Fires for both the initial load (page 1) and every "load more" page —
        // Python always emits this, success or failure, so this is the one place
        // that needs to clear the loading flags.
        function onStudioPageLoaded(payload) {
            const data = JSON.parse(payload)
            if (data.studioId !== root.studioId)
                return

            const isFirstPage = data.page <= 1
            if (isFirstPage)
                root.isInitialLoading = false
            else
                root.isLoadingMore = false

            if (data.isError)
                return

            if (isFirstPage)
                root.studioName = data.name

            root.currentPage = data.page
            root.hasNextPage = data.hasNextPage
            mergeMedia(data.media)
            Qt.callLater(checkFillViewport)
        }
    }

    ListView {
        id: groupsListView
        model:          yearGroupsModel
        spacing:        Kirigami.Units.largeSpacing
        boundsBehavior: Flickable.StopAtBounds

        onContentYChanged: {
            if (isLoadingMore || isInitialLoading || !hasNextPage)
                return
            if (groupsListView.contentY + groupsListView.height
                    >= groupsListView.contentHeight - Kirigami.Units.gridUnit * 8)
                loadMore()
        }

        header: Kirigami.Heading {
            width: groupsListView.width
            topPadding:    Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            leftPadding:   Kirigami.Units.largeSpacing
            rightPadding:  Kirigami.Units.largeSpacing
            level:    1
            text:     root.studioName
            wrapMode: Text.WordWrap
        }

        // One row per year, reusing your existing heading+scroller component
        // instead of hand-rolling another one.
        delegate: HorizontalScrollableMediaCoverCards {
            // Layout.leftMargin/rightMargin on this component only apply when its
            // parent is an actual Layout — a ListView delegate isn't one, so the
            // inset is reproduced here directly instead.
            x:     Kirigami.Units.largeSpacing
            width: groupsListView.width - Kirigami.Units.largeSpacing * 2

            headingText:      model.year
            mediaCardContent: root.toArray(model.items)

            onCardClicked: (mediaId, mediaType) => {
                console.log("MediaCoverCard Clicked!")
                if (mediaType === "ANIME")
                    pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: mediaId })
                else if (mediaType === "MANGA")
                    pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: mediaId })
            }
        }

        footer: ColumnLayout {
            width: groupsListView.width

            Controls.BusyIndicator {
                Layout.alignment:    Qt.AlignHCenter
                Layout.topMargin:    Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                running: root.isLoadingMore || root.isInitialLoading
                visible: running
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 4
                visible: !root.isInitialLoading && yearGroupsModel.count === 0
                text: "No media found for this studio"
            }
        }
    }
}
