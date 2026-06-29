import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Self-contained description renderer.
// Handles AniList markdown, spoiler reveal, and internal link routing.
//
// Usage:
//   AniListDescription {
//       Layout.fillWidth: true
//       Layout.topMargin: Kirigami.Units.smallSpacing
//       description: _data ? (_data.description || "") : ""
//   }

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property string description: ""

    // ── Internal ──────────────────────────────────────────────────────────────
    // Reset spoilers automatically whenever the description changes
    // (i.e. when navigating to a different character/staff).
    property string _revealedIds: ""
    onDescriptionChanged: _revealedIds = ""

    implicitHeight: _label.implicitHeight
    property color color: Kirigami.Theme.textColor
    // Width is supplied by the parent layout (Layout.fillWidth: true).

    // Convert AniList's Markdown subset to HTML for Text.RichText.
    // Order matters: bold (**) before italic (*), spoilers before everything.
    function _markdownToHtml(src, revealed, hoveredId) {
        if (!src) return ""
        let s = src
        let count = 0
        const revList = revealed ? revealed.split(",") : []

        // Spoilers — must run before all other replacements
        s = s.replace(/~!([^!]+)!~/g, function(match, inner) {
            const id = "sp" + (count++)
            if (revList.indexOf(id) >= 0)
                return inner
            const isHovered = (hoveredId === id)
            return '<a href="spoiler://' + id + '" style="text-decoration:none;">'
                + '<span style="background-color:#555555;color:'
                + (isHovered ? '#ffffff' : '#555555')
                + ';border-radius:3px;padding:1px 4px;">Click to Show Spoiler</span></a>'
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

    Controls.Label {
        id:    _label
        width: parent.width

        // Inline <style> colours links from the system palette so they look
        // correct in both light and dark Plasma themes. hoveredLink is a
        // built-in Label property that re-triggers the binding on hover,
        // which is how spoiler chips react to mouse-over without extra state.
        text: {
            const _rev      = root._revealedIds
            const _hovered  = _label.hoveredLink
            const hoveredId = (_hovered && _hovered.startsWith("spoiler://"))
                            ? _hovered.slice("spoiler://".length) : ""
            const body = root._markdownToHtml(root.description, _rev, hoveredId)
            return '<style>a { color: %1; text-decoration: underline; }</style>'
                .arg(_label.palette.link) + body
        }

        onLinkActivated: function(link) {
            // ── Spoiler reveal ────────────────────────────────────────────────
            if (link.startsWith("spoiler://")) {
                const id  = link.slice("spoiler://".length)
                const cur = root._revealedIds
                if (cur.split(",").indexOf(id) < 0)
                    root._revealedIds = cur ? cur + "," + id : id
                return
            }

            // ── Internal AniList links ────────────────────────────────────────
            const charMatch  = link.match(/anilist\.co\/character\/(\d+)/)
            const animeMatch = link.match(/anilist\.co\/anime\/(\d+)/)
            const mangaMatch = link.match(/anilist\.co\/manga\/(\d+)/)
            const staffMatch = link.match(/anilist\.co\/staff\/(\d+)/)
            const studioMatch = link.match(/anilist\.co\/studio\/(\d+)/)

            if (charMatch) {
                console.log("Character Link Clicked:", charMatch[1])
                pageStack.layers.push(Qt.resolvedUrl("../CharacterPage.qml"), {
                    characterId: parseInt(charMatch[1])
                })
            } else if (animeMatch) {
                console.log("Anime Link Clicked:", animeMatch[1])
                pageStack.layers.push(Qt.resolvedUrl("../AnimePage.qml"), {
                    animeId: parseInt(animeMatch[1])
                })
            } else if (mangaMatch) {
                console.log("Manga Link Clicked:", mangaMatch[1])
                pageStack.layers.push(Qt.resolvedUrl("../MangaPage.qml"), {
                    anilistId: parseInt(mangaMatch[1])
                })
            } else if (staffMatch) {
                console.log("Staff Link Clicked:", staffMatch[1])
                pageStack.layers.push(Qt.resolvedUrl("../StaffPage.qml"), {
                    staffId: parseInt(staffMatch[1])
                })
            } else if (studioMatch) {
                console.log("Studio Link Clicked:", studioMatch[1])
                pageStack.layers.push(Qt.resolvedUrl("../StudioPage.qml"), {
                    studioId: parseInt(studioMatch[1])
                })
            } else {
                Qt.openUrlExternally(link)
            }
        }

        wrapMode:   Text.WordWrap
        textFormat: Text.RichText
        color: root.color
    }
}
