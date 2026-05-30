import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

// AnimePage.qml
// This page stores anime details, just like how it is in this page https://anilist.co/anime/112608/Ive-Been-Killing-Slimes-for-300-Years-and-Maxed-Out-My-Level/
Kirigami.Page {
    id: animePage
    title: "Anime Page"

    property var animeId

    Controls.Label {
        text: "Anime ID: " + animeId
    }
}