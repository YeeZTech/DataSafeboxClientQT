import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string text: ""
    property bool enabled: true
    property bool loading: false
    property int fontSize: Theme.Typography.body
    property int fontWeight: Font.Normal

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
            return Qt.darker(Theme.Colors.primary, 1.2);
        if (mouseArea.containsMouse)
            return Qt.lighter(Theme.Colors.primary, 1.2);
        return Theme.Colors.primary;
    }

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: root.loading ? qsTr("Loading...") : root.text
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        color: root.enabled ? Theme.Colors.primaryText : "#90a1b9"
        font.letterSpacing: -0.15
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled && !root.loading)
                root.clicked();
        }
    }
}
