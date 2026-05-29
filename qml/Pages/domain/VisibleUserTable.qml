import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Column {
    id: root

    property var users: []
    property int labelWidth: 110
    property int fieldWidth: 240
    property int fieldSpacing: 40
    property string fontFamily: "Microsoft YaHei"
    property int fontSizeLabel: Theme.Typography.body
    property int fontSizeBody: Theme.Typography.h3

    signal addUserRequested
    signal removeUserRequested(int index)

    width: parent ? parent.width : 400
    height: implicitHeight
    spacing: 8

    Row {
        width: parent.width
        spacing: root.fieldSpacing

        Item {
            width: root.labelWidth
            height: 36

            SelectableText {
                anchors.right: parent.right
                anchors.rightMargin: -4
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Visible Users:")
                font.family: root.fontFamily
                font.pixelSize: root.fontSizeLabel
                color: Theme.Colors.textLabel
            }
        }

        Column {
            width: root.fieldWidth
            spacing: 8

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                radius: 6
                antialiasing: true
                smooth: true
                clip: true
                color: addUserMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                border.color: Theme.Colors.borderField
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-add-user-blue.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    SelectableText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Add Visible User")
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSizeBody
                        font.weight: Font.Medium
                        color: Theme.Colors.textSecondary
                    }
                }

                MouseArea {
                    id: addUserMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addUserRequested()
                }
            }

            Rectangle {
                width: parent.width
                height: root.users.length > 0 ? (40 + root.users.length * 37) : 0
                radius: 6
                antialiasing: true
                smooth: true
                clip: true
                color: Theme.Colors.backgroundWhite
                border.color: Theme.Colors.borderField
                border.width: 1
                visible: root.users.length > 0

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    clip: true

                    Column {
                        anchors.fill: parent

                        UserHeader {
                            width: parent.width
                            fontFamily: root.fontFamily
                            fontSizeBody: root.fontSizeBody
                        }

                        Repeater {
                            model: root.users

                            UserRow {
                                width: parent.width
                                userData: modelData
                                rowIndex: index
                                isLastRow: index >= root.users.length - 1
                                fontFamily: root.fontFamily
                                fontSizeBody: root.fontSizeBody
                                onRemoveRequested: root.removeUserRequested(rowIndex)
                            }
                        }
                    }
                }
            }
        }
    }

    component UserHeader: Rectangle {
        id: header

        property string fontFamily: "Microsoft YaHei"
        property int fontSizeBody: Theme.Typography.h3

        height: 40
        color: Theme.Colors.backgroundWhite
        radius: parent && parent.parent ? Math.max(0, parent.parent.radius - 1) : 5
        antialiasing: true
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(0, 0, 0, 0.1)
        }

        Row {
            anchors.fill: parent

            HeaderCell {
                width: (parent.width - 96) / 2
                text: qsTr("Account")
                leftMargin: 8
                fontFamily: header.fontFamily
                fontSizeBody: header.fontSizeBody
            }

            HeaderCell {
                width: (parent.width - 96) / 2
                text: qsTr("Name")
                leftMargin: 48
                fontFamily: header.fontFamily
                fontSizeBody: header.fontSizeBody
            }

            HeaderCell {
                width: 96
                text: qsTr("Actions")
                alignRight: true
                fontFamily: header.fontFamily
                fontSizeBody: header.fontSizeBody
            }
        }
    }

    component HeaderCell: Item {
        property string text: ""
        property int leftMargin: 8
        property bool alignRight: false
        property string fontFamily: "Microsoft YaHei"
        property int fontSizeBody: Theme.Typography.h3

        height: parent.height

        SelectableText {
            x: parent.alignRight ? 0 : parent.leftMargin
            width: parent.alignRight ? parent.width - 8 : implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: parent.alignRight ? Text.AlignRight : Text.AlignLeft
            text: parent.text
            font.family: parent.fontFamily
            font.pixelSize: parent.fontSizeBody
            font.weight: Font.Medium
            color: Theme.Colors.textLabel
        }
    }

    component UserRow: Rectangle {
        id: row

        property var userData: ({})
        property int rowIndex: -1
        property bool isLastRow: false
        property string fontFamily: "Microsoft YaHei"
        property int fontSizeBody: Theme.Typography.h3

        signal removeRequested

        height: 37
        color: "transparent"

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: row.isLastRow ? 0 : 1
            color: Qt.rgba(0, 0, 0, 0.1)
        }

        Row {
            anchors.fill: parent

            Item {
                width: (parent.width - 96) / 2
                height: parent.height

                CenteredTooltipText {
                    anchors.fill: parent
                    value: row.userData.authUserName || row.userData.user_name || row.userData.account || ""
                    textPixelSize: row.fontSizeBody
                    textColor: Theme.Colors.textLabel
                    leftMargin: 8
                    rightMargin: 28
                }
            }

            Item {
                width: (parent.width - 96) / 2
                height: parent.height

                CenteredTooltipText {
                    anchors.fill: parent
                    value: row.userData.displayName || row.userData.account || ""
                    textPixelSize: row.fontSizeBody
                    textColor: Theme.Colors.textLabel
                    leftMargin: 48
                    rightMargin: 28
                }
            }

            Item {
                width: 96
                height: parent.height

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: removeText.implicitWidth + 8
                    height: removeText.implicitHeight + 4
                    radius: 4
                    color: removeMouseArea.containsMouse ? Qt.rgba(251 / 255, 44 / 255, 54 / 255, 0.1) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }

                    SelectableText {
                        id: removeText
                        anchors.centerIn: parent
                        text: qsTr("Remove")
                        font.family: row.fontFamily
                        font.pixelSize: row.fontSizeBody
                        color: removeMouseArea.containsMouse ? Qt.darker(Theme.Colors.requiredMarker, 1.2) : Theme.Colors.requiredMarker

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                    }

                    MouseArea {
                        id: removeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.removeRequested()
                    }
                }
            }
        }
    }
}
