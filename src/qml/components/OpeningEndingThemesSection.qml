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
ColumnLayout {
    id: root

    property string headingText: ""
    property var themes:   []   // list of { themeId, type, songTitle, artists, artistsText, entries }
    property bool loading: false
    property bool isError: false

    spacing: Kirigami.Units.smallSpacing

    // ── Heading ────────────────────────────────────────────────────────────
    Kirigami.Heading {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        level: 2
        text:  root.headingText
        visible: root.loading || root.isError || root.themes.length > 0
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

        delegate: ColumnLayout {
            id: themeDelegate
            required property var modelData

            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Song title + artist(s)
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "media-album-track-symbolic"
                    implicitWidth:  Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.Label {
                        Layout.fillWidth: true
                        text: themeDelegate.modelData.songTitle || "Unknown title"
                        font.bold: true
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        visible: !!themeDelegate.modelData.artistsText
                        text: themeDelegate.modelData.artistsText
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }
            }

            // One block per entry (episode range / version)
            Repeater {
                model: themeDelegate.modelData.entries || []

                delegate: ColumnLayout {
                    id: entryDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing / 2

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
                                        onTriggered: anilistService.copyToClipboard(videoBlock.modelData.videoLink)
                                    },
                                    Kirigami.Action {
                                        icon.name: "edit-copy"
                                        text: "Copy audio link"
                                        visible: !!videoBlock.modelData.audioLink
                                        onTriggered: anilistService.copyToClipboard(videoBlock.modelData.audioLink)
                                    },
                                    Kirigami.Action {
                                        icon.name: "document-open"
                                        text: "Open"
                                        onTriggered: Qt.openUrlExternally(videoBlock.modelData.videoLink)
                                    },
                                    Kirigami.Action {
                                        icon.name: "media-playback-start"
                                        text: "Open in mpv"
                                        onTriggered: anilistService.openInExternalPlayer(videoBlock.modelData.videoLink, "mpv")
                                    },
                                    Kirigami.Action {
                                        icon.name: "media-playback-start"
                                        text: "Open in VLC"
                                        onTriggered: anilistService.openInExternalPlayer(videoBlock.modelData.videoLink, "vlc")
                                    },
                                    Kirigami.Action {
                                        icon.name: "media-playback-start"
                                        text: "Open audio in mpv"
                                        visible: !!videoBlock.modelData.audioLink
                                        onTriggered: anilistService.openInExternalPlayer(videoBlock.modelData.audioLink, "mpv")
                                    },
                                    Kirigami.Action {
                                        icon.name: "media-playback-start"
                                        text: "Open audio in VLC"
                                        visible: !!videoBlock.modelData.audioLink
                                        onTriggered: anilistService.openInExternalPlayer(videoBlock.modelData.audioLink, "vlc")
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
