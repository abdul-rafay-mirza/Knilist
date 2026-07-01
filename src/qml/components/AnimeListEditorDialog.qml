import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "date_picker"

Kirigami.Dialog {
    id: animeListEditorDialog

    // ── Public API ────────────────────────────────────────────────────────────
    property int    anilistId
    property string animeTitle
    property string currentStatus
    property real   currentScore
    property int    currentProgress
    property int    currentTotalEpisodes
    property int    currentStartYear
    property int    currentStartMonth
    property int    currentStartDay
    property int    currentFinishYear
    property int    currentFinishMonth
    property int    currentFinishDay
    property int    currentRewatches
    property string currentNotes
    property int    currentPriority
    property bool   currentHideFromLists
    property bool   currentPrivate

    signal entrySaved()
    signal entryRemoved()

    // ── Editable state ────────────────────────────────────────────────────────
    property string editStatus:        currentStatus
    property real   editScore:         0
    property int    editProgress:      currentProgress
    property int    editStartYear:     currentStartYear
    property int    editStartMonth:    currentStartMonth
    property int    editStartDay:      currentStartDay
    property int    editFinishYear:    currentFinishYear
    property int    editFinishMonth:   currentFinishMonth
    property int    editFinishDay:     currentFinishDay
    property int    editRewatches:     currentRewatches
    property string editNotes:         currentNotes
    property int    editPriority:      currentPriority
    property bool   editHideFromLists: currentHideFromLists
    property bool   editPrivate:       currentPrivate

    readonly property string scoreFmt: anilistService.scoreFormat

    onOpened: {
        editStatus        = currentStatus
        editScore         = currentScore
        editProgress      = currentProgress
        editStartYear     = currentStartYear
        editStartMonth    = currentStartMonth
        editStartDay      = currentStartDay
        editFinishYear    = currentFinishYear
        editFinishMonth   = currentFinishMonth
        editFinishDay     = currentFinishDay
        editRewatches     = currentRewatches
        editNotes         = currentNotes
        editPriority      = currentPriority
        editHideFromLists = currentHideFromLists
        editPrivate       = currentPrivate
    }

    // ── Dialog chrome ─────────────────────────────────────────────────────────
    title:           ""
    standardButtons: Kirigami.Dialog.NoButton

    // Set width/height directly — preferredWidth is only advisory in Kirigami
    // and gets overridden by overlay constraints
    width:  Math.min(Kirigami.Units.gridUnit * 46,
                     applicationWindow().width  * 0.9)
    height: Math.min(Kirigami.Units.gridUnit * 42,
                     applicationWindow().height * 0.9)

    customFooterActions: [
        Kirigami.Action {
            text:      "Remove from list"
            icon.name: "edit-delete-symbolic"
            onTriggered: removeDialog.open()
        },
        Kirigami.Action {
            text:      "Save"
            icon.name: "document-save-symbolic"
            onTriggered: doSave()
        }
    ]

    // ── Helpers ───────────────────────────────────────────────────────────────
    readonly property var statusOptions: [
        { id: "CURRENT",   label: "Watching"   },
        { id: "REPEATING", label: "Rewatching" },
        { id: "COMPLETED", label: "Completed"  },
        { id: "PAUSED",    label: "Paused"     },
        { id: "DROPPED",   label: "Dropped"    },
        { id: "PLANNING",  label: "Planning"   },
    ]

    function statusLabel(sid) {
        for (let i = 0; i < statusOptions.length; i++)
            if (statusOptions[i].id === sid) return statusOptions[i].label
        return sid
    }

    function padTwo(n) { return n < 10 ? "0" + n : "" + n }

    function dateString(y, m, d) {
        if (y === 0) return "Not set"
        return padTwo(d) + "/" + padTwo(m) + "/" + y
    }

    readonly property var scoreSuffix: ({
        "POINT_100":        "/ 100",
        "POINT_10_DECIMAL": "/ 10",
        "POINT_10":         "/ 10",
        "POINT_5":          "",
        "POINT_3":          "",
    })

    function doSave() {
        const startedAt   = editStartYear  > 0
            ? { year: editStartYear,  month: editStartMonth,  day: editStartDay  } : null
        const completedAt = editFinishYear > 0
            ? { year: editFinishYear, month: editFinishMonth, day: editFinishDay } : null

        anilistService.saveAnimeEntry(
            anilistId, editProgress, editStatus, editScore,
            startedAt   ? JSON.stringify(startedAt)   : "",
            completedAt ? JSON.stringify(completedAt) : "",
            editRewatches, editNotes, editPriority,
            editHideFromLists, editPrivate
        )
        animeListEditorDialog.entrySaved()
        animeListEditorDialog.close()
    }

    // ── Sub-dialogs ───────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id:       removeDialog
        title:    "Remove from list"
        subtitle: "Remove '" + animeListEditorDialog.animeTitle + "' from your list? This cannot be undone."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            anilistService.removeAnimeEntry(animeListEditorDialog.anilistId)
            animeListEditorDialog.entryRemoved()
            animeListEditorDialog.close()
        }
    }

    Kirigami.Dialog {
        id:    statusSheet
        title: "Status"
        standardButtons: Kirigami.Dialog.NoButton
        preferredWidth: Kirigami.Units.gridUnit * 20

        ColumnLayout {
            spacing: 0
            Repeater {
                model: animeListEditorDialog.statusOptions
                delegate: Controls.ItemDelegate {
                    Layout.fillWidth: true
                    text:        modelData.label
                    highlighted: animeListEditorDialog.editStatus === modelData.id
                    onClicked: {
                        animeListEditorDialog.editStatus = modelData.id
                        statusSheet.close()
                    }
                }
            }
        }
    }

    IntValidator    { id: intValidator;    bottom: 0; top: 100 }
    DoubleValidator { id: doubleValidator; bottom: 0; top: 10; decimals: 1
                      notation: DoubleValidator.StandardNotation }

    // ═════════════════════════════════════════════════════════════════════════
    // Content
    // ═════════════════════════════════════════════════════════════════════════
    contentItem: Controls.ScrollView {
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            // Bind to the dialog's own width minus its padding so we never
            // measure against an unconstrained ScrollView content size
            width: animeListEditorDialog.width
                   - animeListEditorDialog.leftPadding
                   - animeListEditorDialog.rightPadding
            spacing: 0

            // ── Title ─────────────────────────────────────────────────────────
            Controls.Label {
                Layout.fillWidth:    true
                Layout.leftMargin:   Kirigami.Units.gridUnit
                Layout.rightMargin:  Kirigami.Units.gridUnit
                Layout.topMargin:    Kirigami.Units.gridUnit
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                text:     animeListEditorDialog.animeTitle
                wrapMode: Text.WordWrap
                font { pixelSize: 18; bold: true }
                color: Kirigami.Theme.textColor
            }

            // ── GENERAL ───────────────────────────────────────────────────────
            SectionHeader { text: "General" }
            Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

            // Status
            EditorRow {
                label: "Status"
                Controls.Button {
                    Layout.fillWidth: true
                    text: animeListEditorDialog.statusLabel(animeListEditorDialog.editStatus)
                    onClicked: statusSheet.open()
                }
            }

            // Score
            EditorRow {
                label: "Score"

                Item {
                    Layout.fillWidth: true
                    implicitHeight: scoreFmt === "POINT_5"
                                    ? starRow.implicitHeight
                                    : scoreFmt === "POINT_3"
                                      ? smileyRow.implicitHeight
                                      : numericRow.implicitHeight

                    Row {
                        id: starRow
                        visible: animeListEditorDialog.scoreFmt === "POINT_5"
                        spacing: 4
                        Repeater {
                            model: 5
                            delegate: Controls.AbstractButton {
                                readonly property int  starValue: modelData + 1
                                readonly property bool filled: animeListEditorDialog.editScore >= starValue
                                implicitWidth:  Kirigami.Units.gridUnit * 2
                                implicitHeight: Kirigami.Units.gridUnit * 2
                                contentItem: Controls.Label {
                                    text:  filled ? "★" : "☆"
                                    color: filled ? Kirigami.Theme.highlightColor
                                                  : Kirigami.Theme.disabledTextColor
                                    font.pixelSize: 26
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: animeListEditorDialog.editScore =
                                    (animeListEditorDialog.editScore === starValue) ? 0 : starValue
                            }
                        }
                        Controls.Label {
                            visible: animeListEditorDialog.editScore > 0
                            text:    "(" + animeListEditorDialog.editScore + " / 5)"
                            color:   Kirigami.Theme.disabledTextColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: smileyRow
                        visible: animeListEditorDialog.scoreFmt === "POINT_3"
                        spacing: Kirigami.Units.largeSpacing
                        Repeater {
                            model: [
                                { val: 1, face: ":(", tip: "Bad"  },
                                { val: 2, face: ":|", tip: "Okay" },
                                { val: 3, face: ":)", tip: "Good" },
                            ]
                            delegate: Controls.Button {
                                readonly property bool active: animeListEditorDialog.editScore === modelData.val
                                text:        modelData.face
                                highlighted: active
                                font.pixelSize: 18
                                Controls.ToolTip.visible: hovered
                                Controls.ToolTip.text:    modelData.tip
                                onClicked: animeListEditorDialog.editScore = active ? 0 : modelData.val
                            }
                        }
                        Controls.Label {
                            visible: animeListEditorDialog.editScore === 0
                            text:    "Not rated"
                            color:   Kirigami.Theme.disabledTextColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: numericRow
                        visible: animeListEditorDialog.scoreFmt !== "POINT_5"
                              && animeListEditorDialog.scoreFmt !== "POINT_3"
                        spacing: Kirigami.Units.smallSpacing
                        Controls.TextField {
                            id: scoreField
                            width: Kirigami.Units.gridUnit * 7
                            placeholderText: "0"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: animeListEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                       ? doubleValidator : intValidator
                            text: animeListEditorDialog.editScore > 0
                                  ? (animeListEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                     ? animeListEditorDialog.editScore.toFixed(1)
                                     : String(Math.round(animeListEditorDialog.editScore)))
                                  : ""
                            onEditingFinished: {
                                const v   = parseFloat(text)
                                const max = anilistService.scoreMax()
                                animeListEditorDialog.editScore =
                                    (!isNaN(v) && v >= 0 && v <= max) ? v : 0
                            }
                        }
                        Controls.Label {
                            text:  animeListEditorDialog.scoreSuffix[animeListEditorDialog.scoreFmt] ?? ""
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Episode
            EditorRow {
                label: "Episode"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Controls.SpinBox {
                        Layout.fillWidth: true
                        from: 0
                        to: animeListEditorDialog.currentTotalEpisodes > 0
                                ? animeListEditorDialog.currentTotalEpisodes : 9999
                        value:    animeListEditorDialog.editProgress
                        editable: true
                        onValueModified: animeListEditorDialog.editProgress = value
                    }
                    Controls.Label {
                        text:  "/ " + (animeListEditorDialog.currentTotalEpisodes > 0
                                       ? animeListEditorDialog.currentTotalEpisodes : "?")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: 13
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                    }
                }
            }

            DatePopup {
                id: startDatePopup
                popupWidth: Kirigami.Units.gridUnit * 24
                onAccepted: {
                    animeListEditorDialog.editStartYear  = value.getFullYear()
                    animeListEditorDialog.editStartMonth = value.getMonth() + 1
                    animeListEditorDialog.editStartDay   = value.getDate()
                }
            }

            DatePopup {
                id: finishDatePopup
                popupWidth: Kirigami.Units.gridUnit * 24
                onAccepted: {
                    animeListEditorDialog.editFinishYear  = value.getFullYear()
                    animeListEditorDialog.editFinishMonth = value.getMonth() + 1
                    animeListEditorDialog.editFinishDay   = value.getDate()
                }
            }

            // Start Date
            EditorRow {
                label: "Start Date"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Button {
                        Layout.fillWidth: true
                        text: animeListEditorDialog.dateString(
                            animeListEditorDialog.editStartYear,
                            animeListEditorDialog.editStartMonth,
                            animeListEditorDialog.editStartDay)
                        onClicked: {
                            startDatePopup.value = animeListEditorDialog.editStartYear > 0
                                ? new Date(animeListEditorDialog.editStartYear,
                                        animeListEditorDialog.editStartMonth - 1,
                                        animeListEditorDialog.editStartDay)
                                : new Date()
                            startDatePopup.open()
                            console.log("Start date clicked!")
                        }
                    }
                    Controls.Button {
                        icon.name: "edit-clear-symbolic"
                        visible: animeListEditorDialog.editStartYear > 0
                        Controls.ToolTip.text: "Clear"
                        Controls.ToolTip.visible: hovered
                        onClicked: {
                            animeListEditorDialog.editStartYear  = 0
                            animeListEditorDialog.editStartMonth = 0
                            animeListEditorDialog.editStartDay   = 0
                        }
                    }
                }
            }

            // Finish Date — same pattern
            EditorRow {
                label: "Finish Date"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Button {
                        Layout.fillWidth: true
                        text: animeListEditorDialog.dateString(
                            animeListEditorDialog.editFinishYear,
                            animeListEditorDialog.editFinishMonth,
                            animeListEditorDialog.editFinishDay)
                        onClicked: {
                            finishDatePopup.value = animeListEditorDialog.editFinishYear > 0
                                ? new Date(animeListEditorDialog.editFinishYear,
                                        animeListEditorDialog.editFinishMonth - 1,
                                        animeListEditorDialog.editFinishDay)
                                : new Date()
                            finishDatePopup.open()
                            console.log("finish date clicked!")
                        }
                    }
                    Controls.Button {
                        icon.name: "edit-clear-symbolic"
                        visible: animeListEditorDialog.editFinishYear > 0
                        Controls.ToolTip.text: "Clear"
                        Controls.ToolTip.visible: hovered
                        onClicked: {
                            animeListEditorDialog.editFinishYear  = 0
                            animeListEditorDialog.editFinishMonth = 0
                            animeListEditorDialog.editFinishDay   = 0
                        }
                    }
                }
            }

            // Rewatches
            EditorRow {
                label: "Rewatches"
                Controls.SpinBox {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    from: 0; to: 9999
                    value:    animeListEditorDialog.editRewatches
                    editable: true
                    onValueModified: animeListEditorDialog.editRewatches = value
                }
            }

            // Notes
            EditorRow {
                label: "Notes"
                Controls.TextArea {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                    placeholderText: "Add notes…"
                    text:            animeListEditorDialog.editNotes
                    wrapMode:        TextInput.WordWrap
                    onTextChanged:   animeListEditorDialog.editNotes = text
                }
            }

            // Priority
            EditorRow {
                label: "Priority"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 0; to: 5; stepSize: 1
                        value: animeListEditorDialog.editPriority
                        onMoved: animeListEditorDialog.editPriority = Math.round(value)
                    }
                    Controls.Label {
                        text:  animeListEditorDialog.editPriority === 0 ? "None"
                               : animeListEditorDialog.editPriority
                        color: animeListEditorDialog.editPriority > 0
                               ? Kirigami.Theme.highlightColor
                               : Kirigami.Theme.disabledTextColor
                        font { pixelSize: 13; bold: animeListEditorDialog.editPriority > 0 }
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // ── OTHERS ────────────────────────────────────────────────────────
            Item { Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5 }
            SectionHeader { text: "Others" }
            Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

            ToggleRow {
                label:     "Hide from status lists"
                checked:   animeListEditorDialog.editHideFromLists
                onToggled: animeListEditorDialog.editHideFromLists = checked
            }

            ToggleRow {
                label:     "Private"
                checked:   animeListEditorDialog.editPrivate
                onToggled: animeListEditorDialog.editPrivate = checked
            }

            Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
        }
    }

    // ── Inline components ─────────────────────────────────────────────────────
    component EditorRow: RowLayout {
        property string label: ""
        Layout.fillWidth:    true
        Layout.leftMargin:   Kirigami.Units.gridUnit
        Layout.rightMargin:  Kirigami.Units.gridUnit
        Layout.topMargin:    Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.gridUnit

        Controls.Label {
            text:  label
            color: Kirigami.Theme.textColor
            font.pixelSize: 13
            // Fixed label column width — wide enough for "Hide from status lists"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 8
            Layout.alignment:    Qt.AlignVCenter
            wrapMode:            Text.WordWrap
        }
    }

    component ToggleRow: RowLayout {
        property string label:   ""
        property bool   checked: false
        signal toggled(bool checked)

        Layout.fillWidth:    true
        Layout.leftMargin:   Kirigami.Units.gridUnit
        Layout.rightMargin:  Kirigami.Units.gridUnit
        Layout.topMargin:    Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.gridUnit

        Controls.Label {
            Layout.fillWidth: true
            text:  label
            color: Kirigami.Theme.textColor
            font.pixelSize: 13
        }
        Controls.CheckBox {
            checked:   parent.checked
            onToggled: parent.toggled(checked)
        }
    }

    component SectionHeader: ColumnLayout {
        property string text: ""
        Layout.fillWidth:   true
        Layout.leftMargin:  Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            text:  parent.text
            color: Kirigami.Theme.highlightColor
            font { pixelSize: 12; bold: true; capitalization: Font.AllUppercase }
            Layout.fillWidth: true
        }
        Kirigami.Separator { Layout.fillWidth: true }
    }
}
