import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string title: ""
    default property alias content: contentArea.data

    width: parent ? parent.width : 200
    height: 48 + contentLayout.implicitHeight
    radius: 14
    color: Theme.Colors.backgroundWhite
    antialiasing: true

    Column {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

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
