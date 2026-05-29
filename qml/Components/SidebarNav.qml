import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

Item {
    id: root
    width: parent.width
    height: 56

    property var currentUser: null
    property string currentUserAvatar: ""
    property bool hasUpdateNotification: false
    property int unreadMessageCount: 0

    signal pageRequested(string page)
    signal logoutRequested
    signal checkUpdateClicked
    signal minimizeWindowRequested

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(0, 0, 0, 0.1)
        visible: !userMenu.visible
    }

    Row {
        id: userProfileRow
        visible: !userMenu.visible
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Item {
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Theme.Colors.accent
            }

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "qrc:/icons/icon-user-avatar.svg"
                fillMode: Image.PreserveAspectFit
                visible: root.currentUserAvatar === ""
            }

            Canvas {
                id: sidebarAvatarCanvas
                anchors.fill: parent
                visible: root.currentUserAvatar !== ""
                property string avatarUrl: root.currentUserAvatar
                onAvatarUrlChanged: {
                    if (avatarUrl !== "")
                        loadImage(avatarUrl);
                    requestPaint();
                }
                onImageLoaded: requestPaint()
                Component.onCompleted: {
                    if (avatarUrl !== "")
                        loadImage(avatarUrl);
                }
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (avatarUrl !== "" && isImageLoaded(avatarUrl)) {
                        ctx.save();
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                        ctx.closePath();
                        ctx.clip();
                        ctx.drawImage(avatarUrl, 0, 0, width, height);
                        ctx.restore();
                    }
                }
            }
        }

        Text {
            id: sidebarUserNameText
            width: 111
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.currentUser)
                    return "";
                return root.currentUser.displayName || root.currentUser.userName || "";
            }
            font.pixelSize: Theme.Typography.body
            font.weight: Font.Normal
            color: Theme.Colors.textLabel
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            maximumLineCount: 1
            elide: Text.ElideMiddle
            readonly property bool isOverflow: implicitWidth > width
            property bool showTooltip: userProfileToggleArea.containsMouse && sidebarUserNameText.isOverflow && userProfileToggleArea.mouseX >= (userProfileRow.x + sidebarUserNameText.x) && userProfileToggleArea.mouseX <= (userProfileRow.x + sidebarUserNameText.x + sidebarUserNameText.width)

            Rectangle {
                visible: parent.showTooltip
                width: Math.min(sidebarUserNameTooltipText.implicitWidth + 16, 400)
                height: 28
                color: Theme.Colors.tooltipBackground
                radius: 4
                z: 1000
                y: -height - 8
                x: -8

                Text {
                    id: sidebarUserNameTooltipText
                    anchors.centerIn: parent
                    text: parent.parent.text
                    font.pixelSize: Theme.Typography.caption
                    color: "white"
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                Canvas {
                    width: 10
                    height: 5
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = Theme.Colors.tooltipBackground;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(5, 5);
                        ctx.lineTo(10, 0);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }
        }

        Image {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            source: "qrc:/icons/icon-dropdown-arrow.svg"
            fillMode: Image.PreserveAspectFit
            rotation: userMenu.visible ? 0 : 180

            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    BadgeIndicator {
        visible: !userMenu.visible && count > 0
        x: 161
        anchors.verticalCenter: parent.verticalCenter
        count: root.hasUpdateNotification ? 1 : root.unreadMessageCount
    }

    MouseArea {
        id: userProfileToggleArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        visible: !userMenu.visible
        onClicked: {
            userMenu.visible = true;
        }
    }

    Rectangle {
        id: userMenu
        visible: false
        width: parent.width
        height: userMenuContent.height
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        color: "white"
        border.color: Theme.Colors.borderSeparator
        border.width: 1

        Column {
            id: userMenuContent
            width: parent.width

            Rectangle {
                width: parent.width
                height: 56
                color: userHeaderMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    id: userMenuHeaderRow
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Item {
                        width: 32
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: Theme.Colors.accent
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "qrc:/icons/icon-user-avatar.svg"
                            fillMode: Image.PreserveAspectFit
                            visible: root.currentUserAvatar === ""
                        }

                        Canvas {
                            id: userMenuAvatarCanvas
                            anchors.fill: parent
                            visible: root.currentUserAvatar !== ""
                            property string avatarUrl: root.currentUserAvatar
                            onAvatarUrlChanged: {
                                if (avatarUrl !== "")
                                    loadImage(avatarUrl);
                                requestPaint();
                            }
                            onImageLoaded: requestPaint()
                            Component.onCompleted: {
                                if (avatarUrl !== "")
                                    loadImage(avatarUrl);
                            }
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (avatarUrl !== "" && isImageLoaded(avatarUrl)) {
                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                                    ctx.closePath();
                                    ctx.clip();
                                    ctx.drawImage(avatarUrl, 0, 0, width, height);
                                    ctx.restore();
                                }
                            }
                        }
                    }

                    Text {
                        id: userMenuHeaderUserNameText
                        width: parent.width - 32 - 16 - 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!root.currentUser)
                                return "";
                            return root.currentUser.displayName || root.currentUser.userName || "";
                        }
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        maximumLineCount: 1
                        elide: Text.ElideMiddle
                        readonly property bool isOverflow: implicitWidth > width
                        property bool showTooltip: userHeaderMouseArea.containsMouse && userMenuHeaderUserNameText.isOverflow && userHeaderMouseArea.mouseX >= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x) && userHeaderMouseArea.mouseX <= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x + userMenuHeaderUserNameText.width)

                        Rectangle {
                            visible: parent.showTooltip
                            width: Math.min(userMenuHeaderNameTooltipText.implicitWidth + 16, 400)
                            height: 28
                            color: Theme.Colors.tooltipBackground
                            radius: 4
                            z: 1000
                            y: -height - 8
                            x: -8

                            Text {
                                id: userMenuHeaderNameTooltipText
                                anchors.centerIn: parent
                                text: parent.parent.text
                                font.pixelSize: Theme.Typography.caption
                                color: "white"
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }

                            Canvas {
                                width: 10
                                height: 5
                                anchors.top: parent.bottom
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = Theme.Colors.tooltipBackground;
                                    ctx.beginPath();
                                    ctx.moveTo(0, 0);
                                    ctx.lineTo(5, 5);
                                    ctx.lineTo(10, 0);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }
                    }

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-dropdown-arrow.svg"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                MouseArea {
                    id: userHeaderMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.Colors.borderSeparator
            }

            Rectangle {
                width: parent.width
                height: 40
                color: userInfoMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-user-avatar.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("User Info")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: userInfoMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        Qt.openUrlExternally(AppConfig.userCenterUrl());
                        root.minimizeWindowRequested();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                color: billMenuArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-bill.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("My Bills")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: billMenuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        Qt.openUrlExternally(AppConfig.walletUrl());
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                color: messagesMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-message.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: qsTr("Message")
                            font.pixelSize: Theme.Typography.body
                            color: Theme.Colors.textMenu
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                BadgeIndicator {
                    x: 166
                    anchors.verticalCenter: parent.verticalCenter
                    count: root.unreadMessageCount
                }

                MouseArea {
                    id: messagesMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageRequested("messageCenter")
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                color: settingsMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-settings.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("Settings")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: settingsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        root.pageRequested("settings");
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                color: customerServiceMenuArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-help.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("Help")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: customerServiceMenuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        Qt.openUrlExternally(AppConfig.helpDocsUrl());
                    }
                }
            }

            Rectangle {
                id: updateMenuItem
                width: parent.width
                height: 40
                color: updateMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"
                opacity: 1.0

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-update-refresh.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("Check for Updates")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BadgeIndicator {
                    visible: root.hasUpdateNotification
                    x: 166
                    anchors.verticalCenter: parent.verticalCenter
                    count: 1
                }

                MouseArea {
                    id: updateMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        root.checkUpdateClicked();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.Colors.borderSeparator
            }

            Rectangle {
                width: parent.width
                height: 40
                color: logoutMouseArea.containsMouse ? Theme.Colors.secondary : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-logout.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: qsTr("Logout")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textMenu
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: logoutMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userMenu.visible = false;
                        root.logoutRequested();
                    }
                }
            }
        }
    }
}
