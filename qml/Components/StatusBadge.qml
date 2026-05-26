import QtQuick 2.15
import "." as Theme

Rectangle {
    id: badge
    property string status: ""
    property string displayText: Theme.Colors.translateStatus(status)
    property var statusStyle: Theme.Colors.getStatusColor(status)
    property int textPixelSize: 14

    implicitWidth: badgeText.implicitWidth + 12
    implicitHeight: 24
    radius: 6
    color: statusStyle.bg
    border.color: statusStyle.border
    border.width: 1
    clip: true

    Text {
        id: badgeText
        anchors.centerIn: parent
        text: badge.displayText
        font.pixelSize: badge.textPixelSize
        font.weight: Font.Medium
        color: badge.statusStyle.text
        horizontalAlignment: Text.AlignHCenter
    }
}
