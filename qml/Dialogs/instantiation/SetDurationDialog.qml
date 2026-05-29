import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    height: 281
    title: qsTr("Duration Settings")
    onCloseRequested: cancelClicked()

    property string durationText: ""
    readonly property bool canConfirm: durationInput && durationInput.text && durationInput.text.trim().length > 0

    signal confirmClicked(string durationText)
    signal cancelClicked

    onOpened: {
        durationText = "";
        if (durationInput)
            durationInput.text = "";
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
                    color: Theme.Colors.textLabel
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    anchors.verticalCenter: parent.verticalCenter
                    text: "*"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: Theme.Colors.requiredMarker
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
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textCaption
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
                    border.color: Theme.Colors.borderField

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
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textHeading
                        selectByMouse: true
                        selectionColor: Theme.Colors.accent
                        selectedTextColor: Theme.Colors.textHeading
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: root.durationText
                        placeholderText: qsTr("Enter instance run duration")
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
            font.pixelSize: Theme.Typography.body
            color: Theme.Colors.textCaption
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            SecondaryButton {
                text: qsTr("Cancel")
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }

            PrimaryButton {
                text: qsTr("Confirm")
                enabled: root.canConfirm
                onClicked: {
                    root.confirmClicked(durationInput.text.trim());
                    root.close();
                }
            }
        }
    }
}
