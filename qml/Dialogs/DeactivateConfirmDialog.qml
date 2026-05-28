import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Popup {
    id: root
    width: 446
    implicitHeight: contentColumn.implicitHeight + 48
    height: implicitHeight
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    property string domainName: ""
    property string titleText: qsTr("Confirm Deactivate Security Domain")
    property string questionPrefix: qsTr("Are you sure you want to deactivate security domain")
    property string questionSuffix: qsTr("?")
    property string descriptionText: qsTr("After deactivation this domain becomes read-only. Existing instances are not affected.")
    property bool showDescription: true
    property string confirmButtonText: qsTr("Confirm Deactivate")
    signal confirmClicked
    signal cancelClicked

    // Remove default Popup background and border
    background: null
    padding: 0

    // Main dialog container
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 0

            // Header with title and close button
            Item {
                width: parent.width
                height: 24

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.titleText
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0f172b"
                }

                // Close button - top right
                Rectangle {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 12
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

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 18
                        color: closeArea.containsMouse ? "#0f4c81" : "#314158"
                    }
                }
            }
            Item {
                width: parent.width
                height: 32
            }

            // Warning message area
            Rectangle {
                width: parent.width
                radius: 10
                color: "#fefce8"
                border.color: "#f59e0b"  // amber-500 for better visibility
                border.width: 1.5
                implicitHeight: warningContent.implicitHeight + warningContent.anchors.topMargin + warningContent.anchors.bottomMargin
                height: implicitHeight

                Row {
                    id: warningContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 18
                    anchors.bottomMargin: 18
                    spacing: 12  // Space between icon and text
                    Image {
                        id: warningIcon
                        width: 20
                        height: 20
                        source: "qrc:/icons/icon-warning.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    // Warning text content
                    Column {
                        id: warningTexts
                        width: warningContent.width - warningIcon.width - warningContent.spacing
                        spacing: 8

                        // Main question text
                        SelectableText {
                            width: parent.width
                            wrapMode: TextEdit.Wrap
                            text: root.questionPrefix + " \"" + root.domainName + "\" " + root.questionSuffix
                            font.pixelSize: 16
                            color: "#314158"
                        }

                        // Description text
                        SelectableText {
                            width: parent.width
                            wrapMode: TextEdit.Wrap
                            text: root.descriptionText
                            font.pixelSize: 14
                            color: "#45556c"
                            visible: root.showDescription && root.descriptionText && root.descriptionText.length > 0
                            height: visible ? implicitHeight : 0
                        }
                    }
                }
            }

            // Spacing between warning box and buttons
            Item {
                width: parent.width
                height: 28
            }

            // Footer buttons
            Row {
                anchors.right: parent.right
                spacing: 16
                height: 36
                SecondaryButton {
                    text: qsTr("Cancel")
                    onClicked: {
                        root.close();
                        root.cancelClicked();
                    }
                }
                DangerButton {
                    text: root.confirmButtonText
                    onClicked: {
                        root.confirmClicked();
                        root.close();
                    }
                }
            }
        }
    }
}
