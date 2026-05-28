import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

Popup {
    id: root

    property string title: ""
    property int dialogWidth: 500
    default property alias content: contentContainer.data

    width: dialogWidth
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0

    background: null
    padding: 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1

        Column {
            id: dialogLayout
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                visible: root.title !== ""
                text: root.title
                font.pixelSize: Theme.Typography.h2
                font.weight: Font.Bold
                color: Theme.Colors.textHeading
            }

            Item {
                id: contentContainer
                width: parent.width
                height: parent.height - (root.title !== "" ? 40 : 0)
            }
        }
    }
}
