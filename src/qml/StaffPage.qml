import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: staffPage
    title: _data ? (_data.nameUserPreferred || _data.nameFull || "Staff") : "Staff"

    // ── Only prop needed from calling page ────────────────────────────────────
    property int staffId: 0

    // ── Internal ──────────────────────────────────────────────────────────────
    property var    _data:        null
    property bool   _ready:       false
    property bool _mediaHasNext:   false
    property bool _charHasNext:    false
    property int  _nextMediaPage:  2
    property int  _nextCharPage:   2
    property bool _isFetchingMore: false

    Component.onCompleted: {
        _ready = true
        _loadData()
    }

    onStaffIdChanged: {
        if (_ready) _loadData()
    }

    function _loadData() {
        if (staffId > 0) {
            anilistService.fetchStaffPage(staffId)
        }
    }

    function _loadMore() {
        if (_isFetchingMore || (!_mediaHasNext && !_charHasNext)) return
        _isFetchingMore = true
        anilistService.fetchStaffPageMore(
            staffId,
            _mediaHasNext ? _nextMediaPage : 0,
            _charHasNext  ? _nextCharPage  : 0
        )
    }

    Connections {
        target: anilistService

        function onStaffPageLoaded(payloadJson) {
            const d = JSON.parse(payloadJson)
            if (d.staffId !== staffPage.staffId) return
            staffPage._data          = d
            staffPage._mediaHasNext  = d.mediaHasNext  || false
            staffPage._charHasNext   = d.charHasNext   || false
            staffPage._nextMediaPage = 2
            staffPage._nextCharPage  = 2
            staffPage._isFetchingMore = false
        }

        function onStaffPageMoreLoaded(payloadJson) {
            const d = JSON.parse(payloadJson)
            if (d.staffId !== staffPage.staffId) return

            if (!d.isError) {
                const updated = Object.assign({}, staffPage._data)
                if (d.staffMedia.length > 0)
                    updated.staffMedia = (staffPage._data.staffMedia || []).concat(d.staffMedia)
                if (d.characters.length > 0)
                    updated.characters = (staffPage._data.characters || []).concat(d.characters)
                staffPage._data = updated

                staffPage._mediaHasNext = d.mediaHasNext
                staffPage._nextMediaPage++
                staffPage._charHasNext  = d.charHasNext
                staffPage._nextCharPage++
            }
            staffPage._isFetchingMore = false
        }

        function onStaffFavouriteToggled(sId, newState) {
            if (sId !== staffPage.staffId) return
            anilistService.fetchStaffPage(staffPage.staffId)
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

            onContentYChanged: {
                if (!staffPage._isFetchingMore &&
                    (staffPage._mediaHasNext || staffPage._charHasNext) &&
                    staffPage._data !== null &&
                    contentY + height >= contentHeight - Kirigami.Units.gridUnit * 20) {
                    staffPage._loadMore()
                }
            }

            ColumnLayout {
                id:      mainColumn
                width:   parent.width
                spacing: 0

                // ── Hero: portrait + primary info ─────────────────────────────
                RowLayout {
                    Layout.fillWidth:    true
                    Layout.topMargin:    Kirigami.Units.largeSpacing
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.largeSpacing

                    // Left: portrait + favourite button
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing:          Kirigami.Units.smallSpacing

                        Rectangle {
                            id:                     portraitRect
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
                            onClicked: {
                                console.log("Staff Favourite Button Clicked!")
                                anilistService.toggleStaffFavourite(staffPage.staffId, _data.isFavourite)
                            }

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
                                    Layout.fillWidth:    true
                                    text:                (_data && _data.isFavourite) ? "Favourited" : "Favourite"
                                    color:               (_data && _data.isFavourite) ? "#e05562" : Kirigami.Theme.textColor
                                    font:                parent.parent.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // Right: name, alt names, info rows
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
                            visible:             _data !== null
                        }

                        // Alternative name chips
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
                                    implicitHeight: altChipLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                                    implicitWidth:  altChipLabel.implicitWidth  + Kirigami.Units.largeSpacing
                                    radius: height / 2
                                    color:  Kirigami.Theme.alternateBackgroundColor

                                    Controls.Label {
                                        id:               altChipLabel
                                        anchors.centerIn: parent
                                        text:             modelData
                                        font.pointSize:   Kirigami.Theme.defaultFont.pointSize * 0.85
                                        color:            Kirigami.Theme.textColor
                                    }
                                }
                            }
                        }

                        // Info rows — only rendered for non-empty fields
                        Repeater {
                            model: {
                                if (!_data) return []
                                const rows = []
                                if (_data.language)
                                    rows.push({ label: "Language",     value: _data.language })
                                if (_data.primaryOccupations && _data.primaryOccupations.length > 0)
                                    rows.push({ label: "Occupation",   value: _data.primaryOccupations.join(", ") })
                                if (_data.gender)
                                    rows.push({ label: "Gender",       value: _data.gender })
                                if (_data.age)
                                    rows.push({ label: "Age",          value: String(_data.age) })
                                if (_data.dateOfBirth)
                                    rows.push({ label: "Birthday",     value: _data.dateOfBirth })
                                if (_data.dateOfDeath)
                                    rows.push({ label: "Death date",   value: _data.dateOfDeath })
                                if (_data.yearsActive && _data.yearsActive.length > 0)
                                    // yearsActive is [startYear] or [startYear, endYear]
                                    rows.push({ label: "Years active", value: _data.yearsActive.join("–") })
                                if (_data.homeTown)
                                    rows.push({ label: "Hometown",     value: _data.homeTown })
                                if (_data.bloodType)
                                    rows.push({ label: "Blood type",   value: _data.bloodType })
                                return rows
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          Kirigami.Units.largeSpacing

                                Controls.Label {
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                                    text:           modelData.label
                                    color:          Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text:             modelData.value
                                    color:            Kirigami.Theme.textColor
                                    font.pointSize:   Kirigami.Theme.defaultFont.pointSize * 0.9
                                    wrapMode:         Text.WordWrap
                                }
                            }
                        }
                    }
                }

                // ── About (description with spoiler support) ──────────────────
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.description)

                    Kirigami.Heading { level: 3; text: "About" }

                    Kirigami.Separator { Layout.fillWidth: true }

                    AniListDescription {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        description:      _data ? (_data.description || "") : ""
                    }
                }

                // ── Voice Roles ───────────────────────────────────────────────
                // Only visible for voice actors; each card shows character image,
                // name, and the first media the character appeared in.
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.characters && _data.characters.length > 0)

                    Kirigami.Heading { level: 3; text: "Voice Roles" }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing:          Kirigami.Units.largeSpacing

                        Repeater {
                            model: (_data && _data.characters) ? _data.characters : []

                            // Inline character card — same footprint as MediaCoverCard
                            Item {
                                implicitWidth:  Kirigami.Units.gridUnit * 9
                                implicitHeight: charInnerCol.implicitHeight

                                Column {
                                    id:      charInnerCol
                                    width:   parent.width
                                    spacing: Kirigami.Units.smallSpacing

                                    Rectangle {
                                        width:  parent.width
                                        height: Kirigami.Units.gridUnit * 13
                                        radius: Kirigami.Units.cornerRadius
                                        clip:   true
                                        color:  Kirigami.Theme.alternateBackgroundColor

                                        Image {
                                            anchors.fill: parent
                                            source:       modelData.image || ""
                                            fillMode:     Image.PreserveAspectCrop
                                            asynchronous: true
                                            mipmap:       true
                                        }
                                    }

                                    // Character name
                                    Controls.Label {
                                        width:               parent.width
                                        text:                modelData.name || ""
                                        wrapMode:            Text.WordWrap
                                        maximumLineCount:    2
                                        elide:               Text.ElideRight
                                        font.pointSize:      Kirigami.Theme.defaultFont.pointSize * 0.85
                                        color:               Kirigami.Theme.textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // First media this character appeared in
                                    Controls.Label {
                                        width:               parent.width
                                        visible:             Boolean(modelData.media && modelData.media.length > 0)
                                        text:                (modelData.media && modelData.media.length > 0)
                                                             ? (modelData.media[0].title || "") : ""
                                        wrapMode:            Text.WordWrap
                                        maximumLineCount:    2
                                        elide:               Text.ElideRight
                                        font.pointSize:      Kirigami.Theme.defaultFont.pointSize * 0.75
                                        color:               Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                TapHandler {
                                    onTapped: pageStack.layers.push(
                                        Qt.resolvedUrl("CharacterPage.qml"),
                                        { characterId: modelData.characterId }
                                    )
                                }

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }

                // ── Anime Staff Roles ─────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.staffMedia && _data.staffMedia.some(m => m.type === "ANIME"))

                    Kirigami.Heading { level: 3; text: "Anime Staff Roles" }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing:          Kirigami.Units.largeSpacing

                        Repeater {
                            model: (_data && _data.staffMedia)
                                ? _data.staffMedia.filter(m => m.type === "ANIME") : []

                            Item {
                                implicitWidth:  Kirigami.Units.gridUnit * 9
                                implicitHeight: animeStaffInnerCol.implicitHeight

                                Column {
                                    id:      animeStaffInnerCol
                                    width:   parent.width
                                    spacing: Kirigami.Units.smallSpacing

                                    MediaCoverCard {
                                        width:    parent.width
                                        mediaId:  modelData.mediaId
                                        title:    modelData.title     || ""
                                        imageURL: modelData.coverImage || ""
                                        onTapped: pageStack.layers.push(
                                            Qt.resolvedUrl("AnimePage.qml"),
                                            { animeId: modelData.mediaId })
                                    }

                                    Controls.Label {
                                        width:               parent.width
                                        text:                modelData.staffRole || ""
                                        font.pointSize:      Kirigami.Theme.defaultFont.pointSize * 0.75
                                        color:               Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode:            Text.WordWrap
                                        maximumLineCount:    2
                                        elide:               Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Manga Staff Roles ─────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   Kirigami.Units.largeSpacing
                    Layout.rightMargin:  Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing:             Kirigami.Units.smallSpacing
                    visible:             Boolean(_data && _data.staffMedia && _data.staffMedia.some(m => m.type === "MANGA"))

                    Kirigami.Heading { level: 3; text: "Manga Staff Roles" }

                    Kirigami.Separator { Layout.fillWidth: true }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing:          Kirigami.Units.largeSpacing

                        Repeater {
                            model: (_data && _data.staffMedia)
                                ? _data.staffMedia.filter(m => m.type === "MANGA") : []

                            Item {
                                implicitWidth:  Kirigami.Units.gridUnit * 9
                                implicitHeight: mangaStaffInnerCol.implicitHeight

                                Column {
                                    id:      mangaStaffInnerCol
                                    width:   parent.width
                                    spacing: Kirigami.Units.smallSpacing

                                    MediaCoverCard {
                                        width:    parent.width
                                        mediaId:  modelData.mediaId
                                        title:    modelData.title     || ""
                                        imageURL: modelData.coverImage || ""
                                        onTapped: pageStack.layers.push(
                                            Qt.resolvedUrl("MangaPage.qml"),
                                            { anilistId: modelData.mediaId })
                                    }

                                    Controls.Label {
                                        width:               parent.width
                                        text:                modelData.staffRole || ""
                                        font.pointSize:      Kirigami.Theme.defaultFont.pointSize * 0.75
                                        color:               Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode:            Text.WordWrap
                                        maximumLineCount:    2
                                        elide:               Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    visible:                staffPage._isFetchingMore

                    Controls.BusyIndicator {
                        anchors.centerIn: parent
                        running:          staffPage._isFetchingMore
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
