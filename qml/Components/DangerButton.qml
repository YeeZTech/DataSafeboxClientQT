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
            return Theme.Colors.buttonDisabled;
        if (mouseArea.pressed)
            return "#A40E20";
        if (mouseArea.containsMouse)
            return "#FD7977";
        return "#FB2C36";
    }

    Behavior on color {
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
        color: root.enabled ? "#FFFFFF" : "#90a1b9"
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
