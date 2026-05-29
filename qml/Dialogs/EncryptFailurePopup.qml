import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Popup {
    id: root
    parent: Overlay.overlay
    width: 420
    height: failureContent.implicitHeight + 48
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: Overlay.overlay ? (Overlay.overlay.width - width) / 2 : 0
    y: Overlay.overlay ? (Overlay.overlay.height - height) / 2 : 0

    property string errorText: ""

    signal retryRequested
    signal contactSupportRequested

    background: Rectangle {
        radius: 12
        color: "#ffffff"
        border.color: Theme.Colors.borderSeparator
        border.width: 1
        layer.enabled: true
    }

    Column {
        id: failureContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        spacing: 16

        Item {
            width: parent.width
            height: 24
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Encryption Failed")
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Theme.Colors.textHeading
            }
            Rectangle {
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 12
                color: failureCloseBtnArea.containsMouse ? Theme.Colors.backgroundGray : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 20
                    color: failureCloseBtnArea.containsMouse ? Theme.Colors.primary : Theme.Colors.textLabel
                }
                MouseArea {
                    id: failureCloseBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Item {
            width: parent.width
            height: 72
            Rectangle {
                width: 56
                height: 56
                anchors.centerIn: parent
                radius: 28
                color: "#fee2e2"
                border.color: "transparent"
                border.width: 0
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#ef4444"
                }
            }
        }

        Text {
            width: parent.width
            text: qsTr("Encryption Failed")
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Theme.Colors.textHeading
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            textFormat: Text.RichText
            text: qsTr("File encryption failed. Reason: ") + "<a href='https://help.yeez.tech/docs/bu-zhou-5-mai-fang-jia-mi-yuan-shi-shu-ju' style='color:#ef4444;text-decoration:underline;'>" + root.errorText + "</a>，" + qsTr(" You may try encrypting again or contact support for help.")
            font.pixelSize: 14
            color: "#475569"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            onLinkActivated: Qt.openUrlExternally(link)
        }

        Row {
            anchors.right: parent.right
            spacing: 12
            topPadding: 4

            SecondaryButton {
                text: qsTr("Contact Support")
                onClicked: {
                    root.close();
                    root.contactSupportRequested();
                }
            }

            PrimaryButton {
                text: qsTr("Retry")
                onClicked: {
                    root.close();
                    root.retryRequested();
                }
            }
        }
    }
}
