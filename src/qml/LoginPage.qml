import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Shown in place of the whole drawer+pageStack UI whenever
// authManager.isLoggedIn is false — see the Loader in Main.qml.
// There's no username/password form here because AniList's OAuth
// flow uses the auth-pin redirect: authManager.login() opens the
// system browser to AniList, which shows the token as plain text on
// its own page (no redirect_uri, no local server). This page's job
// is to kick that off, then let the user paste the token back in.
Kirigami.Page {
    id: root

    title: "Welcome"

    // Page owns no toolbar/actions — nothing useful to put there
    // pre-login, and NeoChat's welcome page is similarly bare.
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

    // ── State ────────────────────────────────────────────────────────
    // "idle"    → show button, ready to start login
    // "waiting" → login() has been called; browser is open, showing
    //             the token on AniList's own page; app is waiting for
    //             the user to paste it back here (no local server —
    //             nothing to time out on this end)
    // "error"   → loginFailed fired; message holds the reason
    property string state: "idle"
    property string errorMessage: ""

    Connections {
        target: authManager

        function onLoginSuccess() {
            // Main.qml's Loader swaps away from this page automatically
            // once authManager.isLoggedIn flips (loginStateChanged is
            // emitted right after loginSuccess in AuthManager), so
            // nothing else to do here.
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

        // ── Idle ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            visible: root.state === "idle"

            Controls.Button {
                text: "Log in with AniList"
                icon.name: "internet-services"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5

                onClicked: {
                    root.state = "waiting"
                    root.errorMessage = ""
                    authManager.login()
                }
            }
        }

        // ── Waiting: paste token back ───────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            visible: root.state === "waiting"

            Controls.Label {
                text: "AniList will show you a token on its own page — copy it and paste it below."
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Controls.TextField {
                id: tokenField
                Layout.fillWidth: true
                placeholderText: "Paste token here"
                onAccepted: submitButton.clicked()
            }

            Controls.Button {
                id: submitButton
                text: "Submit"
                icon.name: "dialog-ok"
                enabled: tokenField.text.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5

                onClicked: authManager.submitToken(tokenField.text)
            }

            Controls.Button {
                text: "Start over"
                flat: true
                Layout.fillWidth: true

                onClicked: {
                    root.state = "idle"
                    tokenField.text = ""
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
