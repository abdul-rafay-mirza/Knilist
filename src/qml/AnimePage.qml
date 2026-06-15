import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: animePage
    title: "Anime Page"

    property var animeTitle
    property var animeBannerImage
    property var animeCoverImage
    property var animeDescription
    property var animeRelations: []

    Connections {
        target: anilistService

        function onAnimePageLoaded(_title, _bannerImage, _coverImage, _description, _relationsJson) {
            animeTitle       = _title
            animeBannerImage = _bannerImage
            animeCoverImage  = _coverImage
            animeDescription = _description
            animeRelations   = JSON.parse(_relationsJson)
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: mainColumn.implicitHeight
        clip: true

        flickableDirection: Flickable.VerticalFlick
        interactive: true

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
        }

        ColumnLayout {
            id:    mainColumn
            width: parent.width
            
            Header {
                Layout.fillWidth: true
                title:       animePage.animeTitle
                bannerImage: animePage.animeBannerImage
                coverImage:  animePage.animeCoverImage
                description: animePage.animeDescription
            }

            RelationsSection {
                Layout.fillWidth: true
                relations: animePage.animeRelations
            }
        }
    }
}