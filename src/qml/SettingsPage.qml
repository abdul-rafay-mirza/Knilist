import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import "components"

Kirigami.Page {
    id: settingsPage
    title: "Settings"

    AboutDialog {
        id: aboutDialog
    }

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
                width: Math.min(parent.width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 40)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Kirigami.Units.largeSpacing

                // Status / error banner
                Kirigami.InlineMessage {
                    id:               statusBar
                    Layout.fillWidth: true
                    visible:          false
                    showCloseButton:  true
                }

                // General
                FormCard.FormHeader {
                    Layout.fillWidth: true
                    title: "General"
                }
                FormCard.FormCard {
                    Layout.fillWidth: true

                    FormCard.AbstractFormDelegate {
                        background: Item {}

                        contentItem: RowLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                text: "Application Theme"
                                font.bold: true
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Controls.ComboBox {
                                id: themeComboBox
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
                        }
                    }
                }

                // Account
                FormCard.FormHeader {
                    Layout.fillWidth: true
                    title: "Account"
                }
                FormCard.FormCard {
                    Layout.fillWidth: true

                    FormCard.AbstractFormDelegate {
                        background: Item {}

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.largeSpacing

                            // ── Logged-out view ───────────────────────────────────────
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

                            // ── Logged-in view ────────────────────────────────────────
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

                                Item {
                                    Layout.fillWidth: true
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
                }

                // ── Scoring format — only shown when logged in ────────────────
                FormCard.FormHeader {
                    Layout.fillWidth: true
                    title: "Scoring System"
                    visible: authManager.isLoggedIn
                }
                FormCard.FormCard {
                    Layout.fillWidth: true

                    FormCard.AbstractFormDelegate {
                        visible: authManager.isLoggedIn
                        background: Item {}

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
                }

                // Defaults
                FormCard.FormHeader {
                    Layout.fillWidth: true
                    title: "Defaults"
                }
                FormCard.FormCard {
                    Layout.fillWidth: true

                    FormCard.AbstractFormDelegate {
                        background: Item {}

                        contentItem: RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing / 2

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: "Default Visibility for About Section"
                                    wrapMode: Text.WordWrap
                                    font.bold: true
                                }
                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: "Set the default visibility of the About section in Profile Page and for other users page"
                                    wrapMode: Text.WordWrap
                                    opacity: 0.65
                                    font.pixelSize: 12
                                }
                            }

                            Controls.Switch {
                                checked: settings.aboutExpanded
                                onToggled: settings.aboutExpanded = checked
                            }
                        }
                    }

                    FormCard.FormDelegateSeparator {}

                    FormCard.AbstractFormDelegate {
                        background: Item {}

                        contentItem: RowLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                Layout.fillWidth: true
                                text: "Default List Selection for Anime List"
                                wrapMode: Text.WordWrap
                                font.bold: true
                            }

                            Controls.ComboBox {

                                model: [
                                    { text: "All",         value: "ALL" },
                                    { text: "Watching",    value: "CURRENT" },
                                    { text: "Rewatching",  value: "REPEATING" },
                                    { text: "Completed",   value: "COMPLETED" },
                                    { text: "Paused",      value: "PAUSED" },
                                    { text: "Dropped",     value: "DROPPED" },
                                    { text: "Planning",    value: "PLANNING" }
                                ]

                                textRole: "text"

                                Component.onCompleted: {
                                    for (let i = 0; i < model.length; ++i) {
                                        if (model[i].value === settings.animeListSelectedStatus) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                onActivated: {
                                    settings.animeListSelectedStatus = model[currentIndex].value
                                }
                            }
                        }
                    }

                    FormCard.FormDelegateSeparator {}

                    FormCard.AbstractFormDelegate {
                        background: Item {}

                        contentItem: RowLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                Layout.fillWidth: true
                                text: "Default List Selection for Manga List"
                                wrapMode: Text.WordWrap
                                font.bold: true
                            }

                            Controls.ComboBox {

                                model: [
                                    { text: "All",         value: "ALL" },
                                    { text: "Reading",    value: "CURRENT" },
                                    { text: "Rereading",  value: "REPEATING" },
                                    { text: "Completed",   value: "COMPLETED" },
                                    { text: "Paused",      value: "PAUSED" },
                                    { text: "Dropped",     value: "DROPPED" },
                                    { text: "Planning",    value: "PLANNING" }
                                ]

                                textRole: "text"

                                Component.onCompleted: {
                                    for (let i = 0; i < model.length; ++i) {
                                        if (model[i].value === settings.mangaListSelectedStatus) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                onActivated: {
                                    settings.mangaListSelectedStatus = model[currentIndex].value
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════════════
                // About
                // ══════════════════════════════════════════════════════════════════
                FormCard.FormHeader {
                    Layout.fillWidth: true
                    title: "About"
                }
                FormCard.FormCard {
                    Layout.fillWidth: true

                    FormCard.FormButtonDelegate {
                        text: "About Knilist"
                        onClicked: aboutDialog.open()
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
        subtitle:        "Are you sure you want to log out?"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted:      authManager.logout()
    }
}
