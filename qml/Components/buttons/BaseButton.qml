import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: root

    property string buttonStyle: "primary"
    property string text: ""
    property bool enabled: true
    property bool loading: false
    // Visually-disabled state that still detects hover so `disabledTooltipText`
    // can be shown (used for the inactive-security-domain submit buttons; PRD 3.3).
    // NOTE: `enabled` maps to Item.enabled, which disables the whole subtree
    // (including this button's hover/tooltip). So when using `inactive`, keep
    // `enabled` truthy — e.g. `enabled: inactive || <yourCondition>` — otherwise
    // the tooltip cannot appear.
    property bool inactive: false
    property string disabledTooltipText: ""
    property int fontSize: Theme.Typography.body
    property int fontWeight: buttonStyle === "primary" ? Font.Normal : Font.Medium
    property url iconSource: ""
    property int iconSize: 16
    // Secondary buttons only: use the blue "accent" hover/pressed variant
    property bool accent: false
    // Secondary buttons only: blue (primary-colored) outline + text at rest, with the
    // accent hover/pressed fills (e.g. the "How to Instantiate Security Domain?" header button)
    property bool primaryOutline: false

    signal clicked

    width: implicitWidth
    height: 36
    implicitWidth: Math.max(88, contentRow.implicitWidth + 32)
    radius: 8
    opacity: _active ? 1.0 : 0.5

    readonly property bool _isSecondary: buttonStyle === "secondary"
    readonly property bool _isDanger: buttonStyle === "danger"
    readonly property bool _useAccent: accent || primaryOutline
    // Interactive (clickable, normally styled) when enabled and not inactive.
    readonly property bool _active: enabled && !inactive

    color: {
        if (!_active) {
            if (_isSecondary)
                return Theme.Colors.buttonSecondaryDefault;
            if (_isDanger)
                return Theme.Colors.buttonDisabled;
            return Theme.Colors.primary;
        }
        if (mouseArea.pressed) {
            if (_isSecondary)
                return _useAccent ? Theme.Colors.buttonSecondaryAccentPressed : Theme.Colors.buttonSecondaryPressed;
            if (_isDanger)
                return Theme.Colors.buttonDangerPressed;
            return Theme.Colors.buttonPrimaryPressed;
        }
        if (mouseArea.containsMouse) {
            if (_isSecondary)
                return _useAccent ? Theme.Colors.buttonSecondaryAccentHover : Theme.Colors.buttonSecondaryHover;
            if (_isDanger)
                return Theme.Colors.buttonDangerHover;
            return Theme.Colors.buttonPrimaryHover;
        }
        if (_isSecondary)
            return Theme.Colors.buttonSecondaryDefault;
        if (_isDanger)
            return Theme.Colors.buttonDanger;
        return Theme.Colors.primary;
    }

    border.color: {
        if (!_isSecondary)
            return "transparent";
        if (_useAccent && _active) {
            if (mouseArea.pressed)
                return Theme.Colors.buttonSecondaryAccentBorderPressed;
            if (mouseArea.containsMouse)
                return Theme.Colors.buttonSecondaryAccentBorderHover;
        }
        return primaryOutline ? Theme.Colors.primary : Theme.Colors.borderField;
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
                if (!root._active) {
                    // Disabled primary keeps white text on its faded-blue fill; gray bg buttons use muted text
                    if (!root._isSecondary && !root._isDanger)
                        return Theme.Colors.primaryText;
                    return Theme.Colors.buttonTextDisabled;
                }
                if (root._isSecondary)
                    return root.primaryOutline ? Theme.Colors.primary : Theme.Colors.textLabel;
                return Theme.Colors.primaryText;
            }
            font.letterSpacing: -0.15
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        // Keep hover tracking alive while inactive so the disabled tooltip can show.
        hoverEnabled: root.enabled || root.inactive
        cursorShape: root._active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root._active && !root.loading)
                root.clicked();
        }
    }

    // Hover hint shown when the button is intentionally inactive (e.g. the security
    // domain is deactivated). No-op when disabledTooltipText is empty.
    HintTooltip {
        parent: root
        text: root.disabledTooltipText
        visible: root.inactive && root.disabledTooltipText !== "" && mouseArea.containsMouse
    }
}
