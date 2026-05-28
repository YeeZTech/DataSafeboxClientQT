import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string text: ""
    property bool enabled: true
    property int fontSize: Theme.Typography.body
    property int fontWeight: Font.Medium

    signal clicked

    width: implicitWidth
    height: 36
    implicitWidth: Math.max(88, buttonText.implicitWidth + 32)
    radius: 8
    opacity: enabled ? 1.0 : 0.6
    color: {
        if (!enabled)
            return "#f1f5f9";
        if (mouseArea.pressed)
            return Qt.darker("#f1f5f9", 1.05);
        if (mouseArea.containsMouse)
            return Qt.lighter("#f1f5f9", 1.02);
        return "#f1f5f9";
    }
    border.color: {
        if (mouseArea.containsMouse || mouseArea.pressed)
            return "#90a1b9";
        return "#cad5e2";
    }
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        color: root.enabled ? "#314158" : "#90a1b9"
        font.letterSpacing: -0.15
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled)
                root.clicked();
        }
    }
}
