import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// This is a page that gives all characters of a given series (can be anime, manga)

Kirigami.Page {
    id: root
    title: "All Characters From " + mediaTitle

    // Push with:
    // pageStack.layers.push(Qt.resolvedUrl("AllCharactersPage.qml"), { anilistId: 21, mediaTitle: "One Piece" })
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
        charactersModel.clear()
        anilistService.fetchAllCharactersPage(anilistId, 1)
    }

    function loadMore() {
        if (isLoadingMore || isInitialLoading || !hasNextPage)
            return
        isLoadingMore = true
        anilistService.fetchAllCharactersPage(anilistId, currentPage + 1)
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
        id: charactersModel
    }

    Connections {
        target: anilistService

        function onAllCharactersPageLoaded(payload) {
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
            for (let i = 0; i < data.characters.length; i++)
                charactersModel.append(data.characters[i])
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

        // GridView has no built-in column count — derive one from a minimum
        // card width, then stretch cellWidth to fill the row exactly.
        readonly property int minCellWidth: 96 + Kirigami.Units.largeSpacing * 2
        readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
        cellWidth:  width / columns
        cellHeight: Kirigami.Units.gridUnit * 9

        model: charactersModel

        onContentYChanged: {
            if (isLoadingMore || isInitialLoading || !hasNextPage)
                return
            if (contentY + height >= contentHeight - Kirigami.Units.gridUnit * 8)
                loadMore()
        }

        delegate: Item {
            width:  grid.cellWidth
            height: grid.cellHeight

            CharacterCard {
                anchors.centerIn: parent
                characterId: model.characterId
                name:        model.name
                image:       model.image
                role:        model.role

                onCharacterClicked: (charId, charName) => {
                    pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), { characterId: charId })
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
                visible: !root.isInitialLoading && charactersModel.count === 0
                text: "No characters found"
            }
        }
    }
}