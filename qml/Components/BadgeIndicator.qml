import QtQuick 2.15

// 红色数字角标 — 项目内统一样式
// 用法: BadgeIndicator { count: 5; x: 161 }
Rectangle {
    id: root
    property int count: 0
    visible: count > 0
    width: count > 99 ? 32 : (count > 9 ? 24 : 16)
    height: 16
    radius: 8
    color: "#D4183D"
    z: 10

    Text {
        anchors.centerIn: parent
        text: root.count > 99 ? "99+" : root.count.toString()
        font.pixelSize: 10
        font.weight: Font.Medium
        font.family: "Inter"
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "#FFFFFF"
    }
}
