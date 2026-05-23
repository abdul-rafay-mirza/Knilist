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
        onDatePicked:  (y, m, d) => { listEditorDialog.editStartYear = y; listEditorDialog.editStartMonth = m; listEditorDialog.editStartDay = d }
        onDateCleared: { listEditorDialog.editStartYear = 0; listEditorDialog.editStartMonth = 0; listEditorDialog.editStartDay = 0 }
    }

    DatePickerDialog {
        id: finishDateDialog
        isStart:   false
        editYear:  listEditorDialog.editFinishYear
        editMonth: listEditorDialog.editFinishMonth > 0 ? listEditorDialog.editFinishMonth : 1
        editDay:   listEditorDialog.editFinishDay   > 0 ? listEditorDialog.editFinishDay   : 1
        onDatePicked:  (y, m, d) => { listEditorDialog.editFinishYear = y; listEditorDialog.editFinishMonth = m; listEditorDialog.editFinishDay = d }
        onDateCleared: { listEditorDialog.editFinishYear = 0; listEditorDialog.editFinishMonth = 0; listEditorDialog.editFinishDay = 0 }
    }

    // Validators — declared at dialog scope so the TextField can reference them
    IntValidator {
        id: intValidator
        bottom: 0
        top: Math.round(anilistService.scoreMax())
    }
    DoubleValidator {
        id: doubleValidator
        bottom: 0
        top: anilistService.scoreMax()
        decimals: 1
        notation: DoubleValidator.StandardNotation
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Content
    // ═════════════════════════════════════════════════════════════════════════
    contentItem: Item {
        Controls.ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 0

                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }

                // ── GENERAL ───────────────────────────────────────────────────
                SectionHeader { text: "General" }
                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

                // Status
                EditorRow {
                    label: "Status"
                    Controls.Button {
                        Layout.fillWidth: true
                        text: listEditorDialog.statusLabel(listEditorDialog.editStatus)
                        onClicked: statusSheet.open()
                    }
                }

                // Score — the control area is a plain Item acting as a switcher;
                // only one child is visible at a time, avoiding multi-RowLayout conflicts.
                EditorRow {
                    label: "Score"

                    Item {
                        Layout.fillWidth: true
                        // Height comes from whichever child is visible
                        implicitHeight: scoreFmt === "POINT_5"
                                        ? starRow.implicitHeight
                                        : scoreFmt === "POINT_3"
                                          ? smileyRow.implicitHeight
                                          : numericRow.implicitHeight

                        // ── POINT_5: five stars ───────────────────────────────
                        Row {
                            id: starRow
                            visible: listEditorDialog.scoreFmt === "POINT_5"
                            spacing: 4

                            Repeater {
                                model: 5
                                delegate: Controls.AbstractButton {
                                    readonly property int  starValue: modelData + 1
                                    readonly property bool filled: listEditorDialog.editScore >= starValue
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
                                    onClicked: listEditorDialog.editScore =
                                        (listEditorDialog.editScore === starValue) ? 0 : starValue
                                }
                            }

                            Controls.Label {
                                visible: listEditorDialog.editScore > 0
                                text:    "(" + listEditorDialog.editScore + " / 5)"
                                color:   Kirigami.Theme.disabledTextColor
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // ── POINT_3: smileys ──────────────────────────────────
                        Row {
                            id: smileyRow
                            visible: listEditorDialog.scoreFmt === "POINT_3"
                            spacing: Kirigami.Units.largeSpacing

                            Repeater {
                                model: [
                                    { val: 1, face: ":(", tip: "Bad"  },
                                    { val: 2, face: ":|", tip: "Okay" },
                                    { val: 3, face: ":)", tip: "Good" },
                                ]
                                delegate: Controls.Button {
                                    readonly property bool active: listEditorDialog.editScore === modelData.val
                                    text:        modelData.face
                                    highlighted: active
                                    font.pixelSize: 18
                                    Controls.ToolTip.visible: hovered
                                    Controls.ToolTip.text:    modelData.tip
                                    onClicked: listEditorDialog.editScore = active ? 0 : modelData.val
                                }
                            }

                            Controls.Label {
                                visible: listEditorDialog.editScore === 0
                                text:    "Not rated"
                                color:   Kirigami.Theme.disabledTextColor
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // ── POINT_100 / POINT_10 / POINT_10_DECIMAL ───────────
                        Row {
                            id: numericRow
                            visible: listEditorDialog.scoreFmt !== "POINT_5"
                                  && listEditorDialog.scoreFmt !== "POINT_3"
                            spacing: Kirigami.Units.smallSpacing

                            Controls.TextField {
                                id: scoreField
                                width: Kirigami.Units.gridUnit * 7
                                placeholderText: "0"
                                horizontalAlignment: Text.AlignHCenter
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                validator: listEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                           ? doubleValidator : intValidator

                                text: listEditorDialog.editScore > 0
                                      ? (listEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                         ? listEditorDialog.editScore.toFixed(1)
                                         : String(Math.round(listEditorDialog.editScore)))
                                      : ""

                                onEditingFinished: {
                                    const v = parseFloat(text)
                                    const max = anilistService.scoreMax()
                                    listEditorDialog.editScore =
                                        (!isNaN(v) && v >= 0 && v <= max) ? v : 0
                                }
                            }

                            Controls.Label {
                                text:  listEditorDialog.scoreSuffix[listEditorDialog.scoreFmt] ?? ""
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
                            to: listEditorDialog.currentTotalEpisodes > 0
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

                // Start Date
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

                // Finish Date
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

                // Rewatches
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

                // Notes
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

                // Priority
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
                            text:  listEditorDialog.editPriority === 0 ? "None"
                                   : listEditorDialog.editPriority
                            color: listEditorDialog.editPriority > 0
                                   ? Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.disabledTextColor
                            font { pixelSize: 13; bold: listEditorDialog.editPriority > 0 }
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // ── OTHERS ────────────────────────────────────────────────────
                Item { Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5 }
                SectionHeader { text: "Others" }
                Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

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

                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
            }
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
            Layout.minimumWidth: Kirigami.Units.gridUnit * 9
            Layout.maximumWidth: Kirigami.Units.gridUnit * 9
            Layout.alignment: Qt.AlignVCenter
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
