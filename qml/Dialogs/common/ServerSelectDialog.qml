import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

// 登录前"选择服务器"弹窗：官方服务器 = 正式环境配置；自有服务器 = 输入后端
// baseUrl 检索内置配置（见 ServerAddressDialog）。切换经由持久化 + 重启生效。
BaseDialog {
    id: root
    dialogWidth: 417
    title: qsTr("Select Server")

    // true = 自有服务器；打开前由调用方按当前环境预选
    property bool useOwnServer: false

    signal connectRequested(bool ownServer)

    Column {
        width: parent.width
        spacing: 24

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/icons/SafeLogo.svg"
            sourceSize: Qt.size(64, 64)
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: [
                    {
                        "label": qsTr("Official Server"),
                        "own": false
                    },
                    {
                        "label": qsTr("Own Server"),
                        "own": true
                    }
                ]

                MouseArea {
                    readonly property bool checked: root.useOwnServer === modelData.own

                    width: optionRow.implicitWidth
                    height: 22
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.useOwnServer = modelData.own

                    Row {
                        id: optionRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 2
                            color: checked ? Theme.Colors.primary : Theme.Colors.backgroundWhite
                            border.color: checked ? Theme.Colors.primary : Theme.Colors.borderField
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                visible: checked
                                text: "✓"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: Theme.Typography.body
                            color: Theme.Colors.textHeading
                        }
                    }
                }
            }
        }

        PrimaryButton {
            anchors.right: parent.right
            text: qsTr("Connect")
            onClicked: {
                root.close();
                root.connectRequested(root.useOwnServer);
            }
        }
    }
}
