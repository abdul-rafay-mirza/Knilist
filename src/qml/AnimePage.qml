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

    Connections {
        target: anilistService

        function onAnimePageLoaded(_title, _bannerImage, _coverImage, _description) {
            animeTitle       = _title
            animeBannerImage = _bannerImage
            animeCoverImage  = _coverImage
            animeDescription = _description
        }
    }

    ColumnLayout {
        anchors.fill: parent

        Header {
            Layout.fillWidth: true
            title:       animePage.animeTitle
            bannerImage: animePage.animeBannerImage
            coverImage:  animePage.animeCoverImage
            description: animePage.animeDescription
        }

        Item { Layout.fillHeight: true }
    }
}