import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    title: qsTr("Encryption Successful")

    property string encryptOutputDir: ""

    Column {
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 72
            Rectangle {
                width: 64
                height: 64
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                radius: width / 2
                color: "#dcfce7"
                Image {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    source: "qrc:/icons/icon-check-success.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        Text {
            width: parent.width
            text: qsTr("Encryption Successful")
            font.pixelSize: Theme.Typography.h3
            color: Theme.Colors.textHeading
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: qsTr("File encryption successful! You can send the encrypted file to the recipient. After importing it into their security domain instance, they will be able to use it normally.")
            font.pixelSize: Theme.Typography.body
            color: "#45556c"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.right: parent.right
            spacing: 8
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
