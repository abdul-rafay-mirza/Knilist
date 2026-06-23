// SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
// SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later
// Modified version of the above

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as Components

/**
 * A popup that prompts the user to select a date.
 * Drop this file into your project and keep DatePicker.qml beside it.
 */
Controls.Dialog {
    id: root

    property date value: new Date()
    property date minimumDate
    property date maximumDate
    property bool autoAccept: false

    // Change this from the outside
    property int popupWidth: 300

    signal cancelled()

    width: popupWidth
    implicitWidth: popupWidth

    padding: 0
    topPadding: 0
    leftPadding: 0
    rightPadding: 0
    bottomPadding: 0
    verticalPadding: 0
    horizontalPadding: 0

    header: null

    contentItem: DatePicker {
        id: datePicker

        width: root.width
        minimumDate: root.minimumDate
        maximumDate: root.maximumDate
        selectedDate: root.value
        focus: true

        onDatePicked: (pickedDate) => {
            if (root.autoAccept) {
                root.value = pickedDate
                root.accept()
            }
        }
    }

    footer: Controls.DialogButtonBox {
        visible: !root.autoAccept

        leftPadding: Kirigami.Units.mediumSpacing
        rightPadding: Kirigami.Units.mediumSpacing
        bottomPadding: Kirigami.Units.mediumSpacing

        Controls.Button {
            text: "Cancel"
            icon.name: "dialog-cancel-symbolic"

            onClicked: {
                root.cancelled()
                root.reject()
            }
        }

        Controls.Button {
            text: "Select"
            icon.name: "dialog-ok-apply-symbolic"

            onClicked: {
                root.value = datePicker.selectedDate
                root.accept()
            }
        }
    }

    background: Components.DialogRoundedBackground {}

    Controls.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.3)

        Behavior on opacity {
            OpacityAnimator {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
}