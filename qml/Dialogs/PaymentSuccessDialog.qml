import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root
    width: 448
    height: 303.28
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    signal confirmClicked()
    signal cancelClicked()

    background: null
    padding: 0

    Rectangle {
        id: dialogCard
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 0.65

        Column {
            width: dialogCard.width - 48
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 0

            // 标题
            Item {
                width: parent.width
                height: 24

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Security Domain Instance Payment Confirmation")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0F172B"
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
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

            // 标题与图标之间 48px 间距（整块向下微调，使浅绿色背景及下方内容整体下移）
            Item { width: parent.width; height: 48 }

            // 成功图标容器
            Rectangle {
                width: 64
                height: 64
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#DCFCE7"

                Image {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    source: Qt.resolvedUrl("icons/icon-check-success.svg")
                    fillMode: Image.PreserveAspectFit
                }
            }

            // 图标与文字之间 16px 间距
            Item { width: parent.width; height: 16 }

            // "支付成功"文字（bounding box 高度 24px）
            Item {
                width: parent.width
                height: 24

                SelectableText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Payment Successful")
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: "#0F172B"
                }
            }

            // 文字与按钮之间 40px 间距
            Item { width: parent.width; height: 40 }

            // "确定"按钮
            Rectangle {
                width: dialogCard.width - 48
                height: 36
                radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                color: {
                    if (confirmMouseArea.pressed) return Qt.darker("#0F4C81", 1.2)
                    if (confirmMouseArea.containsMouse) return Qt.lighter("#0F4C81", 1.15)
                    return "#0F4C81"
                }
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: qsTr("OK")
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
                        root.confirmClicked()
                        root.close()
                    }
                }
            }
        }
    }
}
