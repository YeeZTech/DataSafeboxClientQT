import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string buttonStyle: "primary"
    property string text: ""
    property bool enabled: true
    property bool loading: false
    property int fontSize: Theme.Typography.body
    property int fontWeight: buttonStyle === "primary" ? Font.Normal : Font.Medium
    property url iconSource: ""
    property int iconSize: 16

    signal clicked

    width: implicitWidth
    height: 36
    implicitWidth: Math.max(88, contentRow.implicitWidth + 32)
    radius: 8
    opacity: enabled ? 1.0 : 0.6

    readonly property bool _isSecondary: buttonStyle === "secondary"
    readonly property bool _isDanger: buttonStyle === "danger"

    color: {
        if (!enabled)
            return _isSecondary ? Theme.Colors.buttonSecondaryBg : Theme.Colors.buttonDisabled;
        if (mouseArea.pressed) {
            if (_isSecondary)
                return Qt.darker(Theme.Colors.buttonSecondaryBg, 1.05);
            if (_isDanger)
                return Theme.Colors.buttonDangerPressed;
            return Qt.darker(Theme.Colors.primary, 1.2);
        }
        if (mouseArea.containsMouse) {
            if (_isSecondary)
                return Qt.lighter(Theme.Colors.buttonSecondaryBg, 1.02);
            if (_isDanger)
                return Theme.Colors.buttonDangerHover;
            return Qt.lighter(Theme.Colors.primary, 1.2);
        }
        if (_isSecondary)
            return Theme.Colors.buttonSecondaryBg;
        if (_isDanger)
            return Theme.Colors.buttonDanger;
        return Theme.Colors.primary;
    }

    border.color: {
        if (!_isSecondary)
            return "transparent";
        if (mouseArea.containsMouse || mouseArea.pressed)
            return Theme.Colors.buttonSecondaryBorderHover;
        return Theme.Colors.borderField;
    }
    border.width: _isSecondary ? 1 : 0

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        Image {
            id: buttonIcon
            visible: root.iconSource.toString() !== "" && !root.loading
            anchors.verticalCenter: parent.verticalCenter
            source: root.iconSource
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
        }

        Text {
            id: buttonText
            anchors.verticalCenter: parent.verticalCenter
            text: root.loading ? qsTr("Loading...") : root.text
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            color: {
                if (!root.enabled)
                    return Theme.Colors.buttonTextDisabled;
                if (root._isSecondary)
                    return Theme.Colors.textLabel;
                return Theme.Colors.primaryText;
            }
            font.letterSpacing: -0.15
        }
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
