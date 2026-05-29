import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string title: ""
    property real contentMargins: 24
    property real contentSpacing: 24
    property color borderColor: "transparent"
    property real borderWidth: 0
    default property alias content: contentArea.data

    width: parent ? parent.width : 200
    height: contentMargins * 2 + contentLayout.implicitHeight
    radius: 14
    color: Theme.Colors.backgroundWhite
    border.color: borderColor
    border.width: borderWidth
    antialiasing: true

    Column {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.contentSpacing

        Text {
            visible: root.title !== ""
            text: root.title
            font.pixelSize: Theme.Typography.h3
            font.weight: Font.DemiBold
            color: Theme.Colors.textHeading
        }

        Item {
            id: contentArea
            width: parent.width
            height: childrenRect.height
        }
    }
}
