import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Renders a list of OP/ED themes (as produced by anilist_service.py's
// _flatten_anime_themes / fetchOpeningEndingSongs). Each theme can have more
// than one entry (different episode ranges/versions) and each entry can have
// more than one video variant (resolution, subbed/unsubbed, source) — both
// are shown rather than collapsed, since the backend deliberately keeps them
// as lists instead of picking a "best" one.
//
// Each theme renders as a card with a left-hand thumbnail (matching the
// AnimeCard/StaffCard/RelationCard layout used elsewhere in this app),
// collapsed to just the header by default — tap the header to reveal
// episode/video details. The thumbnail prefers the song's actual album art
// (resolved via MusicBrainz + the Cover Art Archive, arriving progressively
// per-theme after the list first renders — see AnimePage.qml's
// onThemeAlbumArtLoaded), falling back to the performing artist's own photo
// from animethemes.moe when no album art is found or hasn't resolved yet.
// Every action button (copy link, open, open in mpv/VLC) confirms itself
// with a passive notification, matching the "Added to Favorites" toast
// already used elsewhere in this app.
ColumnLayout {
    id: root

    property string headingText: ""
    property var themes:   []   // list of { themeId, type, songTitle, artists, artistsText, entries, albumArt }
    property bool loading: false
    property bool isError: false
    property int cardSize: 7

    spacing: Kirigami.Units.smallSpacing

    // ── Heading ────────────────────────────────────────────────────────────
    Kirigami.Heading {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        level: 3
        text:  root.headingText
        visible: root.loading || root.isError || root.themes.length > 0
    }

    // Attribution: this section's video/audio links come from animethemes.moe,
    // a separate service from the AniList API the rest of this app is built
    // on. Worth making explicit rather than letting it read as AniList data.
    Controls.Label {
        Layout.fillWidth: true
        Layout.bottomMargin: Kirigami.Units.smallSpacing / 2
        text: "Theme songs provided by animethemes.moe"
        opacity: 0.6
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        elide: Text.ElideRight
        visible: !root.loading && !root.isError && root.themes.length > 0
    }

    // ── Loading state ─────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: root.loading
        spacing: Kirigami.Units.smallSpacing

        Controls.BusyIndicator {
            running:            root.loading
            implicitWidth:      Kirigami.Units.iconSizes.small
            implicitHeight:     Kirigami.Units.iconSizes.small
        }
        Controls.Label {
            text: "Loading…"
            opacity: 0.7
        }
    }

    // ── Error state ────────────────────────────────────────────────────────
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: !root.loading && root.isError
        type:    Kirigami.MessageType.Warning
        text:    "Couldn't load theme songs for this anime."
    }

    // ── Themes ─────────────────────────────────────────────────────────────
    Repeater {
        model: root.loading ? [] : root.themes

        delegate: Kirigami.AbstractCard {
            id: themeCard
            required property var modelData

            // Cover image, in priority order:
            //   1. Real album art for the song (modelData.albumArt), resolved
            //      via MusicBrainz + the Cover Art Archive. Arrives AFTER the
            //      card first renders — see AnimePage.qml's
            //      onThemeAlbumArtLoaded — so this is "" on first paint for
            //      every theme and pops in per-card once resolved.
            //   2. The performing artist's own photo from animethemes.moe,
            //      same as before this feature existed — used when
            //      MusicBrainz has no match/no art for this specific song,
            //      or hasn't resolved (yet).
            // Prefer a small cover for a compact thumbnail within whichever
            // source is used, but fall back to whatever facet exists so a
            // card is never emptier than its data — neither source always
            // has every size/facet.
            readonly property var _primaryArtist: (themeCard.modelData.artists && themeCard.modelData.artists.length > 0)
                ? themeCard.modelData.artists[0] : null
            readonly property var _artistImages: (themeCard._primaryArtist && themeCard._primaryArtist.images) || []
            readonly property string _artistCoverImage: {
                if (themeCard._artistImages.length === 0) return ""
                const small = themeCard._artistImages.find(img => img.facet === "SMALL_COVER")
                if (small) return small.link
                const large = themeCard._artistImages.find(img => img.facet === "LARGE_COVER")
                if (large) return large.link
                return themeCard._artistImages[0].link || ""
            }
            readonly property string _coverImage: (themeCard.modelData.albumArt || "") !== ""
                ? themeCard.modelData.albumArt
                : themeCard._artistCoverImage
            readonly property bool _hasCover: themeCard._coverImage !== ""

            readonly property bool _isOpening: (themeCard.modelData.type || "") === "OP"

            property bool expanded: false

            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            padding: 0

            contentItem: ColumnLayout {
                spacing: 0

                // ── Header: thumbnail + title/artist + badge/chevron ───────
                // Same left-thumbnail/right-text shape as AnimeCard,
                // StaffCard, and RelationCard elsewhere in this app — normal
                // Kirigami.Theme colors throughout, since text sits on the
                // card's own background here rather than over a photo (no
                // scrim/legibility overlay needed, unlike the previous
                // backdrop-image design).
                RowLayout {
                    id: headerArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * root.cardSize
                    spacing: 0

                    // Thumbnail
                    Rectangle {
                        Layout.preferredWidth:  Kirigami.Units.gridUnit * root.cardSize
                        Layout.fillHeight:      true
                        color: Kirigami.ColorUtils.tintWithAlpha(
                                   Kirigami.Theme.backgroundColor,
                                   Kirigami.Theme.textColor,
                                   0.05)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source:       themeCard._coverImage
                            fillMode:     Image.PreserveAspectCrop
                            asynchronous: true
                            smooth:       true
                            visible:      themeCard._hasCover && status === Image.Ready
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source:  "media-album-track-symbolic"
                            implicitWidth:  Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            visible: !themeCard._hasCover
                            color:   Kirigami.Theme.disabledTextColor
                        }
                    }

                    // Title/artist + badge/chevron
                    RowLayout {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        Layout.leftMargin:  Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Controls.Label {
                                Layout.fillWidth: true
                                text: themeCard.modelData.songTitle || "Unknown title"
                                color: Kirigami.Theme.textColor
                                font.bold: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                visible: !!themeCard.modelData.artistsText
                                text: themeCard.modelData.artistsText
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        // OP / ED badge — same accent-color logic as before;
                        // no longer needs to match a backdrop gradient, but
                        // keeping the highlight/focus split still reads as
                        // "two distinct kinds of theme" at a glance.
                        Rectangle {
                            id: typeBadge
                            radius: height / 2
                            color: themeCard._isOpening ? Kirigami.Theme.highlightColor : Kirigami.Theme.focusColor
                            height: typeBadgeLabel.implicitHeight + Kirigami.Units.smallSpacing
                            width:  typeBadgeLabel.implicitWidth + Kirigami.Units.largeSpacing

                            Controls.Label {
                                id: typeBadgeLabel
                                anchors.centerIn: parent
                                text: themeCard._isOpening ? "Opening" : "Ending"
                                color: Kirigami.Theme.highlightedTextColor
                                font.bold: true
                                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
                            }
                        }

                        Kirigami.Icon {
                            source: "arrow-down-symbolic"
                            color: Kirigami.Theme.textColor
                            implicitWidth:  Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            rotation: themeCard.expanded ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    TapHandler {
                        onTapped: themeCard.expanded = !themeCard.expanded
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // ── Body: entries/videos, collapsed until the header is tapped ──
                //
                // bodyContent is never resized itself — it just reports its
                // natural (implicitHeight) size. The wrapping Item is what
                // actually animates, sized to bodyContent's height only when
                // expanded. This avoids a Behavior fighting a binding that
                // reads back its own animated target (which is what happens
                // if Layout.preferredHeight both drives *and* is driven by
                // implicitHeight): here the animated property (clipItem's
                // height) and the measured property (bodyContent's
                // implicitHeight) are two different items, so there's
                // nothing for the Behavior to fight, and content that
                // resizes later (e.g. episode text wrapping differently)
                // still reflows correctly next time expanded flips.
                Item {
                    id: clipItem
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    clip: true

                    implicitHeight: themeCard.expanded
                        ? bodyContent.implicitHeight + Kirigami.Units.smallSpacing * 2
                        : 0
                    opacity: themeCard.expanded ? 1.0 : 0.0

                    Behavior on implicitHeight {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }

                    ColumnLayout {
                        id: bodyContent
                        y: Kirigami.Units.smallSpacing
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        // One block per entry (episode range / version)
                        Repeater {
                            model: themeCard.modelData.entries || []

                            delegate: ColumnLayout {
                                id: entryDelegate
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing / 2

                                Kirigami.Separator {
                                    Layout.fillWidth: true
                                    visible: entryDelegate.Repeater.index > 0
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    visible: !!entryDelegate.modelData.episodes
                                    text: "Episodes " + entryDelegate.modelData.episodes
                                    opacity: 0.6
                                    font.italic: true
                                }

                                // One block per video variant: a description line
                                // (resolution / subbed / source) followed by its actions.
                                Repeater {
                                    model: entryDelegate.modelData.videos || []

                                    delegate: ColumnLayout {
                                        id: videoBlock
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                                        spacing: 0

                                        Controls.Label {
                                            Layout.fillWidth: true
                                            opacity: 0.6
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            text: {
                                                const parts = []
                                                if (videoBlock.modelData.resolution)
                                                    parts.push(videoBlock.modelData.resolution + "p")
                                                parts.push(videoBlock.modelData.subbed ? "Subbed" : "Unsubbed")
                                                if (videoBlock.modelData.source)
                                                    parts.push(videoBlock.modelData.source)
                                                return parts.join(" · ")
                                            }
                                        }

                                        Kirigami.ActionToolBar {
                                            id: videoRow
                                            Layout.fillWidth: true
                                            alignment: Qt.AlignLeft
                                            display:   Controls.Button.TextBesideIcon

                                            actions: [
                                                Kirigami.Action {
                                                    icon.name: "edit-copy"
                                                    text: "Copy link"
                                                    onTriggered: {
                                                        anilistService.copyToClipboard(videoBlock.modelData.videoLink)
                                                        applicationWindow().showPassiveNotification("Video link copied")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "edit-copy"
                                                    text: "Copy audio link"
                                                    visible: !!videoBlock.modelData.audioLink
                                                    onTriggered: {
                                                        anilistService.copyToClipboard(videoBlock.modelData.audioLink)
                                                        applicationWindow().showPassiveNotification("Audio link copied")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "document-open"
                                                    text: "Open"
                                                    onTriggered: {
                                                        Qt.openUrlExternally(videoBlock.modelData.videoLink)
                                                        applicationWindow().showPassiveNotification("Opening video…")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "media-playback-start"
                                                    text: "Open in mpv"
                                                    onTriggered: {
                                                        anilistService.openInExternalPlayer(videoBlock.modelData.videoLink, "mpv")
                                                        applicationWindow().showPassiveNotification("Opening in mpv…")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "media-playback-start"
                                                    text: "Open in VLC"
                                                    onTriggered: {
                                                        anilistService.openInExternalPlayer(videoBlock.modelData.videoLink, "vlc")
                                                        applicationWindow().showPassiveNotification("Opening in VLC…")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "media-playback-start"
                                                    text: "Open audio in mpv"
                                                    visible: !!videoBlock.modelData.audioLink
                                                    onTriggered: {
                                                        anilistService.openInExternalPlayer(videoBlock.modelData.audioLink, "mpv")
                                                        applicationWindow().showPassiveNotification("Opening audio in mpv…")
                                                    }
                                                },
                                                Kirigami.Action {
                                                    icon.name: "media-playback-start"
                                                    text: "Open audio in VLC"
                                                    visible: !!videoBlock.modelData.audioLink
                                                    onTriggered: {
                                                        anilistService.openInExternalPlayer(videoBlock.modelData.audioLink, "vlc")
                                                        applicationWindow().showPassiveNotification("Opening audio in VLC…")
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
