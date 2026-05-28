import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Popup {
    id: root
    width: 448
    height: 281
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    property string durationText: ""
    readonly property bool canConfirm: durationInput && durationInput.text && durationInput.text.trim().length > 0

    signal confirmClicked(string durationText)
    signal cancelClicked

    background: null
    padding: 0

    onOpened: {
        durationText = "";
        if (durationInput) {
            durationInput.text = "";
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 10
            color: Theme.Colors.backgroundWhite
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 0.65

            Column {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 24
                anchors.bottomMargin: 20
                spacing: 0

                Item {
                    width: parent.width
                    height: 28

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Duration Settings")
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: "#0f172b"
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                root.cancelClicked();
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 1.5
                            rotation: 45
                            color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 1.5
                            rotation: -45
                            color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 24
                }

                Column {
                    width: parent.width
                    spacing: 20

                    Column {
                        width: parent.width
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 18

                            SelectableText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Duration")
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: "#314158"
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 64
                                anchors.verticalCenter: parent.verticalCenter
                                text: "*"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: "#fb2c36"
                            }
                        }

                        Item {
                            width: parent.width
                            height: 40

                            Text {
                                id: unitLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr(" months")
                                font.pixelSize: 16
                                color: "#45556c"
                            }

                            Rectangle {
                                id: inputBox
                                anchors.left: parent.left
                                anchors.right: unitLabel.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                height: 40
                                radius: 8
                                color: durationInput.activeFocus ? Theme.Colors.backgroundWhite : (durationInputHover.containsMouse ? "#e9eef6" : Theme.Colors.inputBackground)
                                border.width: 1
                                border.color: "#cad5e2"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                MouseArea {
                                    id: durationInputHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }

                                TextField {
                                    id: durationInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                    color: "#0f172b"
                                    selectByMouse: true
                                    selectionColor: "#d4e4f1"
                                    selectedTextColor: "#0f172b"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    text: root.durationText
                                    placeholderText: qsTr("Enter instance run duration")

                                    // background customization removed to avoid native style warnings

                                    onTextChanged: root.durationText = text
                                }

                                InputContextMenu {
                                    anchors.fill: parent
                                    target: durationInput
                                }
                            }
                        }
                    }

                    SelectableText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: qsTr("Duration cannot be modified. The instance will be deleted upon expiration (original files unaffected).")
                        font.pixelSize: 14
                        color: "#62748e"
                    }
                }

                Item {
                    width: parent.width
                    height: 24
                }

                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 60
                            height: 36
                            radius: 8
                            color: {
                                if (cancelMouseArea.pressed)
                                    return "#bedbff";
                                if (cancelMouseArea.containsMouse)
                                    return "#e8f8ff";
                                return "white";
                            }
                            border.width: 1
                            border.color: {
                                if (cancelMouseArea.pressed)
                                    return "#add3e6";
                                if (cancelMouseArea.containsMouse)
                                    return "#79aecd";
                                return "#cad5e2";
                            }
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
                                anchors.centerIn: parent
                                text: qsTr("Cancel")
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "#314158"
                            }

                            MouseArea {
                                id: cancelMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.close();
                                    root.cancelClicked();
                                }
                            }
                        }

                        Rectangle {
                            width: 60
                            height: 36
                            radius: 8
                            property bool hovered: false
                            color: hovered && root.canConfirm ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                            opacity: root.canConfirm ? 1.0 : 0.5
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Confirm")
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: Theme.Colors.primaryText
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.canConfirm
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: if (enabled)
                                    parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    root.confirmClicked(durationInput.text.trim());
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
