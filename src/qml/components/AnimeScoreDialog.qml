import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: animeScoreDialog

    property int  anilistId:    0
    property real currentScore: 0

    readonly property string fmt:      anilistService.scoreFormat
    readonly property real   maxScore: anilistService.scoreMax()

    // Tracks the final value regardless of which input is visible
    property real selectedScore: 0

    title: "Edit Anime Score"
    padding: Kirigami.Units.largeSpacing

    onOpened: {
        selectedScore = currentScore

        // Sync each input to the current score
        intSpin.value       = currentScore
        decimalField.text   = currentScore > 0 ? currentScore.toFixed(1) : ""
        starRow.starValue   = currentScore
        smileyRow.smileyValue = currentScore
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ── POINT_100 / POINT_10 — integer SpinBox ────────────────────────
        Controls.SpinBox {
            id: intSpin
            visible: fmt === "POINT_100" || fmt === "POINT_10"
            Layout.fillWidth: true
            from:  0
            to:    animeScoreDialog.maxScore
            value: animeScoreDialog.currentScore
            onValueModified: animeScoreDialog.selectedScore = value
        }

        // ── POINT_10_DECIMAL — text field with decimal validator ───────────
        ColumnLayout {
            visible: fmt === "POINT_10_DECIMAL"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text:  "Score (0.0 – 10.0)"
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 12
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Controls.TextField {
                    id: decimalField
                    Layout.fillWidth: true
                    placeholderText: "0.0"
                    horizontalAlignment: Text.AlignHCenter
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    validator: DoubleValidator {
                        bottom: 0.0; top: 10.0; decimals: 1
                        notation: DoubleValidator.StandardNotation
                    }
                    onTextChanged: {
                        const v = parseFloat(text)
                        if (!isNaN(v) && v >= 0 && v <= 10)
                            animeScoreDialog.selectedScore = v
                    }
                }

                Controls.Label {
                    text:  "/ 10"
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 14
                }
            }
        }

        // ── POINT_5 — star buttons ────────────────────────────────────────
        RowLayout {
            id: starRow
            visible: fmt === "POINT_5"
            spacing: 4
            property int starValue: 0

            Repeater {
                model: 5
                delegate: Kirigami.Icon {
                    source: (index + 1) <= starRow.starValue
                            ? "starred-symbolic"
                            : "non-starred-symbolic"
                    width:  32; height: 32
                    color:  Kirigami.Theme.highlightColor

                    TapHandler {
                        onTapped: {
                            starRow.starValue = index + 1
                            animeScoreDialog.selectedScore = index + 1
                        }
                    }
                }
            }
        }

        // ── POINT_3 — smiley buttons ──────────────────────────────────────
        RowLayout {
            id: smileyRow
            visible: fmt === "POINT_3"
            spacing: Kirigami.Units.largeSpacing
            property int smileyValue: 0

            Repeater {
                model: [
                    { label: ":(", value: 1 },
                    { label: ":|", value: 2 },
                    { label: ":)", value: 3 }
                ]
                delegate: Controls.Button {
                    text:        modelData.label
                    checkable:   true
                    checked:     smileyRow.smileyValue === modelData.value
                    font.pixelSize: 18
                    onClicked: {
                        smileyRow.smileyValue = modelData.value
                        animeScoreDialog.selectedScore = modelData.value
                    }
                }
            }
        }
    }

    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

    onAccepted: {
        anilistService.saveAnimeScore(animeScoreDialog.anilistId, animeScoreDialog.selectedScore)
    }
}
