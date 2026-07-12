import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
// import org.kde.kirigamiaddons.components as Addons
import "components"

Kirigami.Page {
    id: profilePage
    title: "Profile"

    property var profile: ({})
    property bool profileReady: false

    readonly property int bannerHeight: Kirigami.Units.gridUnit * 10
    readonly property int avatarSize: Kirigami.Units.gridUnit * 7

    // Donator badge + moderator role chips, derived from profile.
    readonly property var badgeList: {
        var chips = []
        if (profile.donatorTier && profile.donatorTier > 0) {
            chips.push(profile.donatorBadge && profile.donatorBadge.length > 0
                       ? profile.donatorBadge : "Supporter")
        }
        var roles = profile.moderatorRoles || []
        for (var i = 0; i < roles.length; i++) {
            chips.push(moderatorRoleLabel(roles[i]))
        }
        return chips
    }

    // AniList favourites come back as {id, name, image} — shared with Favorite
    // Staff — but CharacterCard/CharactersSection (used as-is by AnimePage/
    // MangaPage) hardcode "characterId". Remap here instead of touching those.
    readonly property var favouriteCharactersMapped: (profile.favouriteCharacters || []).map(function (c) {
        return { characterId: c.id, name: c.name, image: c.image, role: "" }
    })

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: anilistService.fetchProfile()
        }
    ]

    Component.onCompleted: anilistService.fetchProfile()

    Connections {
        target: anilistService

        function onProfileLoaded(json) {
            profilePage.profile = JSON.parse(json)
            profilePage.profileReady = true
            errorMessage.visible = false
        }

        function onErrorOccurred(message) {
            errorMessage.text = message
            errorMessage.visible = true
        }
    }

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
                id: mainColumn
                width: parent.width
                spacing: 0

                Kirigami.InlineMessage {
                    id: errorMessage
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    type: Kirigami.MessageType.Error
                    showCloseButton: true
                    visible: false
                }

                // ── Profile content ──────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: profilePage.profileReady

                    // Banner + overlapping avatar
                    Item {
                        id: headerArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: profilePage.bannerHeight + profilePage.avatarSize / 2

                        Rectangle {
                            id: bannerFallback
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: profilePage.bannerHeight
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: profilePage.accentColor() }
                                GradientStop { position: 1.0; color: Qt.darker(profilePage.accentColor(), 1.6) }
                            }
                        }

                        Image {
                            id: bannerImage
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: profilePage.bannerHeight
                            source: profilePage.profile.bannerImage || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            visible: status === Image.Ready
                        }

                        Image {
                            id: avatarImage

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: profilePage.bannerHeight - height / 2

                            width: profilePage.avatarSize
                            height: profilePage.avatarSize

                            source: profilePage.profile.avatar || ""
                            fillMode: Image.PreserveAspectCrop

                            layer.enabled: true
                            layer.smooth: true

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                            }
                        }
                    }

                    // Name + badges
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 1
                            text: profilePage.profile.name || ""
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            visible: badgeRepeater.count > 0

                            Repeater {
                                id: badgeRepeater
                                model: profilePage.badgeList

                                delegate: Rectangle {
                                    radius: height / 2
                                    color: profilePage.accentColor()
                                    height: badgeLabel.implicitHeight + Kirigami.Units.smallSpacing
                                    width: badgeLabel.implicitWidth + Kirigami.Units.largeSpacing

                                    Controls.Label {
                                        id: badgeLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Kirigami.Theme.highlightedTextColor
                                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    // ── Stat bar: Anime / Manga / Following / Followers ─────────
                    StatBar {
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        Layout.alignment: Qt.AlignHCenter
                        stats: [
                            { value: profilePage.profile.animeCount, label: "Anime" },
                            { value: profilePage.profile.mangaCount, label: "Manga" },
                            { value: profilePage.profile.followingCount, label: "Following" },
                            { value: profilePage.profile.followersCount, label: "Followers" }
                        ]
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }

                    // About
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (profilePage.profile.about || "").length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "About"
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: profilePage.profile.about || ""
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }

                    // ── Detailed Stats ───────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true

                            Kirigami.Heading {
                                Layout.fillWidth: true
                                level: 3
                                text: "Stats"
                            }

                            Controls.Label {
                                text: "View Detail Statistics"
                                color: Kirigami.Theme.highlightColor
                                // stub — no dedicated statistics page yet
                            }
                        }

                        Kirigami.FormLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                Kirigami.FormData.label: "Total Anime:"
                                text: String(profilePage.profile.animeCount || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Episodes Watched:"
                                text: String(profilePage.profile.episodesWatched || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Days Watched:"
                                text: (profilePage.profile.daysWatched || 0).toFixed(2)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Anime Mean Score:"
                                text: (profilePage.profile.animeMeanScore || 0).toFixed(2)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Total Manga:"
                                text: String(profilePage.profile.mangaCount || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Chapters Read:"
                                text: String(profilePage.profile.chaptersRead || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Volumes Read:"
                                text: String(profilePage.profile.volumesRead || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Manga Mean Score:"
                                text: (profilePage.profile.mangaMeanScore || 0).toFixed(2)
                            }
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            text: "Stats are automatically updated every 48 hours, or you can force update them in Account Settings."
                            opacity: 0.7
                            wrapMode: Text.Wrap
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    // ── Favorite Anime ───────────────────────────────────────────
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Anime"
                        model: profilePage.profile.favouriteAnime || []

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("AnimePage.qml"), { animeId: entry.mediaId }
                        )
                    }

                    // ── Favorite Manga ───────────────────────────────────────────
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Manga"
                        model: profilePage.profile.favouriteManga || []

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("MangaPage.qml"), { anilistId: entry.mediaId }
                        )
                    }

                    // ── Favorite Characters ──────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (profilePage.profile.favouriteCharacters || []).length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "Favorite Characters"
                        }

                        Kirigami.Separator { Layout.fillWidth: true }

                        CharactersSection {
                            Layout.fillWidth: true
                            characters: profilePage.favouriteCharactersMapped
                            onCharacterClicked: (characterId, name, image, role) => {
                                console.log("Character ID: " + characterId)
                                pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                                    characterId: characterId
                                })
                            }
                            headingVisible: false
                        }
                    }

                    // ── Favorite Staff ────────────────────────────────────────────
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Staff"
                        model: profilePage.profile.favouriteStaff || []
                        idKey: "id"
                        titleKey: "name"
                        imageKey: "image"

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("StaffPage.qml"), { staffId: entry.id }
                        )
                    }

                    // ── Favorite Studios (chips) ─────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (profilePage.profile.favouriteStudios || []).length > 0

                        RowLayout {
                            Layout.fillWidth: true

                            Kirigami.Heading {
                                Layout.fillWidth: true
                                level: 3
                                text: "Favorite Studios"
                            }

                            Controls.Label {
                                text: "See More"
                                color: Kirigami.Theme.highlightColor
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: profilePage.profile.favouriteStudios || []

                                delegate: Rectangle {
                                    radius: height / 2
                                    color: profilePage.accentColor()
                                    height: studioLabel.implicitHeight + Kirigami.Units.smallSpacing
                                    width: studioLabel.implicitWidth + Kirigami.Units.largeSpacing

                                    Controls.Label {
                                        id: studioLabel
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: Kirigami.Theme.highlightedTextColor
                                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
                                        font.bold: true
                                    }

                                    TapHandler {
                                        onTapped: applicationWindow().pageStack.layers.push(
                                            Qt.resolvedUrl("StudioPage.qml"), { studioId: modelData.id }
                                        )
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }

                    // ── Anime Tendencies ─────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (profilePage.profile.tendencies || []).length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "Anime Tendencies"
                        }

                        Repeater {
                            model: profilePage.profile.tendencies || []

                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Controls.Label { text: "•" }
                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: profilePage.tendencyLineHtml(modelData)
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            text: "Tendency is generated automatically based on user stats. It might or might not be accurate."
                            opacity: 0.7
                            wrapMode: Text.Wrap
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.largeSpacing
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }

                    // Account details
                    Kirigami.FormLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2

                        Controls.Label {
                            Kirigami.FormData.label: "Score format:"
                            text: profilePage.scoreFormatLabel(profilePage.profile.scoreFormat)
                        }
                        Controls.Label {
                            Kirigami.FormData.label: "Title language:"
                            text: profilePage.titleLanguageLabel(profilePage.profile.titleLanguage)
                        }
                        Controls.Label {
                            Kirigami.FormData.label: "Adult content:"
                            text: profilePage.profile.displayAdultContent ? "Shown" : "Hidden"
                        }
                        Controls.Label {
                            Kirigami.FormData.label: "Unread notifications:"
                            text: String(profilePage.profile.unreadNotificationCount || 0)
                        }
                    }

                    Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
                }
            }
        }

        // ── Loading overlay (first load + refresh) ────────────────────────
        Rectangle {
            anchors.fill: parent
            visible: anilistService.loading
            color: Kirigami.Theme.backgroundColor
            opacity: 0.6
            z: 2
 
            MouseArea {
                anchors.fill: parent
                enabled: anilistService.loading
                hoverEnabled: true
            }
 
            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: true
            }
        }
    }

    function moderatorRoleLabel(role) {
        return role.toString().toLowerCase()
                   .split("_")
                   .map(function (w) { return w.charAt(0).toUpperCase() + w.slice(1) })
                   .join(" ")
    }

    function scoreFormatLabel(fmt) {
        switch (fmt) {
            case "POINT_100": return "100 point"
            case "POINT_10_DECIMAL": return "10 point (decimal)"
            case "POINT_10": return "10 point"
            case "POINT_5": return "5 star"
            case "POINT_3": return "3 point smiley"
            default: return fmt || "Unknown"
        }
    }

    function titleLanguageLabel(lang) {
        switch (lang) {
            case "ROMAJI": return "Romaji"
            case "ENGLISH": return "English"
            case "NATIVE": return "Native"
            default: return lang || "Unknown"
        }
    }

    function accentColor() {
        var c = profile.profileColor || ""
        if (c.length === 0) {
            return Kirigami.Theme.highlightColor
        }
        if (c.charAt(0) === "#") {
            return c
        }
        var presets = {
            "blue":   "#3DB4F2",
            "purple": "#C063FF",
            "pink":   "#FC9DD6",
            "orange": "#EF881A",
            "red":    "#E13333",
            "green":  "#4CCA51",
            "gray":   "#667380"
        }
        return presets[c] || Kirigami.Theme.highlightColor
    }

    function tendencyLineHtml(entry) {
        var accent = profilePage.accentColor()
        var colored = (entry.values || []).map(function (v) {
            return "<font color=\"" + accent + "\">" + v + "</font>"
        }).join("/")

        switch (entry.kind) {
            case "genresLoved":    return "Seems to love " + colored
            case "genresHated":    return "Seems to hate " + colored
            case "tagsLoved":      return "Tends to like " + colored
            case "yearsLoved":     return "Love " + colored + " series"
            case "firstYear":      return "First recorded watching Anime in " + colored
            case "completionRate": return "Ends up completing " + colored + "% of Anime started"
            default:               return ""
        }
    }
}