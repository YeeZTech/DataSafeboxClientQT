import QtQuick 2.15

// 简易投影：通过偏移矩形近似实现，无外部依赖
// 使用：在带 radius 的容器内放置 ShadowBox { cornerRadius: 30 }
Rectangle {
    property real cornerRadius: 30
    property color shadowColor: "#10000000"

    z: -1
    anchors.fill: parent
    anchors.topMargin: 4
    anchors.leftMargin: 2
    anchors.rightMargin: -2
    color: shadowColor
    radius: cornerRadius
}
