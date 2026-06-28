import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: characterPage
    title: _data ? (_data.nameUserPreferred || _data.nameFull || "Character") : "Character"

    // ── Only prop needed from calling page ────────────────────────────────────
    property int characterId: 0

    // ── Internal ──────────────────────────────────────────────────────────────
    property var  _data:  null
    property string _revealedIds: ""   // comma-separated; change triggers text re-bind
    property bool _ready: false
    property bool _altSpoilerRevealed: false

    Component.onCompleted: {
        _ready = true
        _loadData()
    }

    onCharacterIdChanged: {
        if (_ready) _loadData()
    }

    function _loadData() {
        if (characterId > 0) {
            _revealedIds = ""
            _altSpoilerRevealed = false
            anilistService.fetchCharacterPage(characterId)
        }
    }

    // Convert AniList's Markdown subset to HTML for Text.RichText.
    // Order matters: bold (**) must be matched before italic (*).
    function markdownToHtml(src, revealed) {
        if (!src) return ""
        let s = src
        let count = 0
        const revList = revealed ? revealed.split(",") : []

        // Spoilers — must run before all other replacements
        s = s.replace(/~!([^!]+)!~/g, function(match, inner) {
            const id = "sp" + (count++)
            if (revList.indexOf(id) >= 0)
                return inner   // revealed: subsequent passes handle its markdown
            return '<a href="spoiler://' + id + '" style="text-decoration:none;">'
                + '<span style="background-color:#555555;color:#555555;'
                + 'border-radius:3px;padding:1px 4px;">click to reveal spoiler</span></a>'
        })

        s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
        s = s.replace(/\*\*([^*]+)\*\*/g,          '<b>$1</b>')
        s = s.replace(/__([^_]+)__/g,               '<b>$1</b>')
        s = s.replace(/\*([^*]+)\*/g,               '<i>$1</i>')
        s = s.replace(/_([^_\s][^_]*)_/g,           '<i>$1</i>')
        s = s.replace(/~~([^~]+)~~/g,               '<s>$1</s>')
        s = s.replace(/\n/g,                         '<br>')
        return s
    }

    Connections {
        target: anilistService

        function onCharacterPageLoaded(payloadJson) {
            const d = JSON.parse(payloadJson)
            if (d.characterId !== characterPage.characterId) return
            characterPage._data = d
            console.log(JSON.stringify(_data.description, null, 2))
        }

        function onCharacterFavouriteToggled(charId, newState) {
            if (charId !== characterPage.characterId) return
            anilistService.fetchCharacterPage(characterPage.characterId)
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

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            id: portraitRect
                            Layout.preferredWidth:  Kirigami.Units.gridUnit * 10
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
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

                        Controls.Button {
                            Layout.preferredWidth: portraitRect.width
                            Layout.maximumWidth:   portraitRect.width
                            enabled: _data ? !_data.isFavouriteBlocked : false
                            onClicked: anilistService.toggleCharacterFavourite(
                                characterPage.characterId, _data.isFavourite)

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source:         "love"
                                    isMask:         true
                                    color:          (_data && _data.isFavourite) ? "#e05562" : Kirigami.Theme.textColor
                                    implicitWidth:  Kirigami.Units.iconSizes.medium
                                    implicitHeight: Kirigami.Units.iconSizes.medium
                                    Layout.alignment:  Qt.AlignVCenter
                                    Layout.leftMargin: Kirigami.Units.largeSpacing
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text:             (_data && _data.isFavourite) ? "Favourited" : "Favourite"
                                    color:            (_data && _data.isFavourite) ? "#e05562" : Kirigami.Theme.textColor
                                    font:             parent.parent.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                            }
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

                        // Alternative name chips — wraps naturally at any width
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing:          Kirigami.Units.smallSpacing
                            visible: Boolean(
                                _data &&
                                ((Array.isArray(_data.nameAlternative)        && _data.nameAlternative.length > 0) ||
                                (Array.isArray(_data.nameAlternativeSpoiler) && _data.nameAlternativeSpoiler.length > 0))
                            )

                            // Regular alternative names
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

                            // Spoiler names — single obscured chip until clicked
                            Rectangle {
                                visible: Boolean(
                                    !characterPage._altSpoilerRevealed &&
                                    _data &&
                                    Array.isArray(_data.nameAlternativeSpoiler) &&
                                    _data.nameAlternativeSpoiler.length > 0
                                )
                                implicitHeight: spoilerHintLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                                implicitWidth:  spoilerHintLabel.implicitWidth  + Kirigami.Units.largeSpacing
                                radius: height / 2
                                color:  "#555555"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked:    characterPage._altSpoilerRevealed = true
                                }

                                Controls.Label {
                                    id:               spoilerHintLabel
                                    anchors.centerIn: parent
                                    text:             "click to reveal spoiler"
                                    font.pointSize:   Kirigami.Theme.defaultFont.pointSize * 0.85
                                    color:            "#555555"   // invisible on matching background
                                }
                            }

                            // Spoiler names — revealed chips
                            Repeater {
                                model: (characterPage._altSpoilerRevealed && _data && _data.nameAlternativeSpoiler)
                                    ? _data.nameAlternativeSpoiler : []

                                Rectangle {
                                    implicitHeight: spoilerChipLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                                    implicitWidth:  spoilerChipLabel.implicitWidth  + Kirigami.Units.largeSpacing
                                    radius: height / 2
                                    color:  Kirigami.Theme.alternateBackgroundColor

                                    Controls.Label {
                                        id:               spoilerChipLabel
                                        anchors.centerIn: parent
                                        text:             modelData
                                        font.pointSize:   Kirigami.Theme.defaultFont.pointSize * 0.85
                                        color:            Kirigami.Theme.textColor
                                    }
                                }
                            }
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
                            const _rev = characterPage._revealedIds
                            const raw  = _data ? (_data.description || "") : ""
                            const body = characterPage.markdownToHtml(raw, _rev)
                            return '<style>a { color: %1; text-decoration: underline; }</style>'
                                   .arg(descriptionLabel.palette.link) + body
                        }
                        onLinkActivated: function(link) {
                            if (link.startsWith("spoiler://")) {
                                const id = link.slice("spoiler://".length)
                                const cur = characterPage._revealedIds

                                if (cur.split(",").indexOf(id) < 0)
                                    characterPage._revealedIds = cur ? cur + "," + id : id

                                return
                            }

                            const charMatch  = link.match(/anilist\.co\/character\/(\d+)/)
                            const animeMatch = link.match(/anilist\.co\/anime\/(\d+)/)
                            const mangaMatch = link.match(/anilist\.co\/manga\/(\d+)/)

                            if (charMatch) {
                                pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                                    characterId: parseInt(charMatch[1])
                                })
                            } else if (animeMatch) {
                                pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), {
                                    anilistId: parseInt(animeMatch[1])
                                })
                            } else if (mangaMatch) {
                                pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), {
                                    anilistId: parseInt(mangaMatch[1])
                                })
                            } else {
                                Qt.openUrlExternally(link)
                            }
                        }
                        wrapMode:        Text.WordWrap
                        textFormat:      Text.RichText
                        color:           Kirigami.Theme.textColor
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

                            MediaCoverCard {
                                mediaId:  modelData.mediaId
                                title:    modelData.title || ""
                                imageURL: modelData.cover || ""
                                onTapped: {
                                    console.log("MediaCoverCard Clicked!")
                                    if (modelData.type === "ANIME")
                                        pageStack.layers.push(Qt.resolvedUrl("AnimePage.qml"), { animeId: modelData.mediaId })
                                    else if (modelData.type === "MANGA")
                                        pageStack.layers.push(Qt.resolvedUrl("MangaPage.qml"), { anilistId: modelData.mediaId })
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
