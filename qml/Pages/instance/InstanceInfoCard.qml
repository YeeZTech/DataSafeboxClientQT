import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Card {
    id: root

    height: 314
    contentMargins: 0
    contentSpacing: 0
    borderColor: Theme.Colors.borderSeparator
    borderWidth: 1

    property var instanceData: ({})
    property string expiryText: "-"

    Item {
        x: 25
        y: 25
        width: Math.max(0, parent.width - 26)
        height: 264

        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Instance ID")
                color: Theme.Colors.textCaption
            }

            SelectableText {
                text: root.instanceData.id || "-"
                font.pixelSize: Theme.Typography.h3
                color: Theme.Colors.textHeading
            }
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 451
            anchors.top: parent.top
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Status")
                color: Theme.Colors.textCaption
            }

            Rectangle {
                width: 54
                height: 22
                radius: 8
                property var statusBadgeStyle: Theme.Colors.getStatusColor(root.instanceData.status || "运行中")
                color: statusBadgeStyle.bg
                border.color: statusBadgeStyle.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: Theme.Colors.translateStatus(root.instanceData.status || "运行中")
                    font.pixelSize: Theme.Typography.small
                    font.weight: Font.Medium
                    color: parent.statusBadgeStyle.text
                }
            }
        }
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 72
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Name")
                color: Theme.Colors.textCaption
            }

            SelectableText {
                text: root.instanceData.name || "-"
                font.pixelSize: Theme.Typography.h3
                color: Theme.Colors.textHeading
            }
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 451
            anchors.top: parent.top
            anchors.topMargin: 72
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Belongs To Security Domain")
                color: Theme.Colors.textCaption
            }

            SelectableText {
                text: "-"
                font.pixelSize: Theme.Typography.h3
                color: Theme.Colors.textHeading
            }
        }
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 144
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Path")
                color: Theme.Colors.textCaption
            }

            Row {
                spacing: 4

                SelectableText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.instanceData.diskPartition || "-"
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.primary
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/icons/icon-directory.svg"
                    width: 12
                    height: 12
                }
            }
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 451
            anchors.top: parent.top
            anchors.topMargin: 144
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Created At")
                color: Theme.Colors.textCaption
            }

            SelectableText {
                text: root.instanceData.createdAt || "-"
                font.pixelSize: Theme.Typography.h3
                color: Theme.Colors.textHeading
            }
        }
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 216
            width: 427
            spacing: 4

            SelectableText {
                text: qsTr("Expires At")
                color: Theme.Colors.textCaption
            }

            SelectableText {
                text: root.expiryText
                font.pixelSize: Theme.Typography.h3
                color: Theme.Colors.textHeading
            }
        }
    }
}
