import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Rectangle {
    id: root

    property var exportRequests: []
    property bool canImportExportFiles: false

    signal exportFileClicked
    signal viewExportClicked(var rowData)

    property int exportRequestCount: exportRequests ? exportRequests.length : 0
    property bool hasExportRequests: exportRequestCount > 0

    height: visible ? (24 + 36 + 16 + (hasExportRequests ? exportTable.height : 24) + 25) : 0
    color: "white"
    border.color: "#e2e8f0"
    border.width: 1
    radius: 14

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 25

        Item {
            id: exportHeader
            width: parent.width
            height: 36

            SelectableText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Export Requests")
                font.pixelSize: 14
                color: "#62748e"
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: exportFileRow.width + 24
                height: 36
                radius: 8
                property bool hovered: false
                color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                visible: root.canImportExportFiles

                Row {
                    id: exportFileRow
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: "qrc:/icons/icon-export-file.svg"
                        width: 16
                        height: 16
                    }

                    Text {
                        text: qsTr("Export File")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onClicked: root.exportFileClicked()
                }
            }
        }

        Item {
            id: exportEmptyState
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: exportHeader.bottom
            anchors.topMargin: 16
            height: 24
            visible: !root.hasExportRequests

            SelectableText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
            }
        }

        Rectangle {
            id: exportTable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: exportHeader.bottom
            anchors.topMargin: 16
            height: root.hasExportRequests ? (40 + root.exportRequestCount * 38) : 0
            border.color: "#1a000000"
            border.width: 1
            radius: 10
            color: "white"
            visible: root.hasExportRequests

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                clip: true

                Item {
                    anchors.fill: parent
                    visible: root.hasExportRequests

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 40
                        property bool hovered: false
                        property real headerCornerRadius: Math.max(0, exportTable.radius - 1)
                        color: hovered ? "#f2f7fd" : "transparent"
                        radius: hovered ? headerCornerRadius : 0

                        HoverHandler {
                            acceptedDevices: PointerDevice.Mouse
                            onHoveredChanged: parent.hovered = hovered
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.headerCornerRadius
                            color: parent.color
                            visible: parent.hovered && parent.headerCornerRadius > 0
                        }

                        Row {
                            anchors.fill: parent

                            Rectangle {
                                width: 160
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Request ID")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }

                            Rectangle {
                                width: 100
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("File Count")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }

                            Rectangle {
                                width: 100
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Total Size")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }

                            Rectangle {
                                width: 100
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Status")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }

                            Rectangle {
                                width: 160
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Request Time")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }

                            Rectangle {
                                width: parent.parent.width - 160 - 100 - 100 - 100 - 160
                                height: parent.height
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#1a000000"
                                }

                                SelectableText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Actions")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "#0f172b"
                                }
                            }
                        }
                    }

                    Repeater {
                        id: exportRequestRepeater
                        model: root.exportRequests || []
                        visible: root.hasExportRequests

                        Item {
                            anchors.top: parent.top
                            anchors.topMargin: 40 + index * 38
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            property bool hovered: false
                            property bool isLastRow: exportRequestRepeater.count > 0 && index === exportRequestRepeater.count - 1
                            property real hoverCornerRadius: Math.max(0, exportTable.radius - 1)
                            property bool showRoundedHover: hovered && isLastRow

                            Rectangle {
                                id: rowHoverBackground
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    bottomMargin: showRoundedHover ? 1 : 0
                                }
                                color: hovered ? "#f2f7fd" : "transparent"
                                radius: showRoundedHover ? hoverCornerRadius : 0
                                antialiasing: showRoundedHover
                            }

                            Rectangle {
                                anchors.left: rowHoverBackground.left
                                anchors.right: rowHoverBackground.right
                                anchors.top: rowHoverBackground.top
                                height: showRoundedHover ? rowHoverBackground.radius : 0
                                color: rowHoverBackground.color
                                visible: showRoundedHover && rowHoverBackground.radius > 0
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: index < exportRequestRepeater.count - 1 ? 1 : 0
                                color: "#1a000000"
                                visible: index < exportRequestRepeater.count - 1
                            }

                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: parent.hovered = hovered
                            }

                            Row {
                                anchors.fill: parent

                                Rectangle {
                                    width: 160
                                    height: parent.height
                                    color: "transparent"

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.id || "-"
                                        font.pixelSize: 14
                                        color: "#0f172b"
                                    }
                                }

                                Rectangle {
                                    width: 100
                                    height: parent.height
                                    color: "transparent"

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.fileCount || "-"
                                        font.pixelSize: 14
                                        color: "#0f172b"
                                    }
                                }

                                Rectangle {
                                    width: 100
                                    height: parent.height
                                    color: "transparent"

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Theme.Utils.formatSize(modelData.fileSize)
                                        font.pixelSize: 14
                                        color: "#0f172b"
                                    }
                                }

                                Rectangle {
                                    width: 100
                                    height: parent.height
                                    color: "transparent"

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 54
                                        height: 22
                                        radius: 8
                                        property var auditStatusStyle: Theme.Colors.getStatusColor(modelData.status || "已授权")
                                        color: auditStatusStyle.bg
                                        border.color: auditStatusStyle.border
                                        border.width: 1

                                        SelectableText {
                                            anchors.centerIn: parent
                                            text: Theme.Colors.translateStatus(modelData.status || "已授权")
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            color: parent.auditStatusStyle.text
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 160
                                    height: parent.height
                                    color: "transparent"

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.applyTime || "-"
                                        font.pixelSize: 14
                                        color: "#0f172b"
                                    }
                                }

                                Rectangle {
                                    width: parent.parent.width - 160 - 100 - 100 - 100 - 160
                                    height: parent.height
                                    color: "transparent"
                                    property bool hovered: false

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("View")
                                        font.pixelSize: 14
                                        color: "#0f4c81"
                                        font.underline: parent.hovered
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: parent.hovered = false
                                        onClicked: root.viewExportClicked(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
