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

    // AniList only exposes a single aggregate unread count (no per-
    // notification read state — see graphql_queries.py's _NOTIFICATIONS_QUERY
    // docstring), so this is the one number the drawer badge shows. Kept
    // here rather than in HomePage/NotificationsPage since the drawer is
    // visible regardless of which page is active.
    property int unreadNotificationCount: 0

    // Tracks which of the two top-level UI states (login gate vs. the
    // normal drawer+pageStack UI) is currently showing, so
    // onLoginStateChanged below can tell them apart without inspecting
    // pageStack.currentItem itself (e.g. via toString() on the page
    // instance) — matching on an explicit flag here is more robust than
    // matching on Qt's default object-to-string formatting, which isn't
    // a stable API to depend on.
    property bool loggedInUIShown: false

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

    // Swaps the whole window content between LoginPage (logged out) and
    // the normal drawer+pageStack UI (logged in), mirroring how NeoChat
    // gates its main UI behind a welcome/login screen rather than
    // treating login as just another page on the stack. Driven by
    // authManager.isLoggedIn below, which fires on both directions:
    // login (loginStateChanged emitted right after loginSuccess in
    // AuthManager.login()) and logout (logoutDone/loginStateChanged in
    // AuthManager.logout()), so this covers a logout triggered mid-
    // session from SettingsPage as well as the initial launch state.
    function showLoggedInUI() {
        globalDrawer = loggedInDrawerComponent.createObject(root)
        pageStack.clear()
        pageStack.push(appPagePool.loadPage(Qt.resolvedUrl("HomePage.qml")))
        root.loggedInUIShown = true
        // Fetch here (not just relying on HomePage's own fetchHomeProfile
        // call) so the drawer badge is correct even before HomePage's own
        // Component.onCompleted runs, and stays correct if the user's
        // first destination is ever changed to something other than Home.
        anilistService.fetchHomeProfile()
    }

    function showLoginUI() {
        // Unset (not just hide) the drawer — GlobalDrawer with no
        // meaningful actions pre-login would otherwise still show as an
        // empty collapsed rail. destroy() the old one since it was
        // createObject()'d above and QML won't otherwise garbage-collect
        // a QObject-parented item that's no longer referenced.
        if (globalDrawer) {
            globalDrawer.destroy()
            globalDrawer = null
        }
        pageStack.clear()
        pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
        root.loggedInUIShown = false
    }

    // Use Component.onCompleted so this runs after the window is fully
    // ready, and use loadPage()/resolvedUrl (not load()) per the
    // existing pageStack conventions above.
    Component.onCompleted: {
        if (authManager.isLoggedIn) {
            showLoggedInUI()
        } else {
            showLoginUI()
        }
    }

    Connections {
        target: authManager
        function onLoginStateChanged() {
            if (authManager.isLoggedIn && !root.loggedInUIShown) {
                showLoggedInUI()
            } else if (!authManager.isLoggedIn && root.loggedInUIShown) {
                showLoginUI()
            }
            // Both branches also naturally guard against firing twice
            // for the same transition, since loggedInUIShown flips as
            // part of the corresponding show*UI() call.
        }
    }

    Connections {
        target: pageStack.layers
        function onDepthChanged() {
            // globalDrawer is null while logged out (see showLoginUI),
            // and LoginPage never uses pageStack.layers, but guard
            // anyway since this fires on every depth change regardless
            // of login state.
            if (!globalDrawer) {
                return
            }
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
        function onHomeProfileLoaded(json) {
            const payload = JSON.parse(json)
            root.unreadNotificationCount = payload.unreadNotificationCount || 0
        }
        function onUnreadNotificationCountChanged(count) {
            root.unreadNotificationCount = count
        }
    }

    property var drawerWidth: Kirigami.Units.gridUnit * 9

    // Wrapped in a Component (rather than the previous direct
    // `globalDrawer: Kirigami.GlobalDrawer { ... }` assignment) because
    // it's now instantiated on demand via createObject() in
    // showLoggedInUI(), and destroyed again in showLoginUI() — the
    // drawer only exists at all while logged in. Contents unchanged
    // from before other than that wrapping.
    Component {
        id: loggedInDrawerComponent

        Kirigami.GlobalDrawer {
            id: globalDrawer
            width: root.drawerWidth
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
                        onClicked: {
                            globalDrawer.collapsed = !globalDrawer.collapsed
                            if (globalDrawer.collapsed) {
                                root.drawerWidth = Kirigami.Units.gridUnit * 2.5
                            } else {
                                root.drawerWidth = Kirigami.Units.gridUnit * 9
                            }
                        }
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
                    text: root.unreadNotificationCount > 0
                              ? "Notifications (" + root.unreadNotificationCount + ")"
                              : "Notifications"
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
}
