import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Reusable "heading + separator + wrapping row of cover cards" block.
// Covers Appearances / Favorite Anime / Favorite Manga / Favorite Staff.
ColumnLayout {
    id: mediaCoverCardsSection

    property string heading: ""
    property var model: []

    // AniList payloads aren't consistent about field names between
    // endpoints, so these are overridable per call site.
    property string idKey: "mediaId"
    property string titleKey: "title"
    property string imageKey: "coverImage"

    signal cardTapped(var entry)

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing
    visible: (mediaCoverCardsSection.model || []).length > 0

    Kirigami.Heading {
        level: 3
        text: mediaCoverCardsSection.heading
    }

    Kirigami.Separator { Layout.fillWidth: true }

    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: mediaCoverCardsSection.model

            MediaCoverCard {
                mediaId:  modelData[mediaCoverCardsSection.idKey]
                title:    modelData[mediaCoverCardsSection.titleKey] || ""
                imageURL: modelData[mediaCoverCardsSection.imageKey] || ""
                onTapped: mediaCoverCardsSection.cardTapped(modelData)
            }
        }
    }
}