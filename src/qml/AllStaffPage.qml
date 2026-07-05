import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// This is a page that lists all staff who worked on a given series (can be anime, manga)

Kirigami.Page {
    id: root
    title: "All Staff From " + mediaTitle

    // Push with:
    // pageStack.layers.push(Qt.resolvedUrl("AllStaffPage.qml"), { anilistId: 21, mediaTitle: "One Piece" })
    property int anilistId: 0
    property string mediaTitle: ""

    property bool isInitialLoading: true
    property bool isLoadingMore:    false
    property bool hasNextPage:      true
    property int  currentPage:      1

    Component.onCompleted: reload()

    function reload() {
        isInitialLoading = true
        hasNextPage       = true
        currentPage       = 1
        staffModel.clear()
        anilistService.fetchAllStaffPage(anilistId, 1)
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        isLoadingMore = true
        anilistService.fetchAllStaffPage(anilistId, currentPage + 1)
    }

    // In case the first page(s) don't fill the viewport, keep requesting more
    // until either the page is full or the server says there's nothing left.
    function checkFillViewport() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        if (grid.contentHeight <= grid.height)
            loadMore()
    }

    ListModel {
        id: staffModel
    }

    Connections {
        target: anilistService

        function onAllStaffPageLoaded(payload) {
            const data = JSON.parse(payload)
            if (data.anilistId !== root.anilistId)
                return

            const isFirstPage = data.page <= 1
            if (isFirstPage)
                root.isInitialLoading = false
            else
                root.isLoadingMore = false

            if (data.isError)
                return

            root.currentPage = data.page
            root.hasNextPage = data.hasNextPage
            // Backend keys the identifier as plain "id" for staff (unlike the
            // "characterId"/"mediaId" naming used elsewhere) — remap it to
            // staffId here so the delegate matches StaffCard's property name.
            for (let i = 0; i < data.staff.length; i++) {
                const s = data.staff[i]
                staffModel.append({ staffId: s.id, name: s.name, image: s.image, role: s.role })
            }
            Qt.callLater(checkFillViewport)
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true

        flickableDirection: Flickable.VerticalFlick
        interactive: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
        }

        // StaffCard is a fixed-size horizontal row card (implicitWidth 260,
        // ~100px thumbnail) rather than the poster shape CharacterCard uses,
        // so the grid is sized off StaffCard's own dimensions instead of the
        // numbers used on the characters page.
        readonly property int minCellWidth: 260 + Kirigami.Units.largeSpacing * 2
        readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
        cellWidth:  width / columns
        cellHeight: 100 + Kirigami.Units.largeSpacing * 2

        model: staffModel

        onContentYChanged: {
            if (isLoadingMore || isInitialLoading || !hasNextPage)
                return
            if (contentY + height >= contentHeight - Kirigami.Units.gridUnit * 8)
                loadMore()
        }

        delegate: Item {
            width:  grid.cellWidth
            height: grid.cellHeight

            StaffCard {
                anchors.centerIn: parent
                staffId: model.staffId
                name:    model.name
                image:   model.image
                role:    model.role

                onCardClicked: (id) => {
                    pageStack.layers.push(Qt.resolvedUrl("StaffPage.qml"), { staffId: id })
                }
            }
        }

        footer: ColumnLayout {
            width: grid.width
            height: implicitHeight

            Controls.BusyIndicator {
                Layout.alignment:    Qt.AlignHCenter
                Layout.topMargin:    Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                running: root.isInitialLoading || root.isLoadingMore
                visible: running
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 4
                visible: !root.isInitialLoading && staffModel.count === 0
                text: "No staff found"
            }
        }
    }
}
