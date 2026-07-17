import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
// import org.kde.kirigamiaddons.components as Addons
import "components"

// The page representing any user
// Accessed from ProfilePage > Click on Followers and Following StatBar > Click on a FollowersAndFollowingCard

Kirigami.Page {
    id: usersPage
    title: userName

    property var userId: 0
    property var userName: "User Page"

    property var profile: ({})
    property bool profileReady: false

    // Local optimistic mirror of follow state so the button responds
    // immediately on tap rather than waiting a full round trip. Reset to the
    // server's value whenever a fresh profile loads (e.g. on refresh).
    property bool isFollowing: false
    property bool followActionPending: false

    readonly property int bannerHeight: Kirigami.Units.gridUnit * 10
    readonly property int avatarSize: Kirigami.Units.gridUnit * 7

    // Donator badge + moderator role chips, derived from profile.
    // Mirrors ProfilePage.badgeList exactly - same fields, same shape.
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

    // Same remap ProfilePage does for Favorite Characters - CharactersSection
    // hardcodes "characterId" but favourites come back as {id, name, image}.
    readonly property var favouriteCharactersMapped: (profile.favouriteCharacters || []).map(function (c) {
        return { characterId: c.id, name: c.name, image: c.image, role: "" }
    })

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: "Refresh"
            enabled: !anilistService.loading
            onTriggered: anilistService.fetchUserProfile(usersPage.userId)
        }
    ]

    Component.onCompleted: anilistService.fetchUserProfile(usersPage.userId)

    Connections {
        target: anilistService

        function onUserProfileLoaded(json) {
            usersPage.profile = JSON.parse(json)
            usersPage.profileReady = true
            usersPage.isFollowing = usersPage.profile.isFollowing || false
            errorMessage.visible = false
            console.log(usersPage.profile.about)
        }

        function onFollowToggled(toggledUserId, isFollowingNow, isFollowerNow) {
            // followToggled is shared across every page that can follow/unfollow,
            // so only react if it's about the user this page is showing.
            if (toggledUserId !== usersPage.userId) {
                return
            }
            usersPage.followActionPending = false
            usersPage.isFollowing = isFollowingNow
            usersPage.profile.isFollower = isFollowerNow
        }

        function onErrorOccurred(message) {
            usersPage.followActionPending = false
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

                // -- Blocked notice ---------------------------------------------
                // isBlocked has no equivalent on ProfilePage (you can't block
                // yourself) - shown ahead of the rest of the content rather
                // than hidden, since it changes what the page even means.
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    type: Kirigami.MessageType.Warning
                    text: "You have blocked this user."
                    visible: usersPage.profileReady && (usersPage.profile.isBlocked || false)
                }

                // -- Profile content ----------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: usersPage.profileReady

                    // Banner + overlapping avatar
                    Item {
                        id: headerArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: usersPage.bannerHeight + usersPage.avatarSize / 2

                        Rectangle {
                            id: bannerFallback
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: usersPage.bannerHeight
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                                GradientStop { position: 1.0; color: Qt.darker(Kirigami.Theme.highlightColor, 1.6) }
                            }
                        }

                        Image {
                            id: bannerImage
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: usersPage.bannerHeight
                            source: usersPage.profile.bannerImage || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            visible: status === Image.Ready
                        }

                        AnimatedImage {
                            id: avatarImage

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: usersPage.bannerHeight - height / 2

                            width: usersPage.avatarSize
                            height: usersPage.avatarSize

                            source: usersPage.profile.avatar || ""
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
                            text: usersPage.profile.name || ""
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            visible: badgeRepeater.count > 0

                            Repeater {
                                id: badgeRepeater
                                model: usersPage.badgeList

                                delegate: Rectangle {
                                    radius: height / 2
                                    color: Kirigami.Theme.highlightColor
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

                        // -- Follow button + "Follows you" indicator --------------
                        // The one genuinely new interactive element vs.
                        // ProfilePage: you don't follow or get followed by
                        // yourself, so this concept has no equivalent there.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Kirigami.Units.smallSpacing

                            Controls.Button {
                                text: usersPage.isFollowing ? "Following" : "Follow"
                                icon.name: usersPage.isFollowing ? "list-remove-user" : "list-add-user"
                                enabled: !usersPage.followActionPending
                                       && !(usersPage.profile.isBlocked || false)
                                highlighted: !usersPage.isFollowing

                                onClicked: {
                                    usersPage.followActionPending = true
                                    anilistService.toggleFollow(usersPage.userId)
                                }
                            }

                            Controls.Label {
                                text: "Follows you"
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                visible: usersPage.profile.isFollower || false
                            }
                        }
                    }

                    // -- Stat bar: Anime / Manga / Following / Followers ---------
                    // Same shape as ProfilePage's StatBar. Following/Followers
                    // routes push FollowingPage/FollowersPage as layers - those
                    // currently show the viewer's own following/followers list
                    // regardless of whose profile launched them (see
                    // fetchFollowing/fetchFollowers in anilist_service.py,
                    // which always resolve via _get_viewer_id()) - not this
                    // user's. Left wired identically to ProfilePage for now
                    // rather than silently disabling it.
                    StatBar {
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        Layout.alignment: Qt.AlignHCenter
                        stats: [
                            { value: usersPage.profile.animeCount, label: "Anime", target: "AnimeListPage.qml" },
                            { value: usersPage.profile.mangaCount, label: "Manga", target: "MangaListPage.qml" },
                            { value: usersPage.profile.followingCount, label: "Following", target: "FollowingPage.qml", asLayer: true },
                            { value: usersPage.profile.followersCount, label: "Followers", target: "FollowersPage.qml", asLayer: true }
                        ]

                        onEntryActivated: (target, asLayer) => {
                            if (asLayer) {
                                applicationWindow().pageStack.layers.push(Qt.resolvedUrl(target))
                            } else {
                                applicationWindow().switchToPage(target)
                            }
                        }
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
                        visible: (usersPage.profile.about || "").length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "About"
                        }

                        AniListMarkdownText {
                            Layout.fillWidth: true
                            rawMarkdown: usersPage.profile.about || ""
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }

                    // -- Detailed Stats ---------------------------------------------
                    // Same fields as ProfilePage - fetchUserProfile's payload
                    // carries the identical stat set.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 3
                            text: "Stats"
                        }

                        Kirigami.FormLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                Kirigami.FormData.label: "Total Anime:"
                                text: String(usersPage.profile.animeCount || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Episodes Watched:"
                                text: String(usersPage.profile.episodesWatched || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Days Watched:"
                                text: (usersPage.profile.daysWatched || 0).toFixed(2)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Anime Mean Score:"
                                text: (usersPage.profile.animeMeanScore || 0).toFixed(2)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Total Manga:"
                                text: String(usersPage.profile.mangaCount || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Chapters Read:"
                                text: String(usersPage.profile.chaptersRead || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Volumes Read:"
                                text: String(usersPage.profile.volumesRead || 0)
                            }
                            Controls.Label {
                                Kirigami.FormData.label: "Manga Mean Score:"
                                text: (usersPage.profile.mangaMeanScore || 0).toFixed(2)
                            }
                        }
                    }

                    // -- Favorite Anime ---------------------------------------------
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Anime"
                        model: usersPage.profile.favouriteAnime || []

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("AnimePage.qml"), { animeId: entry.mediaId }
                        )
                    }

                    // -- Favorite Manga ---------------------------------------------
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Manga"
                        model: usersPage.profile.favouriteManga || []

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("MangaPage.qml"), { anilistId: entry.mediaId }
                        )
                    }

                    // -- Favorite Characters --------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (usersPage.profile.favouriteCharacters || []).length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "Favorite Characters"
                        }

                        Kirigami.Separator { Layout.fillWidth: true }

                        CharactersSection {
                            Layout.fillWidth: true
                            characters: usersPage.favouriteCharactersMapped
                            onCharacterClicked: (characterId, name, image, role) => {
                                pageStack.layers.push(Qt.resolvedUrl("CharacterPage.qml"), {
                                    characterId: characterId
                                })
                            }
                            headingVisible: false
                        }
                    }

                    // -- Favorite Staff ------------------------------------------
                    MediaCoverCardsSection {
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

                        heading: "Favorite Staff"
                        model: usersPage.profile.favouriteStaff || []
                        idKey: "id"
                        titleKey: "name"
                        imageKey: "image"

                        onCardTapped: (entry) => applicationWindow().pageStack.layers.push(
                            Qt.resolvedUrl("StaffPage.qml"), { staffId: entry.id }
                        )
                    }

                    // -- Favorite Studios (chips) ---------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: (usersPage.profile.favouriteStudios || []).length > 0

                        Kirigami.Heading {
                            level: 3
                            text: "Favorite Studios"
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: usersPage.profile.favouriteStudios || []

                                delegate: Rectangle {
                                    radius: height / 2
                                    color: Kirigami.Theme.highlightColor
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

                    // No Anime Tendencies section - _compute_tendencies() only
                    // runs inside fetchProfile() (self), never wired into
                    // fetchUserProfile(). Nothing to render here, so the
                    // section is omitted rather than shown empty.

                    // No account-details section - score format aside, those
                    // fields (title language, adult content, unread
                    // notifications) are viewer-only settings that don't exist
                    // in fetchUserProfile's payload for another user.

                    Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
                }
            }
        }

        // -- Loading overlay (first load + refresh) ------------------------
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
}
