import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    width: 800
    height: 600
    title: "Knilist Beta"

    Kirigami.PagePool {
        id: appPagePool
    }

    // Use Component.onCompleted to push after the window is fully ready
    // and use loadPage() not load()
    Component.onCompleted: {
        pageStack.push(appPagePool.loadPage(Qt.resolvedUrl("HomePage.qml")))
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: globalDrawer
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
                page: Qt.resolvedUrl("AnimePage.qml")
                pageStack: root.pageStack
            },
            Kirigami.PagePoolAction {
                text: "Manga"
                icon.name: "view-pages-single-symbolic"
                pagePool: appPagePool
                page: Qt.resolvedUrl("MangaPage.qml")
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