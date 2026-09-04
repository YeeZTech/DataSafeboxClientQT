import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 500
    title: qsTr("Add Visible User")
    onCloseRequested: cancelClicked()

    property string account: ""
    property bool hasError: false
    property string errorMessage: qsTr("User not found")
    property bool isVerifying: false
    property string pendingAccount: ""
    property var currentUserInfo: null  // 存储当前验证通过的用户信息
    property string domainCreator: ""  // 安全域创建者，用于拦截重复添加
    // 当前登录用户，用于拦截"将自己添加为可见用户"
    property string currentUserName: ""
    property string currentUserId: ""
    // 安全域已停用（已关闭/创建失败）：弹窗正常打开，但"添加"按钮置灰并提示 (PRD 3.3)
    property bool domainInactive: false
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

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    Column {
        width: parent.width
        spacing: 8

        SelectableText {
            text: qsTr("Dianshu ID:")
            font.pixelSize: Theme.Typography.body
            font.weight: Font.Medium
            color: Theme.Colors.textLabel
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: accountInput.activeFocus ? "white" : (inputHoverArea.containsMouse ? "#e9eef6" : "white")
            border.color: root.hasError ? "#c10007" : Theme.Colors.borderField
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
                // 长文本必须裁掉，否则会画到输入框外面（占位提示同理，它是本 TextInput 的子项）
                clip: true
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textPrimary
                selectByMouse: true
                selectionColor: Theme.Colors.accent
                selectedTextColor: Theme.Colors.textHeading

                onTextChanged: {
                    root.account = text;
                    root.hasError = false;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Please enter the other party's Dianshu ID to add as visible user")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textSecondary
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
                    source: "qrc:/icons/icon-error.svg"
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    antialiasing: true
                }
            }

            Text {
                text: root.errorMessage
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textError
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

            LinkText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("What is Dianshu ID?")
                fontSize: Theme.Typography.caption
                onClicked: {
                    var url = "https://help.yeez.tech/docs/dian-shu-hao";
                    if (url)
                        Qt.openUrlExternally(url);
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            SecondaryButton {
                text: qsTr("Cancel")
                accent: true
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }

            PrimaryButton {
                text: qsTr("Add")
                inactive: root.domainInactive
                disabledTooltipText: qsTr("Security domain is deactivated, this operation is not supported")
                // Stay enabled (Item-level) while inactive so the hover tooltip works; `inactive` handles the grayed look.
                enabled: root.domainInactive || (accountInput.text.trim() !== "" && !root.isVerifying)
                loading: root.isVerifying
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
            // 不允许将自己添加为可见用户
            var selfId = root.currentUserId ? root.currentUserId.trim() : "";
            var selfName = root.currentUserName ? root.currentUserName.trim() : "";
            if ((selfId && selfId === userId) || (selfName && selfName === userName)) {
                root.hasError = true;
                root.errorMessage = qsTr("You cannot add yourself as a visible user");
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
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            SelectableText {
                width: parent.width
                text: userNotFoundDialog.message
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textLabel
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
                        font.pixelSize: Theme.Typography.body
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
