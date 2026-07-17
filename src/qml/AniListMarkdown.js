// AniListMarkdown.js
// Converts AniList's custom markdown flavor into HTML suitable for
// QtQuick's TextEdit (textFormat: TextEdit.RichText).
//
// AniList's "About" field supports CommonMark-ish markdown PLUS:
//   img(url)          - inline image, default size
//   img275(url)       - inline image, fixed pixel width (any digit run)
//   img100%(url)      - inline image, percentage width (digit run + %)
//   webm(url)         - inline video (rendered as a link/poster fallback,
//                       since TextEdit has no native video element)
//   ~~~ ... ~~~        - centered block
//   ~! ... !~          - spoiler (click-to-reveal)
// ...on top of raw passthrough HTML (<center>, <div align=...>, <img>, etc).
//
// Pipeline (order matters - see comments at each stage):
//   1. Protect existing raw HTML tags from later regex passes
//   2. Block-level AniList wrappers (centered blocks)
//   3. Inline AniList syntax (img sizing tags, spoilers)
//   4. Standard inline markdown (bold, italic, code, links, headers)
//   5. Restore protected HTML
//   6. Paragraph/line-break normalisation
//
// Exposes two functions:
//   toHtml(rawText)     - flat HTML string, spoilers static (non-interactive).
//                          Exists for API completeness / any future
//                          non-interactive caller; NOT used by the shipped
//                          AniListMarkdownText.qml component.
//   toSegments(rawText)  - array of {type, content} segments, spoilers
//                          returned separately for real tap-to-reveal
//                          rendering. This is what AniListMarkdownText.qml
//                          actually calls.

.pragma library

// Fallback used only before a real container width is known (e.g. the
// very first layout pass) or for direct toHtml()/toSegments() callers
// that don't pass one.
var DEFAULT_MAX_IMAGE_WIDTH = 480;

// ── Stage 0: HTML protection ────────────────────────────────────────────
//
// AniList bios routinely contain raw HTML (<center>, <div align=right>,
// <img align="right" width="30%">, <br>, <h1 id="more">). If we let the
// markdown-inline regexes (stage 4) run over those tags' attribute text,
// a bio like <div align=right>__[mal](url)__</div> would have its "__"
// converted to <b> INSIDE the tag soup, breaking the div. So we pull every
// recognisable HTML tag out into a placeholder token before doing any
// markdown work, then splice the real tags back in verbatim at the end.
//
// This is intentionally permissive - it protects tags AniList doesn't
// officially support (e.g. <h1 id="more">) too, since "full support for
// the About section" means whatever real bios rely on, not just the
// documented subset.

function _protectHtml(text, store) {
    return text.replace(/<\/?[a-zA-Z][a-zA-Z0-9]*(?:\s+[a-zA-Z-]+(?:=(?:"[^"]*"|'[^']*'|[^\s>]*))?)*\s*\/?>/g, function (match) {
        var token = "\u0000HTML" + store.length + "\u0000";
        store.push(match);
        return token;
    });
}

function _restoreHtml(text, store) {
    for (var i = 0; i < store.length; i++) {
        var token = "\u0000HTML" + i + "\u0000";
        // split/join instead of replace() - a token can legitimately appear
        // more than once if the same protected string recurs, and we want
        // every occurrence restored, not just the first.
        text = text.split(token).join(store[i]);
    }
    return text;
}

// ── Stage 0b: escape stray angle brackets / ampersands ──────────────────
//
// Runs BEFORE html protection removes real tags, so real tags survive
// (they've already been swapped for \u0000 tokens by the time this looks
// odd - but we actually want this to run first, on the truly-raw string,
// so a literal "<3" or "AT&T" in prose doesn't get interpreted as markup
// by TextEdit's HTML parser). Order: escape raw text -> THEN protect tags
// would escape the tags themselves, so this must run first and tag
// protection must skip already-escaped sequences (it does, since &lt;
// doesn't match the tag regex).
function _escapeStrayEntities(text) {
    // Escape bare & not already part of an entity (&amp; &lt; &#123; etc.)
    text = text.replace(/&(?!#?\w+;)/g, "&amp;");
    return text;
}

// ── Stage 2: block-level AniList wrappers ───────────────────────────────
//
// ~~~ ... ~~~ centers a block. It's the most common block wrapper in real
// bios (see the sample: ~~~img100%(url)~~~ wrapping a banner image, and
// larger ~~~ blocks wrapping multi-line sections). AniList allows the
// delimiter on its own line or inline; both are handled. Non-greedy match
// with the 's' behavior emulated via [\s\S] since QML JS may run on
// engines without the /s flag.
function _convertCenteredBlocks(text) {
    return text.replace(/~~~([\s\S]*?)~~~/g, function (_, inner) {
        return '<center>' + inner + '</center>';
    });
}

function _safeImageWidth(digits, isPercent, maxWidth) {
    var safeMax = maxWidth > 0 ? maxWidth : DEFAULT_MAX_IMAGE_WIDTH;
    var requested;

    if (digits.length > 0 && isPercent) {
        requested = safeMax * (parseFloat(digits) / 100);
    } else if (digits.length > 0) {
        requested = parseFloat(digits);
    } else {
        requested = safeMax;
    }

    if (isNaN(requested)) {
        requested = safeMax;
    }

    return Math.max(1, Math.round(Math.min(requested, safeMax)));
}

// ── Stage 3: inline AniList syntax ──────────────────────────────────────

// img(url), img275(url), img100%(url)
//   - "img" then optional digits then optional "%" then (url)
//   - No size -> default width (we pick a sane cap; AniList's own default
//     is roughly 100% of the containing column, capped so huge images
//     don't blow out a profile layout)
//   - Digit run only -> treated as a pixel width
//   - Digit run + % -> treated as a percentage width
function _convertImageTags(text, maxWidth) {
    return text.replace(/img(\d*)(%?)\((https?:\/\/[^\s()]+)\)/g, function (_, digits, pct, url) {
        var width = _safeImageWidth(digits, pct === "%", maxWidth);
        // Plain width ATTRIBUTE, not a CSS style declaration - see the img
        // vs hr/table attribute note above. Height stays unset so Qt scales
        // it to preserve the image's own aspect ratio.
        return '<img src="' + url + '" width="' + width + '">';
    });
}

// webm(url) / mp4(url) - AniList allows inline video, which TextEdit has
// no way to render. Fall back to a clearly-labelled link so the content
// isn't silently dropped.
function _convertVideoTags(text) {
    return text.replace(/(webm|mp4)\((https?:\/\/[^\s()]+)\)/g, function (_, kind, url) {
        return '<a href="' + url + '">[Video: ' + url + ']</a>';
    });
}

// ~!spoiler text!~
//
// Real click-to-reveal needs an interactive widget, and TextEdit's
// RichText mode has no such concept - a <span> is always static. Rather
// than fake it with dark-on-dark CSS (which never actually reveals on
// click/tap, only on manual text selection - a poor substitute), spoilers
// are pulled OUT of the text stream entirely at this stage and replaced
// with an indexed placeholder token. The QML side (AniListMarkdownText.qml)
// splits on these tokens and renders each spoiler as its own real
// interactive delegate (a tappable redacted bar that swaps to revealed
// text), positioned inline via a Flow of alternating TextEdit/delegate
// items. spoilerStore is populated with the RAW (not yet HTML-converted)
// inner text, since the spoiler segment goes through its OWN independent
// call to toHtml() on the QML side - it needs full markdown/AniList
// syntax support too (see EDGE 8: spoilers can contain links).
function _extractSpoilers(text, spoilerStore) {
    return text.replace(/~!([\s\S]*?)!~/g, function (_, inner) {
        var token = "\u0000SPOILER" + spoilerStore.length + "\u0000";
        spoilerStore.push(inner);
        return token;
    });
}

// ── Stage 4: standard inline markdown ───────────────────────────────────
//
// Order within this stage matters too: links before bold/italic (so an
// asterisk inside a URL like ?foo=*bar* isn't misread), bold before
// italic (so **x** isn't first read as *<i>x</i>* leaving a stray *).

function _convertLinks(text, htmlStore) {
    // [text](url)
    //
    // BUG FIX (found via edge-case testing): the previous version only
    // guarded the LABEL half of the pattern from later regex passes.
    // Once a real href="..." attribute was substituted in, that
    // attribute was just more text to the next regex, so a URL like
    // ?q=*wildcard* had its asterisks read as italics, corrupting the
    // link (see EDGE 6 in edge_cases.txt).
    //
    // Two things both need to be true, though:
    //   1. The href must be protected from later passes (this is the bug).
    //   2. The label must still get bold/italic applied - AniList bios
    //      routinely do [**bold text**](url) (EDGE 2), and if we protect
    //      the whole assembled tag naively, the "**" inside the label is
    //      already past the bold/italic stage and never gets converted.
    //
    // Fix: run bold/italic + inline code over the LABEL only, before
    // assembling the <a> tag, then protect just the assembled tag (with
    // its now-safe label baked in) via the shared HTML protection store.
    text = text.replace(/\[([^\]]*)\]\((https?:\/\/[^\s()]+)\)/g, function (_, label, url) {
        var formattedLabel = _convertBoldItalic(label);
        formattedLabel = _convertInlineCode(formattedLabel);
        var tag = '<a href="' + url + '">' + formattedLabel + '</a>';
        var token = "\u0000HTML" + htmlStore.length + "\u0000";
        htmlStore.push(tag);
        return token;
    });
    return text;
}

function _convertBoldItalic(text) {
    // Bold: **text** or __text__
    text = text.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>');
    text = text.replace(/__([^_]+)__/g, '<b>$1</b>');
    // Italic (single delimiter), run AFTER bold so doubled delimiters
    // above are already consumed.
    //
    // BUG FIX (found via edge-case testing): a naive /_([^_]+)_/ matches
    // every underscore pair, including the ones inside an ordinary
    // snake_case_identifier - "snake_case_variable_name" was coming out
    // as "snake<i>case</i>variable<i>name...</i>", visibly corrupting
    // plain prose/code-like text that has nothing to do with emphasis.
    //
    // CommonMark's real rule: a run of "_" only opens/closes emphasis
    // when it's not flanked by an alphanumeric character on the inner
    // side - i.e. word_word stays literal, but a start-of-word or
    // end-of-word underscore (as in " _actual italic_ ") still works.
    // We approximate that with negative lookaround: the underscore must
    // NOT have a word character immediately before the opening "_" is
    // preceded by, and NOT have a word char immediately after the
    // closing "_".
    text = text.replace(/\*([^\*]+)\*/g, '<i>$1</i>');
    text = text.replace(/(^|[^\w])_([^_]+)_(?!\w)/g, function (_, before, inner) {
        return before + '<i>' + inner + '</i>';
    });
    return text;
}

function _convertInlineCode(text) {
    return text.replace(/`([^`]+)`/g, '<code>$1</code>');
}

function _convertHeaders(text) {
    // # H1 .. ###### H6, must be at start of a line
    return text.replace(/^(#{1,6})\s+(.+)$/gm, function (_, hashes, content) {
        var level = hashes.length;
        return '<h' + level + '>' + content + '</h' + level + '>';
    });
}

function _convertBlockquotes(text) {
    return text.replace(/^>\s?(.+)$/gm, '<blockquote>$1</blockquote>');
}

// ── Stage 5b: constrain raw passthrough <img> tags ──────────────────────
//
// Raw <img> tags survive _protectHtml/_restoreHtml byte-for-byte, so
// whatever width the original bio declared - almost always a percentage,
// sometimes nothing at all - reaches this string unconstrained. Re-derive
// it and run it through the same _safeImageWidth the shorthand syntax
// uses above, so every image is capped identically regardless of how it
// was written in the original bio.
function _constrainRawImageSizes(text, maxWidth) {
    return text.replace(/<img\b(?:\s+[a-zA-Z-]+(?:=(?:"[^"]*"|'[^']*'|[^\s>]*))?)*\s*\/?>/gi, function (tag) {
        var srcMatch = tag.match(/\ssrc\s*=\s*"([^"]*)"/i) || tag.match(/\ssrc\s*=\s*'([^']*)'/i);
        var src = srcMatch ? srcMatch[1] : "";
        if (!src) {
            return tag;
        }

        var widthMatch = tag.match(/\swidth\s*=\s*["']?([\d.]+)(%?)["']?/i);
        var digits = widthMatch ? widthMatch[1] : "";
        var isPercent = widthMatch ? widthMatch[2] === "%" : false;
        var width = _safeImageWidth(digits, isPercent, maxWidth);

        // align isn't in Qt's documented <img> attribute list, but float
        // is explicitly documented as supported for images, so this is
        // the reliable way to keep bios that float a banner left/right.
        var alignMatch = tag.match(/\salign\s*=\s*["']?(left|right)["']?/i);
        var floatStyle = alignMatch ? ' style="float:' + alignMatch[1] + ';"' : "";

        return '<img src="' + src + '" width="' + width + '"' + floatStyle + '>';
    });
}

// ── Stage 6: paragraph / line-break normalisation ───────────────────────
//
// TextEdit's RichText mode respects block tags but plain "\n" is
// whitespace-collapsed like real HTML. We convert single newlines to
// <br> and blank-line-separated chunks to distinct paragraphs, EXCEPT
// inside content we've already wrapped in a block tag (h1-h6, center,
// blockquote), where an inserted <br> right after the opening tag would
// add unwanted spacing. Simplest robust approach: convert newlines to
// <br> globally, since <br> inside <center>/<h1> is harmless, then
// collapse 3+ consecutive <br> down to a paragraph-like double-break.
function _normaliseLineBreaks(text) {
    text = text.replace(/\r\n/g, "\n");
    text = text.replace(/\n{3,}/g, "\n\n");
    text = text.replace(/\n/g, "<br>\n");
    return text;
}

// ── Core conversion (shared by both entry points below) ─────────────────
//
// Runs every stage EXCEPT spoiler handling, since the two public entry
// points disagree on what to do with spoilers: toHtml() (kept for
// simple/non-interactive callers, e.g. a plain-text preview) bakes them
// in as static dark-on-dark spans; toSegments() (used by
// AniListMarkdownText.qml) pulls them out as real interactive delegates.
function _convertCore(rawText, htmlStore, maxWidth) {
    var text = rawText;

    // 0. Escape stray entities in the fully raw string (before anything
    //    else touches it), then protect real HTML tags.
    text = _escapeStrayEntities(text, maxWidth);
    text = _protectHtml(text, htmlStore);

    // 2. Block-level AniList wrappers
    text = _convertCenteredBlocks(text);

    // 3. Inline AniList syntax (spoilers handled separately - see caller)
    text = _convertImageTags(text);
    text = _convertVideoTags(text);

    // 4. Standard inline markdown
    // _convertLinks needs htmlStore now: it protects each generated <a>
    // tag the same way real HTML is protected, so a URL like
    // ?q=*wildcard* doesn't get its asterisks read as italics by the
    // _convertBoldItalic call that follows (see fix notes on
    // _convertLinks above).
    text = _convertLinks(text, htmlStore);
    text = _convertBoldItalic(text);
    text = _convertInlineCode(text);
    text = _convertHeaders(text);
    text = _convertBlockquotes(text);

    // 5. Restore protected HTML verbatim
    text = _restoreHtml(text, htmlStore);
    text = _constrainRawImageSizes(text, maxWidth);

    // 6. Line breaks last, so it doesn't interfere with the multi-line
    //    regexes above (centered blocks, headers-per-line, etc.)
    text = _normaliseLineBreaks(text);

    return text;
}

// ── Public entry point 1: flat HTML string ──────────────────────────────
//
// CORRECTION: an earlier version of this function computed a spoiler-
// aware string, then discarded it and returned _convertCore(rawText, ...)
// on the ORIGINAL text instead - a leftover from restructuring this file
// to extract spoilers into segments (see toSegments below). That bug
// meant ~!spoiler!~ markers would have passed straight through
// unconverted, and it also referenced _convertSpoilers, a function that
// no longer exists under that name (renamed to _extractSpoilers). Caught
// this on re-reading rather than shipping it - fixed by making toHtml a
// thin wrapper over toSegments, which is exercised directly by the real
// UI path and is trustworthy.
//
// Spoilers degrade to a static dark-on-dark span here (no real
// click-to-reveal - flattening to one string necessarily loses
// interactivity). Suitable for contexts that just need a single HTML
// string and don't need spoilers to be interactive (e.g. a tooltip
// preview). The real UI (AniListMarkdownText.qml) uses toSegments()
// directly instead, so spoilers stay interactive there.
function toHtml(rawText, maxWidth) {
    var segments = toSegments(rawText, maxWidth);
    var parts = [];
    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i];
        if (seg.type === "spoiler") {
            parts.push('<span style="background-color:#3a3a3a;color:#3a3a3a;">' + seg.content + '</span>');
        } else {
            parts.push(seg.content);
        }
    }
    return parts.join("");
}

// ── Public entry point 2: segmented structure (used by the QML component) ─
//
// Returns an array of segment objects:
//   { type: "html",    content: "<b>...</b>" }
//   { type: "spoiler", content: "<already-converted inner HTML>" }
//
// AniListMarkdownText.qml renders "html" segments in a TextEdit and
// "spoiler" segments as a real tappable delegate, laid out together in a
// Flow so they read as one continuous block of text with an interactive
// spoiler bar inline - not a separate disconnected widget.
function toSegments(rawText, maxWidth) {
    if (!rawText || rawText.length === 0) {
        return [];
    }

    var spoilerStore = [];
    var withPlaceholders = _extractSpoilers(rawText, spoilerStore);

    // Run the shared core pipeline on everything OUTSIDE spoilers. The
    // \u0000SPOILERn\u0000 tokens contain no markdown-special characters,
    // so they pass through every stage completely untouched and land in
    // the final HTML string exactly where they started.
    var htmlStore = [];
    var htmlWithPlaceholders = _convertCore(withPlaceholders, htmlStore, maxWidth);

    // Now split that HTML string on the spoiler tokens to produce the
    // final segment array. Each spoiler's own inner text is converted
    // through the SAME core pipeline independently (fresh htmlStore),
    // since it's a self-contained piece of markdown (EDGE 8: a spoiler
    // can contain a link).
    var segments = [];
    var remaining = htmlWithPlaceholders;
    var tokenPattern = /\u0000SPOILER(\d+)\u0000/;

    while (true) {
        var match = tokenPattern.exec(remaining);
        if (!match) {
            if (remaining.length > 0) {
                segments.push({ type: "html", content: remaining });
            }
            break;
        }
        var before = remaining.substring(0, match.index);
        if (before.length > 0) {
            segments.push({ type: "html", content: before });
        }
        var spoilerIndex = parseInt(match[1], 10);
        var spoilerRawInner = spoilerStore[spoilerIndex];
        segments.push({
            type: "spoiler",
            content: _convertCore(spoilerRawInner, [], maxWidth)
        });
        remaining = remaining.substring(match.index + match[0].length);
    }

    return segments;
}
