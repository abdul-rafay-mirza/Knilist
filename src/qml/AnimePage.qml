import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.ScrollablePage {
    id: animePage
    title: "Anime List"

    ListModel {
        id: animeModel

        ListElement {
            title:   "Classroom of the Elite 4th Season: Second Year, First Semester"
            type:    "TV"
            nextEp:  "Ep. 12 in 5 days."
            rating:  0
            watched: 11
            total:   16
            cover:   "https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/bx180745-OEZaBeEdWozn.png"
        }
        ListElement {
            title:   "Frieren: Beyond Journey's End"
            type:    "TV"
            nextEp:  "Finished"
            rating:  9
            watched: 28
            total:   28
            cover:   "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg"
        }
        ListElement {
            title:   "Solo Leveling Season 2 -Arise from the Shadow-"
            type:    "TV"
            nextEp:  "Ep. 8 in 3 days."
            rating:  7
            watched: 7
            total:   13
            cover:   "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx176496-9BDMjAZGEbq4.png"
        }
    }

    ListView {
        anchors.fill: parent
        model:   animeModel
        spacing: 10
        topMargin:    10
        bottomMargin: 10
        leftMargin:   10
        rightMargin:  10

        delegate: AnimeCard {
            width:           ListView.view.width - 20   // respect left/right margins
            title:           model.title
            mediaType:       model.type
            nextEpisodeText: model.nextEp
            rating:          model.rating
            watchedEpisodes: model.watched
            totalEpisodes:   model.total
            coverSource:     model.cover

            onAddEpisode: {
                // Increment watched count directly on the model
                if (model.watched < model.total) {
                    animeModel.setProperty(index, "watched", model.watched + 1)
                }
            }
        }
    }
}