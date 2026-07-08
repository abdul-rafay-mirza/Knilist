import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var information: ({})
    property string mediaType: "ANIME"   // "ANIME" | "MANGA"

    readonly property bool isAnime: mediaType === "ANIME"

    // Let the parent RowLayout size us vertically by content
    implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2

    // ── Themed sidebar background ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.alternateBackgroundColor
    }

    // ── Right-edge separator ──────────────────────────────────────────────────
    Kirigami.Separator {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    ColumnLayout {
        id: layout
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   Kirigami.Units.largeSpacing
            leftMargin:  Kirigami.Units.largeSpacing
            rightMargin: Kirigami.Units.largeSpacing
        }
        spacing: Kirigami.Units.largeSpacing

        // ── Airing — anime only, only when there is actually a next episode ───
        ColumnLayout {
            visible: isAnime && (information.timeUntilAiring || "") !== ""
            spacing: 1

            Controls.Label {
                text:        "Airing"
                color:       Kirigami.Theme.highlightColor
                font.weight: Font.DemiBold
            }
            Controls.Label {
                text:  `Ep ${information.nextAiringEpisode || ""}: ${information.timeUntilAiring || ""}`
                color: Kirigami.Theme.highlightColor
            }
        }

        // ── Core fields ───────────────────────────────────────────────────────
        InfoRow { label: "Format"; value: formatFormat(information.format || "") }

        InfoRow {
            visible: isAnime && (information.episodes || 0) > 0
            label: "Episodes"
            value: (information.episodes || 0) > 0 ? String(information.episodes) : ""
        }

        InfoRow {
            visible: isAnime && (information.duration || 0) > 0
            label: "Episode Duration"
            value: (information.duration || 0) > 0 ? `${information.duration} mins` : ""
        }

        InfoRow {
            visible: !isAnime && (information.chapters || 0) > 0
            label: "Chapters"
            value: (information.chapters || 0) > 0 ? String(information.chapters) : ""
        }

        InfoRow {
            visible: !isAnime && (information.volumes || 0) > 0
            label: "Volumes"
            value: (information.volumes || 0) > 0 ? String(information.volumes) : ""
        }

        InfoRow { label: "Status";     value: formatStatus(information.status || "") }
        InfoRow { label: "Start Date"; value: formatDate(information.startDate || "") }

        InfoRow {
            label:   "End Date"
            value:   formatDate(information.endDate || "")
            visible: (information.status === "FINISHED"
                      || information.status === "RELEASING"
                      || information.status === "CANCELLED")
                     && formatDate(information.endDate || "") !== ""
        }

        InfoRow {
            visible: isAnime && formatSeason(information.season || "", information.seasonYear || 0) !== ""
            label: "Season"
            value: formatSeason(information.season || "", information.seasonYear || 0)
        }

        // ── Scores & stats ────────────────────────────────────────────────────
        InfoRow {
            label: "Average Score"
            value: (information.averageScore || 0) > 0 ? `${information.averageScore}%` : ""
        }
        InfoRow {
            label: "Mean Score"
            value: (information.meanScore || 0) > 0 ? `${information.meanScore}%` : ""
        }
        InfoRow {
            label: "Popularity"
            value: (information.popularity || 0) > 0 ? String(information.popularity) : ""
        }
        InfoRow {
            label: "Favorites"
            value: (information.favourites || 0) > 0 ? String(information.favourites) : ""
        }

        // ── Studios — anime only ─────────────────────────────────────────────
        ColumnLayout {
            visible: isAnime && (information.studios || []).length > 0
            spacing: 1

            Controls.Label { text: "Studios"; font.weight: Font.DemiBold; color: Kirigami.Theme.textColor }
            Repeater {
                model: information.studios || []
                Controls.Label {
                    text: modelData.name
                    wrapMode: Text.WordWrap

                    opacity: studioHover.hovered ? 1.0 : 0.85
                    color: studioHover.hovered ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor

                    TapHandler {
                        onTapped: {
                            pageStack.layers.push(Qt.resolvedUrl("../StudioPage.qml"), { studioId: modelData.id, studioName: modelData.name })
                        }
                    }

                    HoverHandler {
                        id: studioHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Producers — anime only ───────────────────────────────────────────
        ColumnLayout {
            visible: isAnime && (information.producers || []).length > 0
            spacing: 1

            Controls.Label { text: "Producers"; font.weight: Font.DemiBold; color: Kirigami.Theme.textColor }
            Repeater {
                model: information.producers || []
                Controls.Label {
                    text: modelData.name
                    wrapMode: Text.WordWrap

                    opacity: producerHover.hovered ? 1.0 : 0.85
                    color: producerHover.hovered ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor

                    TapHandler {
                        onTapped: {
                            pageStack.layers.push(Qt.resolvedUrl("../StudioPage.qml"), { studioId: modelData.id })
                        }
                    }

                    HoverHandler {
                        id: producerHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Misc ──────────────────────────────────────────────────────────────
        InfoRow { label: "Source"; value: formatSource(information.source || "") }

        InfoRow {
            visible: isAnime && (information.hashtag || "") !== ""
            label: "Hashtag"
            value: information.hashtag || ""
        }

        // ── Genres ────────────────────────────────────────────────────────────
        ColumnLayout {
            visible: (information.genres || []).length > 0
            spacing: 1

            Controls.Label { text: "Genres"; font.weight: Font.DemiBold; color: Kirigami.Theme.textColor }
            Repeater {
                model: information.genres || []
                Controls.Label { Layout.fillWidth: true; text: modelData; opacity: 0.85; wrapMode: Text.WordWrap; color: Kirigami.Theme.textColor }
            }
        }

        // ── Titles ────────────────────────────────────────────────────────────
        InfoRow { label: "Romaji";  value: information.titleRomaji  || "" }
        InfoRow { label: "English"; value: information.titleEnglish || "" }
        InfoRow { label: "Native";  value: information.titleNative  || "" }

        // ── Synonyms ──────────────────────────────────────────────────────────
        ColumnLayout {
            visible: (information.synonyms || []).length > 0
            spacing: 1

            Controls.Label { text: "Synonyms"; font.weight: Font.DemiBold; color: Kirigami.Theme.textColor }
            Repeater {
                model: information.synonyms || []
                Controls.Label { Layout.fillWidth: true; text: modelData; opacity: 0.85; wrapMode: Text.WordWrap; color: Kirigami.Theme.textColor }
            }
        }

        Item { implicitHeight: Kirigami.Units.largeSpacing }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function formatDate(dateStr) {
        if (!dateStr || dateStr.length < 10) return ""
        const months = ["Jan","Feb","Mar","Apr","May","Jun",
                        "Jul","Aug","Sep","Oct","Nov","Dec"]
        const p = dateStr.split("-")
        return `${months[parseInt(p[1]) - 1]} ${parseInt(p[2])}, ${p[0]}`
    }

    function formatStatus(s) {
        return ({ FINISHED: "Finished", RELEASING: "Releasing",
                  NOT_YET_RELEASED: "Not Yet Released",
                  CANCELLED: "Cancelled", HIATUS: "Hiatus" })[s] || s
    }

    function formatFormat(f) {
        return ({
            TV:       "TV",
            TV_SHORT: "TV Short",
            MOVIE:    "Movie",
            SPECIAL:  "Special",
            OVA:      "OVA",
            ONA:      "ONA",
            MUSIC:    "Music",
            MANGA:    "Manga",
            NOVEL:    "Novel",
            ONE_SHOT: "One Shot",
        })[f] || f
    }

    function formatSource(s) {
        if (!s) return ""
        return s.split("_").map(w => w[0] + w.slice(1).toLowerCase()).join(" ")
    }

    function formatSeason(season, year) {
        if (!season) return ""
        const s = season[0] + season.slice(1).toLowerCase()
        return year ? `${s} ${year}` : s
    }
}