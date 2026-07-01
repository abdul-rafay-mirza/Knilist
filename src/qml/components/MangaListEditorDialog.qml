import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "date_picker"

Kirigami.Dialog {
    id: mangaListEditorDialog

    // ── Public API ────────────────────────────────────────────────────────────
    property int    anilistId
    property string mangaTitle
    property string currentStatus
    property real   currentScore
    property int    currentChapters        // progress (chapters read)
    property int    currentVolumes         // progressVolumes
    property int    currentTotalChapters   // media.chapters
    property int    currentTotalVolumes    // media.volumes
    property int    currentStartYear
    property int    currentStartMonth
    property int    currentStartDay
    property int    currentFinishYear
    property int    currentFinishMonth
    property int    currentFinishDay
    property int    currentRereads
    property string currentNotes
    property int    currentPriority
    property bool   currentHideFromLists
    property bool   currentPrivate

    signal entrySaved()
    signal entryRemoved()

    // ── Editable state ────────────────────────────────────────────────────────
    property string editStatus:        currentStatus
    property real   editScore:         0
    property int    editChapters:      currentChapters
    property int    editVolumes:       currentVolumes
    property int    editStartYear:     currentStartYear
    property int    editStartMonth:    currentStartMonth
    property int    editStartDay:      currentStartDay
    property int    editFinishYear:    currentFinishYear
    property int    editFinishMonth:   currentFinishMonth
    property int    editFinishDay:     currentFinishDay
    property int    editRereads:       currentRereads
    property string editNotes:         currentNotes
    property int    editPriority:      currentPriority
    property bool   editHideFromLists: currentHideFromLists
    property bool   editPrivate:       currentPrivate

    readonly property string scoreFmt: anilistService.scoreFormat

    onOpened: {
        editStatus        = currentStatus
        editScore         = currentScore
        editChapters      = currentChapters
        editVolumes       = currentVolumes
        editStartYear     = currentStartYear
        editStartMonth    = currentStartMonth
        editStartDay      = currentStartDay
        editFinishYear    = currentFinishYear
        editFinishMonth   = currentFinishMonth
        editFinishDay     = currentFinishDay
        editRereads       = currentRereads
        editNotes         = currentNotes
        editPriority      = currentPriority
        editHideFromLists = currentHideFromLists
        editPrivate       = currentPrivate
    }

    // ── Dialog chrome ─────────────────────────────────────────────────────────
    title:           ""
    standardButtons: Kirigami.Dialog.NoButton

    width:  Math.min(Kirigami.Units.gridUnit * 46,
                     applicationWindow().width  * 0.9)
    height: Math.min(Kirigami.Units.gridUnit * 46,
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
        { id: "CURRENT",   label: "Reading"    },
        { id: "REPEATING", label: "Rereading"  },
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

        anilistService.saveMangaEntry(
            anilistId,
            editChapters,
            editVolumes,
            editStatus,
            editScore,
            startedAt   ? JSON.stringify(startedAt)   : "",
            completedAt ? JSON.stringify(completedAt) : "",
            editRereads,
            editNotes,
            editPriority,
            editHideFromLists,
            editPrivate
        )
        mangaListEditorDialog.entrySaved()
        mangaListEditorDialog.close()
    }

    // ── Sub-dialogs ───────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id:       removeDialog
        title:    "Remove from list"
        subtitle: "Remove '" + mangaListEditorDialog.mangaTitle + "' from your list? This cannot be undone."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            anilistService.removeMangaEntry(mangaListEditorDialog.anilistId)
            mangaListEditorDialog.entryRemoved()
            mangaListEditorDialog.close()
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
                model: mangaListEditorDialog.statusOptions
                delegate: Controls.ItemDelegate {
                    Layout.fillWidth: true
                    text:        modelData.label
                    highlighted: mangaListEditorDialog.editStatus === modelData.id
                    onClicked: {
                        mangaListEditorDialog.editStatus = modelData.id
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
            width: mangaListEditorDialog.width
                   - mangaListEditorDialog.leftPadding
                   - mangaListEditorDialog.rightPadding
            spacing: 0

            // ── Title ─────────────────────────────────────────────────────────
            Controls.Label {
                Layout.fillWidth:    true
                Layout.leftMargin:   Kirigami.Units.gridUnit
                Layout.rightMargin:  Kirigami.Units.gridUnit
                Layout.topMargin:    Kirigami.Units.gridUnit
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                text:     mangaListEditorDialog.mangaTitle
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
                    text: mangaListEditorDialog.statusLabel(mangaListEditorDialog.editStatus)
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
                        visible: mangaListEditorDialog.scoreFmt === "POINT_5"
                        spacing: 4
                        Repeater {
                            model: 5
                            delegate: Controls.AbstractButton {
                                readonly property int  starValue: modelData + 1
                                readonly property bool filled: mangaListEditorDialog.editScore >= starValue
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
                                onClicked: mangaListEditorDialog.editScore =
                                    (mangaListEditorDialog.editScore === starValue) ? 0 : starValue
                            }
                        }
                        Controls.Label {
                            visible: mangaListEditorDialog.editScore > 0
                            text:    "(" + mangaListEditorDialog.editScore + " / 5)"
                            color:   Kirigami.Theme.disabledTextColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: smileyRow
                        visible: mangaListEditorDialog.scoreFmt === "POINT_3"
                        spacing: Kirigami.Units.largeSpacing
                        Repeater {
                            model: [
                                { val: 1, face: ":(", tip: "Bad"  },
                                { val: 2, face: ":|", tip: "Okay" },
                                { val: 3, face: ":)", tip: "Good" },
                            ]
                            delegate: Controls.Button {
                                readonly property bool active: mangaListEditorDialog.editScore === modelData.val
                                text:        modelData.face
                                highlighted: active
                                font.pixelSize: 18
                                Controls.ToolTip.visible: hovered
                                Controls.ToolTip.text:    modelData.tip
                                onClicked: mangaListEditorDialog.editScore = active ? 0 : modelData.val
                            }
                        }
                        Controls.Label {
                            visible: mangaListEditorDialog.editScore === 0
                            text:    "Not rated"
                            color:   Kirigami.Theme.disabledTextColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: numericRow
                        visible: mangaListEditorDialog.scoreFmt !== "POINT_5"
                              && mangaListEditorDialog.scoreFmt !== "POINT_3"
                        spacing: Kirigami.Units.smallSpacing
                        Controls.TextField {
                            id: scoreField
                            width: Kirigami.Units.gridUnit * 7
                            placeholderText: "0"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: mangaListEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                       ? doubleValidator : intValidator
                            text: mangaListEditorDialog.editScore > 0
                                  ? (mangaListEditorDialog.scoreFmt === "POINT_10_DECIMAL"
                                     ? mangaListEditorDialog.editScore.toFixed(1)
                                     : String(Math.round(mangaListEditorDialog.editScore)))
                                  : ""
                            onEditingFinished: {
                                const v   = parseFloat(text)
                                const max = anilistService.scoreMax()
                                mangaListEditorDialog.editScore =
                                    (!isNaN(v) && v >= 0 && v <= max) ? v : 0
                            }
                        }
                        Controls.Label {
                            text:  mangaListEditorDialog.scoreSuffix[mangaListEditorDialog.scoreFmt] ?? ""
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Chapter
            EditorRow {
                label: "Chapter"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Controls.SpinBox {
                        Layout.fillWidth: true
                        from: 0
                        to: mangaListEditorDialog.currentTotalChapters > 0
                                ? mangaListEditorDialog.currentTotalChapters : 99999
                        value:    mangaListEditorDialog.editChapters
                        editable: true
                        onValueModified: mangaListEditorDialog.editChapters = value
                    }
                    Controls.Label {
                        text:  "/ " + (mangaListEditorDialog.currentTotalChapters > 0
                                       ? mangaListEditorDialog.currentTotalChapters : "?")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: 13
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                    }
                }
            }

            // Volume
            EditorRow {
                label: "Volume"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Controls.SpinBox {
                        Layout.fillWidth: true
                        from: 0
                        to: mangaListEditorDialog.currentTotalVolumes > 0
                                ? mangaListEditorDialog.currentTotalVolumes : 9999
                        value:    mangaListEditorDialog.editVolumes
                        editable: true
                        onValueModified: mangaListEditorDialog.editVolumes = value
                    }
                    Controls.Label {
                        text:  "/ " + (mangaListEditorDialog.currentTotalVolumes > 0
                                       ? mangaListEditorDialog.currentTotalVolumes : "?")
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
                    mangaListEditorDialog.editStartYear  = value.getFullYear()
                    mangaListEditorDialog.editStartMonth = value.getMonth() + 1
                    mangaListEditorDialog.editStartDay   = value.getDate()
                }
            }

            DatePopup {
                id: finishDatePopup
                popupWidth: Kirigami.Units.gridUnit * 24
                onAccepted: {
                    mangaListEditorDialog.editFinishYear  = value.getFullYear()
                    mangaListEditorDialog.editFinishMonth = value.getMonth() + 1
                    mangaListEditorDialog.editFinishDay   = value.getDate()
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
                        text: mangaListEditorDialog.dateString(
                            mangaListEditorDialog.editStartYear,
                            mangaListEditorDialog.editStartMonth,
                            mangaListEditorDialog.editStartDay)
                        onClicked: {
                            startDatePopup.value = mangaListEditorDialog.editStartYear > 0
                                ? new Date(mangaListEditorDialog.editStartYear,
                                        mangaListEditorDialog.editStartMonth - 1,
                                        mangaListEditorDialog.editStartDay)
                                : new Date()
                            startDatePopup.open()
                        }
                    }
                    Controls.Button {
                        icon.name: "edit-clear-symbolic"
                        visible: mangaListEditorDialog.editStartYear > 0
                        Controls.ToolTip.text: "Clear"
                        Controls.ToolTip.visible: hovered
                        onClicked: {
                            mangaListEditorDialog.editStartYear  = 0
                            mangaListEditorDialog.editStartMonth = 0
                            mangaListEditorDialog.editStartDay   = 0
                        }
                    }
                }
            }

            // Finish Date
            EditorRow {
                label: "Finish Date"
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Button {
                        Layout.fillWidth: true
                        text: mangaListEditorDialog.dateString(
                            mangaListEditorDialog.editFinishYear,
                            mangaListEditorDialog.editFinishMonth,
                            mangaListEditorDialog.editFinishDay)
                        onClicked: {
                            finishDatePopup.value = mangaListEditorDialog.editFinishYear > 0
                                ? new Date(mangaListEditorDialog.editFinishYear,
                                        mangaListEditorDialog.editFinishMonth - 1,
                                        mangaListEditorDialog.editFinishDay)
                                : new Date()
                            finishDatePopup.open()
                        }
                    }
                    Controls.Button {
                        icon.name: "edit-clear-symbolic"
                        visible: mangaListEditorDialog.editFinishYear > 0
                        Controls.ToolTip.text: "Clear"
                        Controls.ToolTip.visible: hovered
                        onClicked: {
                            mangaListEditorDialog.editFinishYear  = 0
                            mangaListEditorDialog.editFinishMonth = 0
                            mangaListEditorDialog.editFinishDay   = 0
                        }
                    }
                }
            }

            // Total Rereads
            EditorRow {
                label: "Total Rereads"
                Controls.SpinBox {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    from: 0; to: 9999
                    value:    mangaListEditorDialog.editRereads
                    editable: true
                    onValueModified: mangaListEditorDialog.editRereads = value
                }
            }

            // Notes
            EditorRow {
                label: "Notes"
                Controls.TextArea {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                    placeholderText: "Add notes…"
                    text:            mangaListEditorDialog.editNotes
                    wrapMode:        TextInput.WordWrap
                    onTextChanged:   mangaListEditorDialog.editNotes = text
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
                        value: mangaListEditorDialog.editPriority
                        onMoved: mangaListEditorDialog.editPriority = Math.round(value)
                    }
                    Controls.Label {
                        text:  mangaListEditorDialog.editPriority === 0 ? "None"
                               : mangaListEditorDialog.editPriority
                        color: mangaListEditorDialog.editPriority > 0
                               ? Kirigami.Theme.highlightColor
                               : Kirigami.Theme.disabledTextColor
                        font { pixelSize: 13; bold: mangaListEditorDialog.editPriority > 0 }
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
                checked:   mangaListEditorDialog.editHideFromLists
                onToggled: mangaListEditorDialog.editHideFromLists = checked
            }

            ToggleRow {
                label:     "Private"
                checked:   mangaListEditorDialog.editPrivate
                onToggled: mangaListEditorDialog.editPrivate = checked
            }

            Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
        }
    }

    // ── Inline components — identical to AnimeListEditorDialog ────────────────
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
