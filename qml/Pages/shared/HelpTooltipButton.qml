import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Item {
    id: root

    property string tooltipText: ""
    property string fontFamily: "Microsoft YaHei"
    property int tooltipWidth: 240
    property int tooltipFontSize: 10
    property color tooltipColor: "#1d4171"

    width: 16
    height: 16

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "qrc:/icons/icon-help.svg"
        sourceSize: Qt.size(16, 16)
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
    }

    MouseArea {
        id: helpButtonMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    Rectangle {
        id: helpTooltip
        visible: helpButtonMouseArea.containsMouse
        x: parent.width / 2 - width / 2
        y: -height - 4
        width: root.tooltipWidth
        height: tooltipLabel.implicitHeight + 16
        color: root.tooltipColor
        radius: 8
        z: 1000

        Text {
            id: tooltipLabel
            anchors.fill: parent
            anchors.margins: 8
            text: root.tooltipText
            font.family: root.fontFamily
            font.pixelSize: root.tooltipFontSize
            lineHeight: 15
            lineHeightMode: Text.FixedHeight
            color: Theme.Colors.primaryText
            wrapMode: Text.WordWrap
        }

        Canvas {
            width: 10
            height: 6
            x: parent.width / 2 - width / 2
            y: parent.height

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.tooltipColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(10, 0);
                ctx.lineTo(5, 6);
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
