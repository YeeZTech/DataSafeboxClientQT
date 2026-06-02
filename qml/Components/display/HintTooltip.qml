import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

// 深蓝提示气泡，样式与"查看功能介绍"引导气泡一致 (#1a3d6e + 顶部高光描边)，
// 底部带向下小三角，默认显示在父项上方并指向父项中心。
// 用法：HintTooltip { parent: someItem; text: "..."; visible: someHoverCondition }
ToolTip {
    id: control

    readonly property color bubbleColor: "#1a3d6e"
    readonly property int arrowWidth: 16
    readonly property int arrowHeight: 9

    delay: 150
    padding: 0

    // 悬浮在父项上方，留 6px 间距；气泡水平居中于父项，三角对准父项中心。
    x: parent ? (parent.width - width) / 2 : 0
    y: -height - 6

    background: null

    contentItem: Item {
        implicitWidth: bubble.width
        implicitHeight: bubble.height + control.arrowHeight

        Rectangle {
            id: bubble
            width: label.implicitWidth + 24
            height: label.implicitHeight + 16
            radius: 8
            color: control.bubbleColor

            // 顶部高光描边，与引导气泡一致
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: control.text
                color: "white"
                font.pixelSize: Theme.Typography.caption
            }
        }

        // 向下小三角，居中于气泡底部
        Canvas {
            id: arrow
            width: control.arrowWidth
            height: control.arrowHeight
            x: (bubble.width - width) / 2
            y: bubble.height - 1
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = control.bubbleColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width / 2, height);
                ctx.lineTo(width, 0);
                ctx.closePath();
                ctx.fill();
            }
            Component.onCompleted: requestPaint()
        }
    }
}
