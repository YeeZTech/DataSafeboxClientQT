import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Column {
    id: root

    property string label: ""
    property bool required: false
    property string displayText: ""
    property string placeholder: ""
    property bool hasValue: displayText !== ""
    property bool selectorEnabled: true
    property bool showClearButton: false

    signal selectClicked
    signal clearClicked

    width: parent ? parent.width : 400
    spacing: 8

    Row {
        spacing: 4

        SelectableText {
            text: root.label
            font.pixelSize: Theme.Typography.body
            font.weight: Font.Medium
            color: Theme.Colors.textLabel
        }

        SelectableText {
            visible: root.required
            text: "*"
            font.pixelSize: Theme.Typography.body
            font.weight: Font.Medium
            color: Theme.Colors.requiredMarker
        }
    }

    Rectangle {
        width: parent.width
        height: 36
        radius: 8
        color: selectorArea.containsMouse ? "#e8f8ff" : Theme.Colors.backgroundWhite
        border.color: selectorArea.containsMouse ? "#79aecd" : "#94a3b8"
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

        Row {
            anchors.left: parent.left
            anchors.right: clearButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Image {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/icons/icon-directory.svg"
                fillMode: Image.PreserveAspectFit
            }

            Item {
                width: parent.width - 16 - 12
                height: parent.height
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hasValue ? root.displayText : root.placeholder
                    font.pixelSize: Theme.Typography.body
                    font.weight: Font.Medium
                    color: root.hasValue ? Theme.Colors.textHeading : "#94a3b8"
                    elide: Text.ElideMiddle
                }
            }
        }

        Rectangle {
            id: clearButton
            width: root.showClearButton ? 20 : 0
            height: 20
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            radius: 10
            visible: root.showClearButton
            color: clearArea.containsMouse ? "#fee2e2" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: Theme.Typography.small
                color: clearArea.containsMouse ? "#ef4444" : "#94a3b8"
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                enabled: root.selectorEnabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: root.clearClicked()
            }
        }

        MouseArea {
            id: selectorArea
            anchors.left: parent.left
            anchors.right: clearButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            enabled: root.selectorEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: root.selectClicked()
        }
    }
}
