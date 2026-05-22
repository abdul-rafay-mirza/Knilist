import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 400
    height: 300

    title: "Day Kountdown"

    globalDrawer: Kirigami.GlobalDrawer {
        id: globalDrawer
        title: "Widget gallery"
        titleIcon: "applications-graphics"

        // Force the drawer to act as a slim, collapsible icon sidebar on startup
        modal: false            // Keep it integrated into the window canvas rather than an overlay panel
        collapsible: true       // Allow it to shrink down into a slim strip of icons
        collapsed: false         // Force it to initialize in that collapsed icon strip state on launch
        collapseButtonVisible: false // Removes default collapse button

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
            Kirigami.Action {
                text: "Home"
                icon.name: "go-home-symbolic"
                onTriggered: showPassiveNotification("Home Clicked!")
            },
            Kirigami.Action {
                text: "Anime"
                icon.name: "view-pages-single-symbolic"
                onTriggered: showPassiveNotification("Anime Clicked!")
            },
            Kirigami.Action {
                text: "Manga"
                icon.name: "view-pages-single-symbolic"
                onTriggered: showPassiveNotification("Manga Clicked!")
            },
            Kirigami.Action {
                text: "Notifications"
                icon.name: "view-pages-single-symbolic"
                onTriggered: showPassiveNotification("Notifications Clicked!")
            },
            Kirigami.Action {
                text: "Profile"
                icon.name: "view-pages-single-symbolic"
                onTriggered: showPassiveNotification("Profile Clicked!")
            },
            Kirigami.Action {
                text: "Settings"
                icon.name: "view-pages-single-symbolic"
                onTriggered: showPassiveNotification("Settings Clicked!")
            }
        ]
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Kountdown"

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            
            anchors.left: parent.left
            anchors.right: parent.right

            Controls.Label {
                text: "Welcome to Day Kountdown"
                font.bold: true
                font.pointSize: 16
            }

            Repeater {
                model: 10 
                
                Kirigami.Card {
                    Layout.fillWidth: true
                    
                    contentItem: Controls.Label {
                        text: "Event Number " + (index + 1)
                        padding: Kirigami.Units.largeSpacing
                    }
                }
            }
        }
    }
}