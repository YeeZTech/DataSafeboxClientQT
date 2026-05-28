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
        border.color: "#e2e8f0"
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
                color: "#0f172b"
            }
            Rectangle {
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 12
                color: failureCloseBtnArea.containsMouse ? "#f0f4fa" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 20
                    color: failureCloseBtnArea.containsMouse ? "#0f4c81" : "#314158"
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
            color: "#0f172b"
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

            Rectangle {
                width: contactSupportText.implicitWidth + 24
                height: 36
                radius: 8
                color: contactSupportArea.pressed ? "#dce8f5" : contactSupportArea.containsMouse ? "#eef4fb" : "white"
                border.color: contactSupportArea.containsMouse ? "#1d4ed8" : "#94a3b8"
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Text {
                    id: contactSupportText
                    anchors.centerIn: parent
                    text: qsTr("Contact Support")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "#334155"
                }
                MouseArea {
                    id: contactSupportArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close();
                        root.contactSupportRequested();
                    }
                }
            }

            Rectangle {
                width: retryBtnText.implicitWidth + 32
                height: 36
                radius: 8
                color: retryArea.pressed ? Qt.darker("#0f4c81", 1.2) : retryArea.containsMouse ? Qt.lighter("#0f4c81", 1.15) : "#0f4c81"
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Text {
                    id: retryBtnText
                    anchors.centerIn: parent
                    text: qsTr("Retry")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "white"
                }
                MouseArea {
                    id: retryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close();
                        root.retryRequested();
                    }
                }
            }
        }
    }
}
