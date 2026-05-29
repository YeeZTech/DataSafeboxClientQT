import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: badge
    property string status: ""
    property string displayText: Theme.Colors.translateStatus(status)
    property var statusStyle: Theme.Colors.getStatusColor(status)
    property int textPixelSize: Theme.Typography.small
    readonly property bool truncated: badgeText.truncated

    implicitWidth: badgeText.implicitWidth + 12
    implicitHeight: 24
    radius: 6
    color: statusStyle.bg
    border.color: statusStyle.border
    border.width: 1
    clip: true

    Text {
        id: badgeText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        text: badge.displayText
        font.pixelSize: badge.textPixelSize
        font.weight: Font.Medium
        color: badge.statusStyle.text
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
        wrapMode: Text.NoWrap
    }
}
