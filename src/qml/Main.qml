import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    width: 800
    height: 600
    title: "Knilist"

    // Exposed so child pages (e.g. ProfilePage's StatBar) can reach it — QML
    // ids are only visible within the file that declares them and that
    // file's own children, so without this alias appPagePool is invisible
    // to anything pushed onto pageStack.
    property alias appPagePool: appPagePool

    Kirigami.PagePool {
        id: appPagePool
    }

    // Switches the main pageStack to a fresh instance of the page at `url`,
    // replicating exactly what Kirigami.PagePoolAction does internally for
    // the actions below (basePage unset, useLayers false):
    //   stack.clear(); stack.push(pagePool.loadPage(url))
    // — verified against KDE/kirigami's PagePoolAction.qml (master), not
    // pageStack.replace(). Doing it this exact way also keeps the
    // GlobalDrawer's own checked/highlighted state correct, since that's
    // driven by pageStack's onCurrentItemChanged signal, not by which code
    // triggered the change.
    function switchToPage(url) {
        const resolved = Qt.resolvedUrl(url)
        const target = appPagePool.pageForUrl(resolved)
        if (target !== null && pageStack.currentItem === target) {
            return
        }
        pageStack.clear()
        pageStack.push(appPagePool.loadPage(resolved))
    }

    // Use Component.onCompleted to push after the window is fully ready
    // and use loadPage() not load()
    Component.onCompleted: {
        pageStack.push(appPagePool.loadPage(Qt.resolvedUrl("HomePage.qml")))
    }

    Connections {
        target: pageStack.layers
        function onDepthChanged() {
            if (pageStack.layers.depth > 1) {
                globalDrawer.drawerOpen = false
            } else {
                globalDrawer.drawerOpen = true
            }
        }
    }

    Connections {
        target: anilistService
        function onErrorOccurred(message) {
            applicationWindow().showPassiveNotification(message)
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: globalDrawer
        handleVisible: false
        modal: false
        collapsible: true
        collapsed: false
        collapseButtonVisible: false
        showHeaderWhenCollapsed: true

        header: Controls.ToolBar {
            contentItem: RowLayout {
                Layout.fillWidth: true

                Controls.ToolButton {
                    icon.name: "application-menu"
                    visible: globalDrawer.collapsible
                    checked: !globalDrawer.collapsed
                    onClicked: globalDrawer.collapsed = !globalDrawer.collapsed
                }

                Controls.Label {
                    text: "Menu"
                    visible: !globalDrawer.collapsed
                }
            }
        }

        actions: [
            Kirigami.PagePoolAction {
                text: "Home"
                icon.name: "go-home-symbolic"
                pagePool: appPagePool
                page: Qt.resolvedUrl("HomePage.qml")
                pageStack: root.pageStack
                // basePage removed — without it, PagePoolAction replaces
                // the whole stack, which is exactly the swap behaviour you want
            },
            Kirigami.PagePoolAction {
                text: "Anime"
                icon.name: "video-television-symbolic"
                pagePool: appPagePool
                page: Qt.resolvedUrl("AnimeListPage.qml")
                pageStack: root.pageStack
            },
            Kirigami.PagePoolAction {
                text: "Manga"
                icon.name: "accessories-dictionary-symbolic"
                pagePool: appPagePool
                page: Qt.resolvedUrl("MangaListPage.qml")
                pageStack: root.pageStack
            },
            Kirigami.PagePoolAction {
                text: "Notifications"
                icon.name: "notifications"
                pagePool: appPagePool
                page: Qt.resolvedUrl("NotificationsPage.qml")
                pageStack: root.pageStack
            },
            Kirigami.PagePoolAction {
                text: "Profile"
                icon.name: "user-identity"
                pagePool: appPagePool
                page: Qt.resolvedUrl("ProfilePage.qml")
                pageStack: root.pageStack
            },
            Kirigami.PagePoolAction {
                text: "Settings"
                icon.name: "settings-configure"
                pagePool: appPagePool
                page: Qt.resolvedUrl("SettingsPage.qml")
                pageStack: root.pageStack
            }
        ]
    }
}
