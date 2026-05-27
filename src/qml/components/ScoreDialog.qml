import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: scoreDialog

    property int  anilistId:    0
    property real currentScore: 0

    readonly property real maxScore: anilistService.scoreMax()

    title: "Edit Score"
    padding: Kirigami.Units.largeSpacing

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Controls.Label {
            text: "Score  (0 – " + scoreDialog.maxScore + ")"
            color: Kirigami.Theme.textColor
        }

        Controls.SpinBox {
            id: scoreSpin
            Layout.fillWidth: true
            from:  0
            to:    scoreDialog.maxScore
            value: scoreDialog.currentScore
        }
    }

    // Reset spinbox every time the dialog opens
    onOpened: scoreSpin.value = currentScore

    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

    onAccepted: {
        anilistService.saveScore(scoreDialog.anilistId, scoreSpin.value)
    }
}