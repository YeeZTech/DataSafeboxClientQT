import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    title: qsTr("Encryption Successful")

    property string encryptOutputDir: ""
    // 本轮加密产出的 .sealed 路径。非空且信令服务已配置时，才提供"传输文件"
    // 入口 —— 一次只发一个文件，取最后一个产物。
    property string encryptedFilePath: ""

    // 用户选择把加密文件直接传给命令行客户端，由宿主页面打开发送弹窗。
    signal sendToCliRequested(string filePath)

    readonly property bool _canSendToCli: root.encryptedFilePath !== "" && AppConfig.transferSignalUrl() !== ""

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
            font.pixelSize: Theme.Typography.small
            color: Theme.Colors.textLabel
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        // 链接单独占一行、按钮右对齐另起一行：中英文案在一行里放不下
        // (链接 + 两个按钮会超出弹窗宽度并从左侧溢出)，拆两行可保证不溢出。
        Column {
            width: parent.width
            spacing: 12
            topPadding: 4

            LinkText {
                text: qsTr("View Encrypted File Guide")
                onClicked: Qt.openUrlExternally("https://help.yeez.tech/docs/bu-zhou-5-mai-fang-jia-mi-yuan-shi-shu-ju")
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                SecondaryButton {
                    accent: true
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

                PrimaryButton {
                    visible: root._canSendToCli
                    text: qsTr("Transfer File")
                    onClicked: {
                        root.close();
                        root.sendToCliRequested(root.encryptedFilePath);
                    }
                }
            }
        }
    }
}
