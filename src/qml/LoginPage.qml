import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Shown in place of the whole drawer+pageStack UI whenever
// authManager.isLoggedIn is false — see the Loader in Main.qml.
// There's no username/password form here because AniList's OAuth
// flow (AuthManager.login()) opens the system browser and spins up
// a localhost callback server; this page's job is just to kick that
// off and show waiting/error state until loginSuccess or
// loginFailed comes back.
Kirigami.Page {
    id: root

    title: "Welcome"

    // Page owns no toolbar/actions — nothing useful to put there
    // pre-login, and NeoChat's welcome page is similarly bare.
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

    // ── State ────────────────────────────────────────────────────────
    // "idle"    → show button, ready to start login
    // "waiting" → login() has been called; browser is open, local
    //             server is listening for the OAuth redirect
    // "error"   → loginFailed fired; message holds the reason
    property string state: "idle"
    property string errorMessage: ""

    Connections {
        target: authManager

        function onLoginSuccess() {
            // Main.qml's Loader swaps away from this page automatically
            // once authManager.isLoggedIn flips (loginStateChanged is
            // emitted right after loginSuccess in AuthManager.login()),
            // so nothing else to do here.
            root.state = "idle"
        }

        function onLoginFailed(message) {
            root.state = "error"
            root.errorMessage = message
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit * 4,
                         Kirigami.Units.gridUnit * 22)
        spacing: Kirigami.Units.largeSpacing * 2

        Kirigami.Icon {
            source: "com.github.abdul-rafay-mirza.knilist"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: "Knilist"
                level: 1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Controls.Label {
                text: "Track your anime and manga with AniList"
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ── Idle / waiting ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            visible: root.state !== "error"

            Controls.Button {
                text: root.state === "waiting" ? "Waiting for browser…" : "Log in with AniList"
                icon.name: "internet-services"
                enabled: root.state !== "waiting"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5

                onClicked: {
                    root.state = "waiting"
                    root.errorMessage = ""
                    authManager.login()
                }
            }

            RowLayout {
                visible: root.state === "waiting"
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                Controls.BusyIndicator {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    running: root.state === "waiting"
                }

                Controls.Label {
                    text: "Continue in your browser, then return here"
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }
        }

        // ── Error ───────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            visible: root.state === "error"

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: root.errorMessage
                visible: true
            }

            Controls.Button {
                text: "Try again"
                icon.name: "view-refresh"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5

                onClicked: {
                    root.state = "idle"
                    root.errorMessage = ""
                }
            }
        }
    }
}
