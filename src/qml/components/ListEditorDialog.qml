import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: listEditorDialog

    // ── Public API ────────────────────────────────────────────────────────────
    property int    anilistId
    property string animeTitle
    property string currentStatus
    property int    currentScore
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

    // ── Local editable state ──────────────────────────────────────────────────
    property string editStatus:        currentStatus
    property int    editScore:         currentScore
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
    title:           animeTitle
    standardButtons: Kirigami.Dialog.NoButton
    preferredWidth:  Kirigami.Units.gridUnit * 44
    preferredHeight: Kirigami.Units.gridUnit * 42

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
        return y + "-" + padTwo(m) + "-" + padTwo(d)
    }

    function doSave() {
        const startedAt   = editStartYear  > 0
            ? { year: editStartYear,  month: editStartMonth,  day: editStartDay  } : null
        const completedAt = editFinishYear > 0
            ? { year: editFinishYear, month: editFinishMonth, day: editFinishDay } : null

        anilistService.saveEntry(
            anilistId, editProgress, editStatus, editScore,
            startedAt   ? JSON.stringify(startedAt)   : "",
            completedAt ? JSON.stringify(completedAt) : "",
            editRewatches, editNotes, editPriority,
            editHideFromLists, editPrivate
        )
        listEditorDialog.entrySaved()
        listEditorDialog.close()
    }

    // ── Sub-dialogs ───────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id:       removeDialog
        title:    "Remove from list"
        subtitle: "Remove '" + listEditorDialog.animeTitle + "' from your list? This cannot be undone."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            anilistService.removeEntry(listEditorDialog.anilistId)
            listEditorDialog.entryRemoved()
            listEditorDialog.close()
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
                model: listEditorDialog.statusOptions
                delegate: Controls.ItemDelegate {
                    Layout.fillWidth: true
                    text:        modelData.label
                    highlighted: listEditorDialog.editStatus === modelData.id
                    onClicked: {
                        listEditorDialog.editStatus = modelData.id
                        statusSheet.close()
                    }
                }
            }
        }
    }

    component DatePickerDialog: Kirigami.Dialog {
        id: dpDialog
        property int  editYear:  0
        property int  editMonth: 1
        property int  editDay:   1
        property bool isStart:   true

        signal datePicked(int y, int m, int d)
        signal dateCleared()

        title: isStart ? "Start Date" : "Finish Date"
        standardButtons: Kirigami.Dialog.NoButton
        preferredWidth: Kirigami.Units.gridUnit * 22

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.gridUnit
                rowSpacing:    Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Controls.Label { text: "Year";  font.pixelSize: 13 }
                Controls.SpinBox {
                    Layout.fillWidth: true
                    from: 1900; to: 2100
                    value: dpDialog.editYear > 0 ? dpDialog.editYear : 2024
                    editable: true
                    onValueModified: dpDialog.editYear = value
                }
                Controls.Label { text: "Month"; font.pixelSize: 13 }
                Controls.SpinBox {
                    Layout.fillWidth: true
                    from: 1; to: 12
                    value: dpDialog.editMonth
                    editable: true
                    onValueModified: dpDialog.editMonth = value
                }
                Controls.Label { text: "Day";   font.pixelSize: 13 }
                Controls.SpinBox {
                    Layout.fillWidth: true
                    from: 1; to: 31
                    value: dpDialog.editDay
                    editable: true
                    onValueModified: dpDialog.editDay = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Controls.Button {
                    text: "Clear"
                    Layout.fillWidth: true
                    onClicked: { dpDialog.dateCleared(); dpDialog.close() }
                }
                Controls.Button {
                    text: "Set"
                    Layout.fillWidth: true
                    highlighted: true
                    onClicked: {
                        dpDialog.datePicked(dpDialog.editYear, dpDialog.editMonth, dpDialog.editDay)
                        dpDialog.close()
                    }
                }
            }
        }
    }

    DatePickerDialog {
        id: startDateDialog
        isStart:   true
        editYear:  listEditorDialog.editStartYear
        editMonth: listEditorDialog.editStartMonth > 0 ? listEditorDialog.editStartMonth : 1
        editDay:   listEditorDialog.editStartDay   > 0 ? listEditorDialog.editStartDay   : 1
        onDatePicked: (y, m, d) => {
            listEditorDialog.editStartYear  = y
            listEditorDialog.editStartMonth = m
            listEditorDialog.editStartDay   = d
        }
        onDateCleared: {
            listEditorDialog.editStartYear  = 0
            listEditorDialog.editStartMonth = 0
            listEditorDialog.editStartDay   = 0
        }
    }

    DatePickerDialog {
        id: finishDateDialog
        isStart:   false
        editYear:  listEditorDialog.editFinishYear
        editMonth: listEditorDialog.editFinishMonth > 0 ? listEditorDialog.editFinishMonth : 1
        editDay:   listEditorDialog.editFinishDay   > 0 ? listEditorDialog.editFinishDay   : 1
        onDatePicked: (y, m, d) => {
            listEditorDialog.editFinishYear  = y
            listEditorDialog.editFinishMonth = m
            listEditorDialog.editFinishDay   = d
        }
        onDateCleared: {
            listEditorDialog.editFinishYear  = 0
            listEditorDialog.editFinishMonth = 0
            listEditorDialog.editFinishDay   = 0
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Content
    // ═════════════════════════════════════════════════════════════════════════
    contentItem: Item {
        // Wrap in a ScrollView so very tall content stays reachable
        Controls.ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width  // must be explicit inside ScrollView
                spacing: 0

                // ── padding shim ─────────────────────────────────────────────
                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }

                // ╔══════════════════════════════╗
                // ║  G E N E R A L               ║
                // ╚══════════════════════════════╝
                SectionHeader { text: "General" }

                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

                EditorRow {
                    label: "Status"
                    Controls.Button {
                        text: listEditorDialog.statusLabel(listEditorDialog.editStatus)
                        Layout.fillWidth: true
                        onClicked: statusSheet.open()
                    }
                }

                EditorRow {
                    label: "Score"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        Controls.Slider {
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 5
                            value: listEditorDialog.editScore
                            onMoved: listEditorDialog.editScore = Math.round(value)
                        }
                        Controls.Label {
                            text:  (listEditorDialog.editScore / 10).toFixed(1)
                            color: listEditorDialog.editScore > 0
                                   ? Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.disabledTextColor
                            font { pixelSize: 14; bold: true }
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                EditorRow {
                    label: "Episode"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        Controls.SpinBox {
                            Layout.fillWidth: true
                            from: 0
                            to:   listEditorDialog.currentTotalEpisodes > 0
                                      ? listEditorDialog.currentTotalEpisodes : 9999
                            value:    listEditorDialog.editProgress
                            editable: true
                            onValueModified: listEditorDialog.editProgress = value
                        }
                        Controls.Label {
                            text:  "/ " + (listEditorDialog.currentTotalEpisodes > 0
                                           ? listEditorDialog.currentTotalEpisodes : "?")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 13
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                        }
                    }
                }

                EditorRow {
                    label: "Start Date"
                    Controls.Button {
                        Layout.fillWidth: true
                        text: listEditorDialog.dateString(
                            listEditorDialog.editStartYear,
                            listEditorDialog.editStartMonth,
                            listEditorDialog.editStartDay)
                        onClicked: startDateDialog.open()
                    }
                }

                EditorRow {
                    label: "Finish Date"
                    Controls.Button {
                        Layout.fillWidth: true
                        text: listEditorDialog.dateString(
                            listEditorDialog.editFinishYear,
                            listEditorDialog.editFinishMonth,
                            listEditorDialog.editFinishDay)
                        onClicked: finishDateDialog.open()
                    }
                }

                EditorRow {
                    label: "Rewatches"
                    Controls.SpinBox {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        from: 0; to: 9999
                        value:    listEditorDialog.editRewatches
                        editable: true
                        onValueModified: listEditorDialog.editRewatches = value
                    }
                }

                EditorRow {
                    label: "Notes"
                    Controls.TextArea {
                        Layout.fillWidth: true
                        Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                        placeholderText: "Add notes…"
                        text:            listEditorDialog.editNotes
                        wrapMode:        TextInput.WordWrap
                        onTextChanged:   listEditorDialog.editNotes = text
                    }
                }

                EditorRow {
                    label: "Priority"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        Controls.Slider {
                            Layout.fillWidth: true
                            from: 0; to: 5; stepSize: 1
                            value: listEditorDialog.editPriority
                            onMoved: listEditorDialog.editPriority = Math.round(value)
                        }
                        Controls.Label {
                            text:  listEditorDialog.editPriority === 0
                                   ? "None" : listEditorDialog.editPriority
                            color: listEditorDialog.editPriority > 0
                                   ? Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.disabledTextColor
                            font { pixelSize: 13; bold: listEditorDialog.editPriority > 0 }
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // ── gap between sections ──────────────────────────────────────
                Item { Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5 }

                // ╔══════════════════════════════╗
                // ║  O T H E R S                 ║
                // ╚══════════════════════════════╝
                SectionHeader { text: "Others" }

                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

                // Checkboxes: label on left, switch-style toggle on right
                ToggleRow {
                    label:     "Hide from status lists"
                    checked:   listEditorDialog.editHideFromLists
                    onToggled: listEditorDialog.editHideFromLists = checked
                }

                ToggleRow {
                    label:     "Private"
                    checked:   listEditorDialog.editPrivate
                    onToggled: listEditorDialog.editPrivate = checked
                }

                // ── bottom padding ────────────────────────────────────────────
                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
            }
        }
    }

    // ── Reusable row layouts ──────────────────────────────────────────────────

    // A labelled form row with generous vertical padding
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
            // Fixed width so all controls line up in one column
            Layout.minimumWidth: Kirigami.Units.gridUnit * 9
            Layout.maximumWidth: Kirigami.Units.gridUnit * 9
        }
    }

    // A toggle row — label fills, checkbox on the right
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

    // A bold section header with a separator beneath it
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
