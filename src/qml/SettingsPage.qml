import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: settingsPage
    title: "Settings"

    // ── React to auth state changes from Python ───────────────────────────────
    Connections {
        target: authManager

        function onLoginFailed(message) {
            statusBar.type    = Kirigami.MessageType.Error
            statusBar.text    = message
            statusBar.visible = true
        }

        function onLoginSuccess() {
            statusBar.type    = Kirigami.MessageType.Positive
            statusBar.text    = "Fetching your anime list…"
            statusBar.visible = true
        }

        function onLogoutDone() {
            statusBar.visible = false
        }

        function onLoginStateChanged() {
            // Clear any leftover status message once state settles
            if (!authManager.isLoggedIn)
                statusBar.visible = false
        }
    }

    Connections {
        target: anilistService

        function onAnimeLoaded() {
            statusBar.visible = false
        }

        function onErrorOccurred(msg) {
            statusBar.type    = Kirigami.MessageType.Error
            statusBar.text    = "AniList error: " + msg
            statusBar.visible = true
        }
    }

    // ── Page content ──────────────────────────────────────────────────────────
    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        // Status / error banner
        Kirigami.InlineMessage {
            id:               statusBar
            Layout.fillWidth: true
            visible:          false
            showCloseButton:  true
            // .type and .text set dynamically above
        }

        // ── AniList account card ──────────────────────────────────────────────
        Kirigami.Card {
            Layout.fillWidth: true

            header: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                anchors.margins: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "im-user-symbolic"
                    implicitWidth:  Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                Kirigami.Heading {
                    text:  "AniList Account"
                    level: 3
                }
            }

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // ── Logged-out view ───────────────────────────────────────────
                ColumnLayout {
                    visible:  !authManager.isLoggedIn
                    spacing:  Kirigami.Units.smallSpacing

                    Controls.Label {
                        Layout.fillWidth: true
                        text:     "Connect your AniList account to sync your anime and manga lists."
                        wrapMode: Text.WordWrap
                        opacity:  0.7
                    }

                    Controls.Button {
                        text:      "Log in to AniList"
                        icon.name: "network-connect-symbolic"
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        onClicked: {
                            statusBar.type    = Kirigami.MessageType.Information
                            statusBar.text    = "Opening browser… complete login there, then return here."
                            statusBar.visible = true
                            authManager.login()
                        }
                    }
                }

                // ── Logged-in view ────────────────────────────────────────────
                RowLayout {
                    visible:  authManager.isLoggedIn
                    spacing:  Kirigami.Units.largeSpacing

                    // Avatar placeholder (swap for Image {} when you add avatarUrl)
                    Rectangle {
                        width:  Kirigami.Units.iconSizes.huge
                        height: Kirigami.Units.iconSizes.huge
                        radius: width / 2
                        color:  Kirigami.Theme.highlightColor

                        Controls.Label {
                            anchors.centerIn: parent
                            text:  authManager.username.length > 0
                                   ? authManager.username[0].toUpperCase()
                                   : "?"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                            color: Kirigami.Theme.highlightedTextColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Controls.Label {
                            text:        authManager.username || "Loading…"
                            font.weight: Font.DemiBold
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                        }

                        Controls.Label {
                            text:    "Connected to AniList"
                            opacity: 0.6
                        }
                    }

                    Controls.Button {
                        text:      "Sync now"
                        icon.name: "view-refresh-symbolic"
                        Layout.alignment: Qt.AlignVCenter
                        enabled:  !anilistService.loading
                        onClicked: anilistService.fetchAll()
                    }

                    Controls.Button {
                        text:      "Log out"
                        icon.name: "system-log-out-symbolic"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: logoutDialog.open()
                    }
                }

                // Loading indicator (visible during fetchAll)
                RowLayout {
                    visible:  anilistService.loading
                    spacing:  Kirigami.Units.smallSpacing

                    Controls.BusyIndicator {
                        implicitWidth:  Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        running: true
                    }
                    Controls.Label {
                        text:    "Syncing with AniList…"
                        opacity: 0.7
                    }
                }
            }
        }
        // Spacing at the bottom
        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
    }

    // ── Logout confirmation dialog ─────────────────────────────────────────────
    Kirigami.PromptDialog {
        id:              logoutDialog
        title:           "Log out of AniList?"
        subtitle:        "Your stored token will be removed from KWallet. " +
                         "Your AniList data stays on AniList and can be re-synced after logging in again."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted:      authManager.logout()
    }
}
