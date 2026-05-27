import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

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
                        source: Qt.resolvedUrl("icons/icon-warning.svg")
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
                Rectangle {
                    width: 60
                    height: 36  // 与确认按钮统一高度
                    radius: 8
                    color: {
                        if (cancelArea.pressed)
                            return "#bedbff";
                        if (cancelArea.containsMouse)
                            return "#e8f8ff";
                        return "white";  // 默认状态
                    }
                    border.width: 1
                    border.color: {
                        if (cancelArea.pressed)
                            return "#add3e6";
                        if (cancelArea.containsMouse)
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

                    SelectableText {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#314158"
                        font.letterSpacing: -0.15
                    }

                    MouseArea {
                        id: cancelArea
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
                    width: 88
                    height: 36
                    radius: 8
                    color: {
                        // 默认: #fd7977, 悬停: 稍浅, 点击: #fb2c36
                        if (confirmArea.pressed)
                            return "#fb2c36";  // 点击状态
                        if (confirmArea.containsMouse)
                            return "#fe9a98";  // 悬停状态（稍浅）
                        return "#fd7977";  // 默认状态
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    SelectableText {
                        anchors.centerIn: parent
                        text: root.confirmButtonText
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                        font.letterSpacing: -0.15
                    }

                    MouseArea {
                        id: confirmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.confirmClicked();
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
