import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root
    width: 446
    height: hasError ? 278 : 254
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    property string account: ""
    property bool hasError: false
    property string errorMessage: qsTr("User not found")
    property bool isVerifying: false
    property string pendingAccount: ""
    property var currentUserInfo: null  // 存储当前验证通过的用户信息
    property string domainCreator: ""  // 安全域创建者，用于拦截重复添加
    signal addClicked(string account)
    signal cancelClicked

    function normalizeUserSearchError(message) {
        var text = message ? message.toString().trim() : "";
        if (!text) {
            return qsTr("User not found");
        }

        // Defensive fallback for mojibake/garbled backend text.
        if (/[�]/.test(text) || /(钐登|鑠查谢|璧绺|缺少|字段|失败|状态|异常|字碱皮|琀|潏)/.test(text)) {
            return qsTr("User not found");
        }
        return text;
    }

    onClosed: {
        verifyTimeoutTimer.stop();
        accountInput.text = "";
        root.hasError = false;
        root.isVerifying = false;
        root.pendingAccount = "";
        root.currentUserInfo = null;
    }

    // 网络超时保护：避免 Casdoor 接口长时间无响应导致界面卡死
    Timer {
        id: verifyTimeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.isVerifying)
                return;
            root.isVerifying = false;
            root.pendingAccount = "";
            root.hasError = true;
            root.errorMessage = qsTr("Network request timed out, please check your connection and retry");
        }
    }

    // Remove default Popup background and border
    background: null
    padding: 0

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    Rectangle {
        id: bgRect
        width: root.width
        height: root.height
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1

        SelectableText {
            x: 24
            y: 24
            text: qsTr("Add Visible User")
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: "#0f172b"
        }

        Rectangle {
            width: 24
            height: 24
            x: parent.width - 44
            y: 21
            radius: 12
            color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: 18
                color: closeArea.containsMouse ? "#0f4c81" : "#314158"
            }

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
        }

        Column {
            x: 24
            y: 58
            width: 398
            spacing: 8

            SelectableText {
                text: qsTr("Dianshu ID:")
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#314158"
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: accountInput.activeFocus ? "white" : (inputHoverArea.containsMouse ? "#e9eef6" : "white")
                border.color: root.hasError ? "#c10007" : "#cad5e2"
                border.width: 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: 180
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MouseArea {
                    id: inputHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                TextInput {
                    id: accountInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 14
                    color: Theme.Colors.textPrimary
                    selectByMouse: true
                    selectionColor: "#d4e4f1"
                    selectedTextColor: "#0f172b"

                    onTextChanged: {
                        root.account = text;
                        root.hasError = false;
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("Please enter the other party's Dianshu ID to add as visible user")
                        font.pixelSize: 14
                        color: "#5a7c9b"
                        visible: !accountInput.text && !accountInput.activeFocus
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                            accountInput.copy();
                            event.accepted = true;
                        }
                        if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                            accountInput.selectAll();
                            event.accepted = true;
                        }
                    }
                }

                InputContextMenu {
                    anchors.fill: parent
                    target: accountInput
                }
            }

            Row {
                width: parent.width
                spacing: 4
                height: 20
                visible: root.hasError

                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: "icons/icon-error.svg"
                        sourceSize: Qt.size(16, 16)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                    }
                }

                Text {
                    text: root.errorMessage
                    font.pixelSize: 14
                    color: "#e7000b"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: 4
                height: 20

                Image {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/icons/icon-info-dark.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("What is Dianshu ID?")
                    font.pixelSize: 13
                    font.underline: true
                    color: linkHover.containsMouse ? "#0f4c81" : "#1566c0"

                    MouseArea {
                        id: linkHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var url = "";
                            if (url)
                                Qt.openUrlExternally(url);
                        }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 8

            Rectangle {
                width: 62
                height: 36
                radius: 8
                color: {
                    if (cancelArea.pressed)
                        return "#bedbff";
                    if (cancelArea.containsMouse)
                        return "#e8f8ff";
                    return "white";
                }
                border.color: {
                    if (cancelArea.pressed)
                        return "#add3e6";
                    if (cancelArea.containsMouse)
                        return "#79aecd";
                    return "#cad5e2";
                }
                border.width: 1
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
                width: 60
                height: 36
                radius: 8
                color: {
                    if (!addArea.enabled)
                        return "#0f4c81";
                    if (addArea.pressed)
                        return Qt.darker("#0f4c81", 1.2);
                    if (addArea.containsMouse)
                        return Qt.lighter("#0f4c81", 1.15);
                    return "#0f4c81";
                }
                opacity: addArea.enabled ? 1.0 : 0.5
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                SelectableText {
                    anchors.centerIn: parent
                    text: qsTr("Add")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "white"
                }

                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: accountInput.text.trim() !== "" && !root.isVerifying
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        var trimmedAccount = accountInput.text ? accountInput.text.trim() : "";
                        if (!trimmedAccount || root.isVerifying) {
                            return;
                        }
                        root.hasError = false;
                        root.pendingAccount = trimmedAccount;
                        root.isVerifying = true;
                        verifyTimeoutTimer.restart();
                        CasdoorHelper.searchUser(trimmedAccount);
                    }
                }
            }
        }
    }

    // ── Casdoor user search result handlers ─────────────────────────────
    Connections {
        target: CasdoorHelper

        function onUserSearchCompleted(user) {
            if (!root.isVerifying)
                return;
            verifyTimeoutTimer.stop();
            root.isVerifying = false;
            var userId = (user.user_id || user.authUserId || "").trim();
            var userName = (user.user_name || user.authUserName || "").trim();
            var account = (user.account || "").trim();
            var displayName = (user.displayName || account).trim();
            if (!userId || !userName || !account) {
                root.hasError = true;
                root.errorMessage = qsTr("Query result is missing required fields, please contact administrator");
                return;
            }
            root.currentUserInfo = {
                user_id: userId,
                user_name: userName,
                account: account,
                authUserId: userId,
                displayName: displayName,
                authUserName: userName
            };
            root.addClicked(root.pendingAccount);
            root.pendingAccount = "";
            root.close();
        }

        function onUserSearchFailed(errorMessage) {
            if (!root.isVerifying)
                return;
            verifyTimeoutTimer.stop();
            root.isVerifying = false;
            root.hasError = true;
            root.errorMessage = root.normalizeUserSearchError(errorMessage);
        }
    }

    Popup {
        id: userNotFoundDialog
        width: 340
        height: 160
        modal: true
        parent: root.parent ? root.parent : root
        closePolicy: Popup.NoAutoClose
        x: (parent ? (parent.width - width) / 2 : 0)
        y: (parent ? (parent.height - height) / 2 : 0)

        property string message: ""

        background: Rectangle {
            radius: 10
            color: Theme.Colors.backgroundWhite
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            SelectableText {
                width: parent.width
                text: qsTr("Prompt")
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
            }

            SelectableText {
                width: parent.width
                text: userNotFoundDialog.message
                font.pixelSize: 14
                color: "#314158"
                wrapMode: TextEdit.Wrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 60
                    height: 36
                    radius: 8
                    property bool hovered: false
                    color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("OK")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: userNotFoundDialog.close()
                    }
                }
            }
        }
    }
}
