import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

// 使用方（非安全域创建方）在安全域详情页点击"加密文件"按钮时的提示弹窗 (PRD 3.6)。
// 仅作提示，"取消"与"确定"均只关闭弹窗，不执行任何操作。
BaseDialog {
    id: root
    dialogWidth: 480
    title: qsTr("Encrypt File")

    Column {
        width: parent.width
        spacing: 28

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Encryption can only be performed by the security domain creator. As a user, you only need to receive the encrypted files and import them into a security domain instance to use them normally.")
            font.pixelSize: Theme.Typography.body
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            color: Theme.Colors.textCaption
        }

        Row {
            anchors.right: parent.right
            spacing: 16
            height: 36

            SecondaryButton {
                text: qsTr("Cancel")
                accent: true
                onClicked: root.close()
            }

            PrimaryButton {
                text: qsTr("OK")
                onClicked: root.close()
            }
        }
    }
}
