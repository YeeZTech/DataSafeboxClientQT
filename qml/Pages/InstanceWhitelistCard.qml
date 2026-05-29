import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Rectangle {
    id: root

    property var processWhitelist: []

    property int whitelistCount: processWhitelist ? processWhitelist.length : 0
    property bool hasWhitelist: whitelistCount > 0

    height: visible ? (20 + 16 + (hasWhitelist ? whitelistTable.height : 24) + 48) : 0
    color: "white"
    border.color: Theme.Colors.borderSeparator
    border.width: 1
    radius: 14

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 24

        SelectableText {
            id: whitelistTitle
            anchors.left: parent.left
            anchors.top: parent.top
            text: qsTr("App Whitelist")
            font.pixelSize: 14
            color: Theme.Colors.textCaption
        }

        Item {
            id: whitelistEmptyState
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: whitelistTitle.bottom
            anchors.topMargin: 16
            height: 24
            visible: !root.hasWhitelist

            SelectableText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.pixelSize: 16
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }
        }

        Rectangle {
            id: whitelistTable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: whitelistTitle.bottom
            anchors.topMargin: 16
            height: root.hasWhitelist ? (40 + root.whitelistCount * 36) : 0
            radius: 10
            border.color: "#1a000000"
            border.width: 1
            color: "white"
            visible: root.hasWhitelist

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                clip: true

                Item {
                    id: whitelistHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 40
                    visible: root.hasWhitelist

                    Rectangle {
                        anchors.left: parent.left
                        width: 130
                        height: parent.height
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#1a000000"
                        }

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Program Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textHeading
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 130
                        anchors.right: parent.right
                        height: parent.height
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#1a000000"
                        }

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Program Path")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textHeading
                        }
                    }
                }

                Repeater {
                    model: root.processWhitelist || []
                    visible: root.hasWhitelist

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: whitelistHeader.bottom
                        anchors.topMargin: index * 36
                        height: 36
                        color: "white"

                        Rectangle {
                            anchors.left: parent.left
                            width: 130
                            height: parent.height
                            color: "transparent"

                            SelectableText {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name || ""
                                font.pixelSize: 14
                                color: Theme.Colors.textHeading
                                width: parent.width - 16
                                clip: true
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 130
                            anchors.right: parent.right
                            height: parent.height
                            color: "transparent"

                            SelectableText {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.diskPartition || ""
                                font.pixelSize: 14
                                color: Theme.Colors.textHeading
                                width: parent.width - 16
                                clip: true

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor

                                    ToolTip.delay: 500
                                    ToolTip.visible: containsMouse
                                    ToolTip.text: modelData.diskPartition || ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
