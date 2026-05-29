import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    parent: Overlay.overlay
    dialogWidth: 420
    title: qsTr("Encryption Successful")

    property string encryptOutputDir: ""

    Column {
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 72
            Rectangle {
                width: 56
                height: 56
                anchors.centerIn: parent
                radius: 28
                color: "#dcfce7"
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
            font.pixelSize: Theme.Typography.h3
            font.weight: Font.Medium
            color: Theme.Colors.textHeading
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: qsTr("File encryption successful! You can send the encrypted file to the recipient. After importing it into their security domain instance, they will be able to use it normally.")
            font.pixelSize: Theme.Typography.body
            color: "#475569"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.right: parent.right
            spacing: 12
            topPadding: 4

            LinkText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("View Encrypted File Guide")
                onClicked: Qt.openUrlExternally("https://help.yeez.tech/docs/bu-zhou-5-mai-fang-jia-mi-yuan-shi-shu-ju")
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
