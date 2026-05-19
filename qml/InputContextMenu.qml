import QtQuick 2.15
import QtQuick.Controls 2.15

// Reusable context menu component that can be attached to any text input
// Usage: InputContextMenu { target: yourTextInput }
// Place this component in the same container as your TextInput/TextArea
Item {
    id: root
    
    property var target: null  // The TextInput or TextArea component to attach menu to
    
    // Right-click MouseArea - covers the entire parent area
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: 1  // Above input field but doesn't interfere with text selection
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && root.target) {
                if (root.target.forceActiveFocus) {
                    root.target.forceActiveFocus()
                }
                contextMenu.popup()
            }
        }
    }
    
    // Context menu - same style as SelectableText and login/register pages
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
            text: qsTr("Paste")
            enabled: root.target ? (!root.target.readOnly) : false
            onTriggered: {
                if (root.target && root.target.paste) {
                    root.target.paste()
                }
            }
        }

        MenuItem {
            text: qsTr("Copy")
            enabled: root.target ? (root.target.selectedText ? root.target.selectedText.length > 0 : false) : false
            onTriggered: {
                if (root.target) {
                    root.target.copy()
                }
            }
        }
        
        MenuItem {
            text: qsTr("Select All")
            onTriggered: {
                if (root.target) {
                    root.target.selectAll()
                }
            }
        }
    }
}

