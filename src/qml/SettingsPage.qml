import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: settingsPage
    title: "Settings"

    // ── Human-readable labels for each AniList scoreFormat enum value ─────────
    readonly property var scoreFormatLabels: ({
        "POINT_100":        "100 Point  (e.g. 75/100)",
        "POINT_10_DECIMAL": "10 Point Decimal  (e.g. 7.5/10)",
        "POINT_10":         "10 Point  (e.g. 7/10)",
        "POINT_5":          "5 Star  (e.g. ★★★☆☆)",
        "POINT_3":          "3 Point Smiley  (e.g. :) :| :(",
    })

    function scoreFormatLabel(fmt) {
        return scoreFormatLabels[fmt] ?? fmt
    }

    // ── React to auth / service signals ───────────────────────────────────────
    Connections {
        target: authManager

        function onLoginFailed(message) {
            statusBar.type    = Kirigami.MessageType.Error
            statusBar.text    = message
            statusBar.visible = true
        }
        function onLoginSuccess() {
            statusBar.type    = Kirigami.MessageType.Positive
            statusBar.text    = "Fetching your anime and manga list…"
            statusBar.visible = true
        }
        function onLogoutDone() {
            statusBar.visible = false
        }
        function onLoginStateChanged() {
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
    Item {
        anchors.fill: parent

        Flickable {
            anchors.fill:       parent
            contentWidth:       parent.width
            contentHeight:      mainColumn.implicitHeight
            clip:               true
            flickableDirection: Flickable.VerticalFlick

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: mainColumn
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                // Status / error banner
                Kirigami.InlineMessage {
                    id:               statusBar
                    Layout.fillWidth: true
                    visible:          false
                    showCloseButton:  true
                }

                // Theme Changer
                Controls.Label {
                    text: "Theme:"
                    font.bold: true
                }

                Controls.ComboBox {
                    id: themeComboBox
                    Layout.fillWidth: true
                    model: themeChanger ? themeChanger.getThemes() : []

                    onActivated: (index) => {
                        if (!themeChanger) return
                        let selectedName = model[index]
                        themeChanger.applyTheme(selectedName)
                    }

                    Component.onCompleted: {
                        let index = model.indexOf(themeChanger.currentTheme())
                        if (index >= 0)
                            currentIndex = index
                    }
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
                                onClicked: {
                                    anilistService.fetchAnime()
                                    anilistService.fetchManga()
                                }
                            }

                            Controls.Button {
                                text:      "Log out"
                                icon.name: "system-log-out-symbolic"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: logoutDialog.open()
                            }
                        }

                        // Loading indicator
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

                // ── Scoring format card — only shown when logged in ───────────────────
                Kirigami.Card {
                    Layout.fillWidth: true
                    visible: authManager.isLoggedIn

                    header: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        anchors.margins: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            source: "starred-symbolic"
                            implicitWidth:  Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                        }
                        Kirigami.Heading {
                            text:  "Scoring System"
                            level: 3
                        }
                    }

                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.largeSpacing

                        // Detected format row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Controls.Label {
                                    text: anilistService.scoreFormat !== ""
                                          ? settingsPage.scoreFormatLabel(anilistService.scoreFormat)
                                          : "Not yet detected — sync to load"
                                    font.pixelSize: 14
                                    font.weight:    Font.DemiBold
                                    color: Kirigami.Theme.textColor
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: "Detected automatically from your AniList account settings. "
                                        + "To change it, update your scoring system on AniList, then sync."
                                    wrapMode: Text.WordWrap
                                    opacity:  0.65
                                    font.pixelSize: 12
                                }
                            }

                            // Quick link to AniList settings
                            Controls.Button {
                                text:      "Change on AniList"
                                icon.name: "internet-web-browser-symbolic"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: Qt.openUrlExternally(
                                    "https://anilist.co/settings/lists")
                            }
                        }

                        // Visual example of how a score looks in the current format
                        RowLayout {
                            visible: anilistService.scoreFormat !== ""
                            spacing: Kirigami.Units.smallSpacing

                            Controls.Label {
                                text:    "Example:"
                                opacity: 0.6
                                font.pixelSize: 12
                            }
                            Controls.Label {
                                // Show a mid-range score in whatever the user's format is
                                text: {
                                    const fmt = anilistService.scoreFormat
                                    if (fmt === "POINT_100")        return anilistService.formatScore(72)
                                    if (fmt === "POINT_10_DECIMAL") return anilistService.formatScore(7.2)
                                    if (fmt === "POINT_10")         return anilistService.formatScore(7)
                                    if (fmt === "POINT_5")          return anilistService.formatScore(4)
                                    if (fmt === "POINT_3")          return anilistService.formatScore(2)
                                    return ""
                                }
                                color: Kirigami.Theme.highlightColor
                                font { pixelSize: 13; bold: true }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
            }
        }
    }

    // ── Logout dialog ─────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id:              logoutDialog
        title:           "Log out of AniList?"
        subtitle:        "Your stored token will be removed from KWallet. " +
                         "Your AniList data stays on AniList and can be re-synced after logging in again."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted:      authManager.logout()
    }
}
