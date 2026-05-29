import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Popup {
    id: root
    parent: Overlay.overlay
    width: 420
    height: successContent.implicitHeight + 48
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: Overlay.overlay ? (Overlay.overlay.width - width) / 2 : 0
    y: Overlay.overlay ? (Overlay.overlay.height - height) / 2 : 0

    property string encryptOutputDir: ""

    background: Rectangle {
        radius: 12
        color: "#ffffff"
        border.color: Theme.Colors.borderSeparator
        border.width: 1
        layer.enabled: true
    }

    Column {
        id: successContent
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
                text: qsTr("Encryption Successful")
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
                color: successCloseBtnArea.containsMouse ? Theme.Colors.backgroundGray : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 20
                    color: successCloseBtnArea.containsMouse ? Theme.Colors.primary : Theme.Colors.textLabel
                }
                MouseArea {
                    id: successCloseBtnArea
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
                color: "#dcfce7"
                border.color: "transparent"
                border.width: 0
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#22c55e"
                }
            }
        }

        Text {
            width: parent.width
            text: qsTr("Encryption Successful")
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Theme.Colors.textHeading
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: qsTr("File encryption successful! You can send the encrypted file to the recipient. After importing it into their security domain instance, they will be able to use it normally.")
            font.pixelSize: 14
            color: "#475569"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.right: parent.right
            spacing: 12
            topPadding: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("View Encrypted File Guide")
                font.pixelSize: 14
                font.underline: true
                color: guideLink.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : guideLink.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                MouseArea {
                    id: guideLink
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://help.yeez.tech/docs/bu-zhou-5-mai-fang-jia-mi-yuan-shi-shu-ju")
                }
            }

            PrimaryButton {
                text: qsTr("Open File Save Directory")
                onClicked: {
                    var p = root.encryptOutputDir;
                    if (p) {
                        var url = p.replace(/\\/g, "/");
                        if (!url.startsWith("file:"))
                            url = "file:///" + url;
                        Qt.openUrlExternally(url);
                    }
                    root.close();
                }
            }
        }
    }
}
