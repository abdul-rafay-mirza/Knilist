import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: characterPage
    title: _data ? (_data.nameUserPreferred || _data.nameFull || "Character") : "Character"

    // ── Only prop needed from calling page ────────────────────────────────────
    property int characterId: 0

    // ── Internal ──────────────────────────────────────────────────────────────
    property var  _data:  null
    property bool _ready: false

    Component.onCompleted: {
        _ready = true
        _loadData()
    }

    onCharacterIdChanged: {
        if (_ready) _loadData()
    }

    function _loadData() {
        if (characterId > 0)
            anilistService.fetchCharacterPage(characterId)
    }

    // Convert AniList's Markdown subset to HTML for Text.RichText.
    // Order matters: bold (**) must be matched before italic (*).
    function markdownToHtml(src) {
        if (!src) return ""
        let s = src
        s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>') // [text](url)
        s = s.replace(/\*\*([^*]+)\*\*/g,          '<b>$1</b>')           // **bold**
        s = s.replace(/__([^_]+)__/g,               '<b>$1</b>')           // __bold__
        s = s.replace(/\*([^*]+)\*/g,               '<i>$1</i>')           // *italic*
        s = s.replace(/_([^_\s][^_]*)_/g,           '<i>$1</i>')           // _italic_ (guard against lone underscores in words)
        s = s.replace(/~~([^~]+)~~/g,               '<s>$1</s>')           // ~~strike~~
        s = s.replace(/\n/g,                         '<br>')                // newlines
        return s
    }

    Connections {
        target: anilistService

        function onCharacterPageLoaded(payloadJson) {
            const d = JSON.parse(payloadJson)
            if (d.characterId !== characterPage.characterId) return
            characterPage._data = d
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
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
                id:    mainColumn
                width: parent.width
                spacing: 0

                // ── Hero: portrait + primary info ─────────────────────────────
                RowLayout {
                    Layout.fillWidth:    true
                    Layout.topMargin:    Kirigami.Units.largeSpacing
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.largeSpacing

                    Rectangle {
                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 8
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                        Layout.alignment:       Qt.AlignTop
                        radius: Kirigami.Units.cornerRadius
                        clip:   true
                        color:  Kirigami.Theme.alternateBackgroundColor

                        Image {
                            anchors.fill: parent
                            source:       _data ? (_data.image || "") : ""
                            fillMode:     Image.PreserveAspectCrop
                            asynchronous: true
                            mipmap:       true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing:          Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level:            2
                            text:             _data ? (_data.nameFull || "") : ""
                            wrapMode:         Text.WordWrap
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            visible:          Boolean(_data && _data.nameNative)
                            text:             _data ? (_data.nameNative || "") : ""
                            color:            Kirigami.Theme.disabledTextColor
                            wrapMode:         Text.WordWrap
                        }

                        Kirigami.Separator {
                            Layout.fillWidth:    true
                            Layout.topMargin:    Kirigami.Units.smallSpacing
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                            visible: _data !== null
                        }

                        // Only renders rows for fields that actually exist
                        Repeater {
                            model: {
                                if (!_data) return []
                                const rows = []
                                if (_data.gender)      rows.push({ label: "Gender",     value: _data.gender })
                                if (_data.age)         rows.push({ label: "Age",         value: String(_data.age) })
                                if (_data.dateOfBirth) rows.push({ label: "Birthday",    value: _data.dateOfBirth })
                                if (_data.bloodType)   rows.push({ label: "Blood type",  value: _data.bloodType })
                                return rows
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          Kirigami.Units.largeSpacing

                                Controls.Label {
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                                    text:           modelData.label
                                    color:          Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text:           modelData.value
                                    color:          Kirigami.Theme.textColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                    wrapMode:       Text.WordWrap
                                }
                            }
                        }

                        // Alternative name chips — wraps naturally at any width
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing:          Kirigami.Units.smallSpacing
                            visible: Boolean(
                                _data &&
                                Array.isArray(_data.nameAlternative) &&
                                _data.nameAlternative.length > 0
                            )

                            Repeater {
                                model: (_data && _data.nameAlternative) ? _data.nameAlternative : []

                                Rectangle {
                                    implicitHeight: chipLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                                    implicitWidth:  chipLabel.implicitWidth  + Kirigami.Units.largeSpacing
                                    radius: height / 2
                                    color:  Kirigami.Theme.alternateBackgroundColor

                                    Controls.Label {
                                        id:               chipLabel
                                        anchors.centerIn: parent
                                        text:             modelData
                                        font.pointSize:   Kirigami.Theme.defaultFont.pointSize * 0.85
                                        color:            Kirigami.Theme.textColor
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Description ───────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.description)

                    Kirigami.Heading {
                        level: 3
                        text:  "About"
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Controls.Label {
                        id:               descriptionLabel
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        // Inline <style> colours links from the system palette so they
                        // look correct in both light and dark Plasma themes.
                        text: {
                            const raw  = _data ? (_data.description || "") : ""
                            const body = characterPage.markdownToHtml(raw)
                            return '<style>a { color: %1; text-decoration: underline; }</style>'
                                   .arg(descriptionLabel.palette.link) + body
                        }
                        wrapMode:        Text.WordWrap
                        textFormat:      Text.RichText
                        color:           Kirigami.Theme.textColor
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }

                // ── Appearances ───────────────────────────────────────────────
                // Cards wrap freely; the outer Flickable handles scrolling
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.media && _data.media.length > 0)

                    Kirigami.Heading {
                        level: 3
                        text:  "Appearances"
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing:          Kirigami.Units.largeSpacing

                        Repeater {
                            model: (_data && _data.media) ? _data.media : []

                            // Fixed-width column; Flow wraps when it can't fit another
                            ColumnLayout {
                                width:   Kirigami.Units.gridUnit * 6
                                spacing: Kirigami.Units.smallSpacing

                                Rectangle {
                                    Layout.preferredWidth:  Kirigami.Units.gridUnit * 6
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 9
                                    radius: Kirigami.Units.cornerRadius
                                    clip:   true
                                    color:  Kirigami.Theme.alternateBackgroundColor

                                    Image {
                                        anchors.fill: parent
                                        source:       modelData.cover || ""
                                        fillMode:     Image.PreserveAspectCrop
                                        asynchronous: true
                                        mipmap:       true
                                    }
                                }

                                Controls.Label {
                                    Layout.fillWidth:    true
                                    text:               modelData.title || ""
                                    wrapMode:           Text.WordWrap
                                    maximumLineCount:   2
                                    elide:              Text.ElideRight
                                    font.pointSize:     Kirigami.Theme.defaultFont.pointSize * 0.85
                                    color:              Kirigami.Theme.textColor
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: Kirigami.Units.largeSpacing * 2
                }
            }
        }

        // Dimming overlay during loading
        Rectangle {
            anchors.fill: parent
            visible:      anilistService.loading
            color:        Kirigami.Theme.backgroundColor
            opacity:      0.6
            z:            2

            MouseArea {
                anchors.fill: parent
                enabled:      anilistService.loading
                hoverEnabled: true
            }

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running:          true
            }
        }
    }
}
