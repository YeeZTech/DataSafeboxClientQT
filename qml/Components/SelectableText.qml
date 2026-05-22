import QtQuick 2.15
import QtQuick.Controls 2.15

// A selectable and copyable text component
// Usage: SelectableText { text: "some text"; font.pixelSize: 14; color: "#0f172b" }
TextEdit {
    id: root
    
    readOnly: true
    selectByMouse: true
    selectionColor: "#d4e4f1"
    selectedTextColor: "#0f172b"
    
    // Disable editing features
    activeFocusOnPress: true
    
    // Allow text wrapping by default (can be overridden)
    wrapMode: TextEdit.NoWrap
    
    // Right-click context menu for copy
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.RightButton
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
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
            color: "#f1f5f9"
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
                font.pixelSize: 14
                color: menuItem.enabled ? "#334155" : "#94a3b8"
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: 8
            }
            
            background: Rectangle {
                implicitWidth: 92
                implicitHeight: 32
                color: menuItem.highlighted ? "#e2e8f0" : "transparent"
                radius: 6
            }
        }
        
        MenuItem {
            text: qsTr("Copy")
            enabled: root.selectedText.length > 0
            onTriggered: {
                root.copy()
            }
        }
        
        MenuItem {
            text: qsTr("Select All")
            onTriggered: {
                root.selectAll()
            }
        }
    }
    
    // Keyboard shortcut for copy (Ctrl+C)
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            root.copy()
            event.accepted = true
        }
        if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            root.selectAll()
            event.accepted = true
        }
    }
}

