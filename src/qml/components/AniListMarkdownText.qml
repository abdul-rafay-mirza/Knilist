import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../AniListMarkdown.js" as AniListMarkdown

// Drop-in replacement for the plain Controls.Label used for
// profile.about in ProfilePage.qml and UsersPage.qml:
//
//   Controls.Label {
//       text: profilePage.profile.about || ""
//       textFormat: Text.MarkdownText
//       wrapMode: Text.Wrap
//       onLinkActivated: (link) => Qt.openUrlExternally(link)
//   }
//
// becomes:
//
//   AniListMarkdownText {
//       rawMarkdown: profilePage.profile.about || ""
//   }
//
// Renders via TextEdit(readOnly) in RichText mode rather than Text with
// Text.MarkdownText, because AniList's real About syntax
// (img###(url) sizing tags, ~~~centered~~~ blocks, ~!spoilers!~, and raw
// passthrough HTML like <div align=right> / <img align="right" width="30%">)
// needs float/align support that Qt's own markdown parser doesn't have -
// see AniListMarkdown.js for the full conversion pipeline.
//
// Spoilers get a REAL tap-to-reveal delegate rather than a static CSS
// approximation: AniListMarkdown.toSegments() splits the converted output
// into alternating {type: "html"} and {type: "spoiler"} chunks, and this
// component lays them out as a Flow of TextEdit-per-html-chunk +
// SpoilerBar-per-spoiler-chunk, so the whole thing still reads as one
// continuous block of prose with an interactive redacted bar inline.
ColumnLayout {
    id: root

    // Public API
    property string rawMarkdown: ""
    property string rawHtml: ""   // NEW — pre-rendered HTML from AniList's asHtml:true.
                                   // When set (non-empty), takes priority over rawMarkdown
                                   // and skips the AniListMarkdown.js conversion pipeline
                                   // entirely, since the content is already HTML and running
                                   // it through the markdown converter again would corrupt it
                                   // (double-escaped entities, spoilers no longer recognised,
                                   // stray literal */_ in prose misread as emphasis).

    spacing: 0

    // When rawHtml is provided, wrap it as a single non-spoiler segment so the
    // same Flow/Repeater rendering below handles both paths uniformly — no
    // spoiler delegate is produced this way (see file-level note below), but
    // links, images, and everything else render through the identical
    // htmlDelegate used by the markdown path.
    readonly property var _segments: root.rawHtml.length > 0
        ? [{ type: "html", content: root.rawHtml }]
        : AniListMarkdown.toSegments(root.rawMarkdown, root.width)

    Flow {
        id: flow
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: root._segments

            delegate: Loader {
                // modelData.type picks which delegate to instantiate.
                // Using a Loader (rather than two always-present items
                // with visible: bindings) keeps a spoiler-free bio from
                // paying for any spoiler-delegate overhead at all.
                sourceComponent: modelData.type === "spoiler" ? spoilerDelegate : htmlDelegate

                property string segmentContent: modelData.content

                onLoaded: {
                    item.segmentContent = Qt.binding(function () { return segmentContent })
                }
            }
        }
    }

    Component {
        id: htmlDelegate

        TextEdit {
            id: textEdit
            property string segmentContent: ""

            // Each html segment is a fragment, not a full document - Qt's
            // RichText mode is tolerant of fragments (no <html>/<body>
            // wrapper required), so this is safe to feed straight in.
            text: segmentContent

            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.RichText
            clip: true

            // implicitWidth left unconstrained deliberately: sitting
            // inside a Flow, each TextEdit should size to its own content
            // (short segments between spoilers shouldn't stretch full
            // width), while wrapMode still applies once a segment is
            // long enough to need it. Flow gives each child its natural
            // width unless the child sets Layout.fillWidth, which we
            // intentionally don't here.

            color: Kirigami.Theme.textColor
            selectionColor: Kirigami.Theme.highlightColor
            selectedTextColor: Kirigami.Theme.highlightedTextColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            font.family: Kirigami.Theme.defaultFont.family

            onLinkActivated: (link) => Qt.openUrlExternally(link)

            HoverHandler {
                cursorShape: textEdit.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
            }
        }
    }

    Component {
        id: spoilerDelegate

        // Real click-to-reveal: starts redacted (background and text
        // color matched so nothing is legible), taps toggle to the
        // actual rendered content. Kept as its own small TextEdit so
        // links/bold/etc. INSIDE a spoiler still work once revealed
        // (see EDGE 8 in the parser's test suite - a spoiler containing
        // a link).
        Item {
            id: spoilerRoot
            property string segmentContent: ""
            property bool revealed: false

            implicitWidth: spoilerBackground.implicitWidth
            implicitHeight: spoilerBackground.implicitHeight

            Rectangle {
                id: spoilerBackground
                implicitWidth: spoilerText.implicitWidth + Kirigami.Units.smallSpacing * 2
                implicitHeight: spoilerText.implicitHeight + Kirigami.Units.smallSpacing
                radius: Kirigami.Units.cornerRadius
                color: spoilerRoot.revealed ? "transparent" : Kirigami.Theme.textColor
                opacity: spoilerRoot.revealed ? 1.0 : 0.85

                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                TextEdit {
                    id: spoilerText
                    anchors.centerIn: parent
                    text: spoilerRoot.segmentContent
                    readOnly: true
                    selectByMouse: spoilerRoot.revealed
                    enabled: spoilerRoot.revealed
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap

                    // Redacted state is entirely opacity-driven: text is
                    // fully transparent until revealed, so there's no
                    // color-matching trick to maintain (an earlier draft
                    // had a color ternary here that evaluated to the same
                    // value on both branches - dead code implying a
                    // mechanism that wasn't actually doing anything;
                    // removed rather than left in to avoid confusing a
                    // future reader about how the redaction works).
                    color: Kirigami.Theme.textColor
                    opacity: spoilerRoot.revealed ? 1.0 : 0.0

                    onLinkActivated: (link) => {
                        if (spoilerRoot.revealed) {
                            Qt.openUrlExternally(link)
                        }
                        // Ignore link taps while still redacted, so a tap
                        // meant to REVEAL the spoiler doesn't accidentally
                        // fire an embedded link the user can't even read yet.
                    }
                }

                TapHandler {
                    // Only handles the reveal tap; once revealed, taps
                    // pass through to spoilerText so its own link-tap
                    // handling and text selection work normally.
                    enabled: !spoilerRoot.revealed
                    onTapped: spoilerRoot.revealed = true
                }

                HoverHandler {
                    id: spoilerHover
                    cursorShape: spoilerRoot.revealed ? Qt.IBeamCursor : Qt.PointingHandCursor
                }

                Controls.ToolTip.visible: spoilerHover.hovered && !spoilerRoot.revealed
                Controls.ToolTip.text: "Click to show spoiler"
            }
        }
    }

    // ── Known limitations (documented rather than silently glossed over) ──
    //
    // 1. webm()/mp4() video embeds degrade to a plain link. TextEdit has
    //    no video element; an actual inline player would need a
    //    MediaPlayer + VideoOutput rendered as its own Flow delegate,
    //    following the same "extract from the text stream, render as a
    //    sibling component" pattern used for spoilers above. Not built
    //    here since no sample bio in scope used video embeds - flagging
    //    so it's a known gap rather than an assumed non-issue.
    //
    // 2. AniList's `~~~` block delimiter doesn't support nesting (matches
    //    upstream behavior - AniList's own renderer treats `~~~` as a
    //    single non-nesting pair too), so a bio that puts `~~~` inside
    //    `~~~` will not centre correctly. This is a real format
    //    limitation, not a bug in this converter.
    //
    // 3. Flow lays out html/spoiler delegates left-to-right, wrapping at
    //    the container width - this reproduces normal reading order
    //    correctly for spoilers embedded mid-paragraph, but a spoiler
    //    that spans what would be multiple visual lines in the original
    //    text may wrap differently than the surrounding TextEdit segments
    //    do, since each is an independently-sized Flow child rather than
    //    one continuously-reflowing text run. Acceptable for the common
    //    case (short inline spoilers) seen in real bios; a perfectly
    //    seamless reflow across the html/spoiler boundary would require
    //    a custom single text-layout engine, well beyond what TextEdit
    //    + Flow can offer.
    // 4. When rawHtml is used instead of rawMarkdown (AniList's asHtml:true
    //    output), spoilers (~!...!~) are NOT interactive — AniList's server-
    //    rendered HTML wraps them in its own markup (not ~!...!~ syntax,
    //    which has already been converted server-side), so _extractSpoilers
    //    finds nothing to pull out. Spoiler text in rawHtml mode renders
    //    directly, unredacted. If AniList's asHtml spoiler markup is ever
    //    inspected and found to be parseable (e.g. a consistent CSS class),
    //    a rawHtml-specific spoiler extraction pass could be added here —
    //    not attempted yet since the actual markup shape hasn't been
    //    confirmed against a live response.
}
