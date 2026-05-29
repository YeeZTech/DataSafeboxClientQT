import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

// A selectable and copyable text component
// Usage: SelectableText { text: "some text"; font.pixelSize: Theme.Typography.body; color: Theme.Colors.textHeading }
TextEdit {
    id: root

    readOnly: true
    selectByMouse: true
    selectionColor: Theme.Colors.accent
    selectedTextColor: Theme.Colors.textHeading

    // Disable editing features
    activeFocusOnPress: true

    // Allow text wrapping by default (can be overridden)
    wrapMode: TextEdit.NoWrap

    // Right-click context menu for copy
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.RightButton

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup();
            }
        }
    }

    // Context menu
    Menu {
        id: contextMenu
        padding: 4

        background: Rectangle {
            implicitWidth: 100
            implicitHeight: 40
            color: Theme.Colors.buttonSecondaryBg
            radius: 8
            border.color: "#cbd5e1"
            border.width: 1
        }

        delegate: MenuItem {
            id: menuItem
            implicitWidth: 92
            implicitHeight: 32

            contentItem: Text {
                text: menuItem.text
                font.pixelSize: Theme.Typography.body
                color: menuItem.enabled ? Theme.Colors.textMenu : "#94a3b8"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: 8
            }

            background: Rectangle {
                implicitWidth: 92
                implicitHeight: 32
                color: menuItem.highlighted ? Theme.Colors.borderSeparator : "transparent"
                radius: 6
            }
        }

        MenuItem {
            text: qsTr("Copy")
            enabled: root.selectedText.length > 0
            onTriggered: {
                root.copy();
            }
        }

        MenuItem {
            text: qsTr("Select All")
            onTriggered: {
                root.selectAll();
            }
        }
    }

    // Keyboard shortcut for copy (Ctrl+C)
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            root.copy();
            event.accepted = true;
        }
        if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            root.selectAll();
            event.accepted = true;
        }
    }
}
