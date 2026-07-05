import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "components"

Kirigami.Page {
    id: allStaffPage
    title: "All Staff Page for " + mediaTitle

    property int anilistId: 0
    property string mediaTitle: ""

    Controls.Label {
        text: "Anilist ID: " + anilistId
    }
}