import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

// "自有服务器"地址输入弹窗：以后端 baseUrl 检索内置服务配置（由调用方通过
// AppConfig.serverIdForBaseUrl 完成），命中则切换到对应环境，未命中就地报错。
BaseDialog {
    id: root
    dialogWidth: 417
    title: qsTr("Server Address")

    property alias address: addressInput.text
    property bool hasError: false

    signal confirmed(string address)

    onClosed: root.hasError = false

    Column {
        width: parent.width
        spacing: 8

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: addressInput.activeFocus ? "white" : (inputHoverArea.containsMouse ? "#e9eef6" : "white")
            border.color: root.hasError ? "#c10007" : Theme.Colors.borderField
            border.width: 1
            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            MouseArea {
                id: inputHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            TextInput {
                id: addressInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textPrimary
                selectByMouse: true
                selectionColor: Theme.Colors.accent
                selectedTextColor: Theme.Colors.textHeading
                clip: true

                onTextChanged: root.hasError = false

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Enter server address")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textSecondary
                    visible: !addressInput.text && !addressInput.activeFocus
                }
            }

            InputContextMenu {
                anchors.fill: parent
                target: addressInput
            }
        }

        Text {
            width: parent.width
            text: qsTr("Address example: http://your.domain.name")
            font.pixelSize: Theme.Typography.small
            color: Theme.Colors.textCaption
        }

        Row {
            width: parent.width
            spacing: 4
            height: 20
            visible: root.hasError

            Image {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/icons/icon-error.svg"
                sourceSize: Qt.size(16, 16)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("No server configuration found for this address")
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textError
            }
        }

        Item {
            width: parent.width
            height: 16
        }

        PrimaryButton {
            anchors.right: parent.right
            text: qsTr("OK")
            enabled: addressInput.text.trim() !== ""
            onClicked: root.confirmed(addressInput.text.trim())
        }
    }
}
