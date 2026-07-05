import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// This is a page that gives all characters of a given series (can be anime, manga)

Kirigami.Page {
    id: allCharactersPage
    title: "All Characters From " + mediaTitle

    property var anilistId: 0
    property var mediaTitle: "Null"

    Controls.Label {
        text: "Anilist ID: " + anilistId
    }
}