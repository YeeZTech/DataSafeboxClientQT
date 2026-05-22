import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root
    width: 448
    height: 382
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    property string instanceSize: "250 GB"
    property string instanceFee: "2 months"
    property string billingRule: "30 CNY/GB/Month"
    // 仅存数值部分，文案中统一追加“元”单位
    property string estimatedFee: "350.00"
    property string durationText: ""

    signal confirmClicked(string durationText)
    signal cancelClicked()

    background: null
    padding: 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: "#d1d5db"
        border.width: 1

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            anchors.bottomMargin: 20
            spacing: 0

            // 标题行（24px 高，文字 18px）
            Item {
                width: parent.width
                height: 18

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Security Domain Instance Payment Confirmation")
                    font.pixelSize: 18    // 与 Figma 一致
                    font.weight: Font.DemiBold
                    color: "#0f172b"
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 24
                    height: 24
                    radius: 12
                    color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close()
                            root.cancelClicked()
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 1.5
                        rotation: 45
                        color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 1.5
                        rotation: -45
                        color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                    }
                }
            }

            // 标题与黄色提示块之间 28px 间距（累计向下偏移 12px）
            Item { width: parent.width; height: 28 }

            // 黄色提示块
            Rectangle {
                width: parent.width
                height: 81
                radius: 10
                color: "#fffbeb"
                border.width: 0.65
                border.color: "#fee685"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    anchors.topMargin: 16
                    anchors.bottomMargin: 4    // 模拟 pb-[0.653px]
                    spacing: 12

                    Image {
                        width: 20
                        height: 20
                        anchors.top: warningText.top
                        source: Qt.resolvedUrl("icons/icon-warnning.svg")
                        fillMode: Image.PreserveAspectFit
                    }

                    SelectableText {
                        id: warningText
                        width: 320
                        wrapMode: TextEdit.Wrap
                        text: qsTr("Instantiating this security domain requires payment of the following fees:")
                        font.pixelSize: 14
                        color: "#314158"
                    }
                }
            }

            // 黄色提示块与明细区域之间 16px 间距
            Item { width: parent.width; height: 16 }

            // 费用明细区域（h≈129px）
            Column {
                width: parent.width
                spacing: 12

                // 存储空间
                Item {
                    width: parent.width
                    height: 20

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Storage Space:")
                        font.pixelSize: 14
                        color: "#45556c"
                    }

                    SelectableText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.instanceSize
                        font.pixelSize: 14
                        color: "#0f172b"
                    }
                }

                // 实例费
                Item {
                    width: parent.width
                    height: 20

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Instance Duration:")
                        font.pixelSize: 14
                        color: "#45556c"
                    }

                    SelectableText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.instanceFee
                        font.pixelSize: 14
                        color: "#0f172b"
                    }
                }

                // 计费规则
                Item {
                    width: parent.width
                    height: 20

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Billing Rule:")
                        font.pixelSize: 14
                        color: "#45556c"
                    }

                    SelectableText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.billingRule
                        font.pixelSize: 14
                        color: "#0f172b"
                    }
                }

                // 分割线
                Rectangle {
                    width: parent.width
                    height: 0.65
                    color: Qt.rgba(0, 0, 0, 0.1)
                }

                // 预计费用
                Item {
                    width: parent.width
                    height: 20

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Estimated Fee:")
                        font.pixelSize: 14
                        color: "#45556c"
                    }

                    SelectableText {
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.estimatedFee + qsTr(" CNY")
                        font.pixelSize: 14
                        color: "#0f172b"
                    }
                }
            }

            // 明细与按钮之间 24px 间距
            Item { width: parent.width; height: 24 }

            // 底部按钮区：与 Figma 的 61px/88px 宽度和 8px 间距对齐
            Row {
                width: parent.width
                height: 36
                spacing: 8
                layoutDirection: Qt.RightToLeft

                // 确认按钮
                Rectangle {
                    width: 88
                    height: 36
                    radius: 8
                    color: {
                        if (confirmMouseArea.pressed) return Qt.lighter("#0f4c81", 1.3)
                        if (confirmMouseArea.containsMouse) return Qt.lighter("#0f4c81", 1.2)
                        return "#0f4c81"
                    }
                    Behavior on color { ColorAnimation { duration: 300 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Confirm Payment")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        id: confirmMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.confirmClicked(root.durationText)
                            root.close()
                        }
                    }
                }

                // 取消按钮
                Rectangle {
                    width: 61
                    height: 36
                    radius: 8
                    color: {
                        if (cancelMouseArea2.pressed) return "#bedbff"
                        if (cancelMouseArea2.containsMouse) return "#e8f8ff"
                        return "white"
                    }
                    border.width: 1
                    border.color: {
                        if (cancelMouseArea2.pressed) return "#add3e6"
                        if (cancelMouseArea2.containsMouse) return "#79aecd"
                        return "#cad5e2"
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#314158"
                    }

                    MouseArea {
                        id: cancelMouseArea2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close()
                            root.cancelClicked()
                        }
                    }
                }
            }
        }
    }
}
