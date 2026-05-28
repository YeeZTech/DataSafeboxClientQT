import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Item {
    id: root
    width: parent.width
    height: 32

    property string domainName: ""
    property bool isDomainReadOnly: false
    property bool encryptButtonBusy: false
    property string domainPubKey: ""

    property alias encryptFileButton: encryptFileButton
    property alias createInstanceButton: createInstanceButton

    signal instantiateRequested
    signal encryptRequested
    signal guideRequested
    signal errorOccurred(string message, string title)

    Text {
        id: headerTitleText
        anchors.left: parent.left
        anchors.right: headerButtonRow.left
        anchors.rightMargin: 48
        anchors.verticalCenter: parent.verticalCenter
        text: root.domainName
        font.pixelSize: 24
        font.weight: Font.Medium
        color: "#0f172b"
        elide: Text.ElideRight

        ToolTip.visible: truncated && headerTitleHover.containsMouse
        ToolTip.text: root.domainName
        ToolTip.delay: 500

        HoverHandler {
            id: headerTitleHover
            enabled: headerTitleText.truncated
        }
    }

    Row {
        id: headerButtonRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: guideLinkText.implicitWidth + 12
            height: 36
            radius: 5
            color: Qt.rgba(238 / 255, 244 / 255, 251 / 255, 0)

            Text {
                id: guideLinkText
                anchors.centerIn: parent
                text: qsTr("View Feature Guide")
                font.pixelSize: 14
                font.underline: true
                color: guideArea.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : guideArea.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            MouseArea {
                id: guideArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.guideRequested()
            }
        }

        Rectangle {
            id: createInstanceButton
            visible: true
            width: instantiateRow.width + 24
            height: 36
            radius: 8
            color: {
                if (instantiateMouseArea.pressed)
                    return "#dce8f5";
                if (instantiateMouseArea.containsMouse)
                    return "#eef4fb";
                return "#ffffff";
            }
            border.color: instantiateMouseArea.containsMouse ? Theme.Colors.primary : Qt.lighter(Theme.Colors.primary, 1.4)
            border.width: 1
            opacity: !root.isDomainReadOnly ? 1.0 : 0.5
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
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Row {
                id: instantiateRow
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("How to Instantiate Security Domain?")
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: instantiateMouseArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.3) : Theme.Colors.primary
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }

            MouseArea {
                id: instantiateMouseArea
                anchors.fill: parent
                enabled: !root.isDomainReadOnly
                hoverEnabled: true
                cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: {
                    if (root.isDomainReadOnly)
                        return;
                    root.instantiateRequested();
                }
            }
        }

        Rectangle {
            id: encryptFileButton
            readonly property bool disabled: root.isDomainReadOnly || root.encryptButtonBusy
            width: encryptRow.width + 24
            height: 36
            radius: 8
            color: {
                if (encryptFileButton.disabled)
                    return "#9fb0c3";
                if (encryptMouseArea.pressed)
                    return Qt.darker("#0f4c81", 1.2);
                if (encryptMouseArea.containsMouse)
                    return Qt.lighter("#0f4c81", 1.15);
                return "#0f4c81";
            }
            visible: true
            opacity: encryptFileButton.disabled ? 0.55 : 1.0
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Row {
                id: encryptRow
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Image {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/icons/icon-encrypt-to-domain.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Encrypt Files to This Security Domain")
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: "white"
                }
            }

            MouseArea {
                id: encryptMouseArea
                anchors.fill: parent
                enabled: !encryptFileButton.disabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: {
                    if (encryptFileButton.disabled)
                        return;
                    if (!root.domainPubKey) {
                        root.errorOccurred(qsTr("Security domain public key not found"), qsTr("Encrypt File"));
                        return;
                    }
                    root.encryptRequested();
                }
            }
        }
    }
}
