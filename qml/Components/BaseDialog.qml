import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

Popup {
    id: root

    property string title: ""
    property int dialogWidth: 500
    property bool showCloseButton: true
    default property alias content: contentContainer.data

    signal closeRequested

    width: dialogWidth
    implicitHeight: dialogBg.implicitHeight
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0

    background: null
    padding: 0

    Rectangle {
        id: dialogBg
        width: root.dialogWidth
        height: root.height
        implicitHeight: dialogLayout.implicitHeight + 48
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1

        Column {
            id: dialogLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 16

            Item {
                visible: root.title !== ""
                width: parent.width
                height: visible ? 28 : 0

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    font.pixelSize: Theme.Typography.h2
                    font.weight: Font.Bold
                    color: Theme.Colors.textHeading
                }

                Rectangle {
                    visible: root.showCloseButton
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 12
                    color: closeBtnHover.containsMouse ? Theme.Colors.backgroundGray : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 18
                        color: closeBtnHover.containsMouse ? Theme.Colors.primary : Theme.Colors.textLabel
                    }

                    MouseArea {
                        id: closeBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeRequested();
                            root.close();
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                width: parent.width
                implicitHeight: childrenRect.height
                height: implicitHeight
            }
        }
    }
}
