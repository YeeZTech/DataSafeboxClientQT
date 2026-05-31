import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Item {
    id: root
    width: parent ? parent.width : 778
    height: parent ? parent.height : 801

    property string domainName: ""
    property string payer: ""
    property var payerOptions: ["创建者", "使用者"]
    property var visibleUsers: []
    property string description: ""
    readonly property string trimmedDomainName: domainName.trim()
    readonly property string domainNameError: {
        var name = root.trimmedDomainName;
        if (name.length === 0) {
            return "";
        }
        if (name.length < 2 || name.length > 32) {
            return qsTr("Name must be between 2 and 32 characters");
        }
        if (!/^[A-Za-z0-9_\-\u4E00-\u9FFF]+$/.test(name)) {
            return qsTr("Name contains illegal characters, only Chinese, English, numbers, _ and - are supported");
        }
        return "";
    }
    property bool isValid: trimmedDomainName !== "" && domainNameError === "" && payer !== "" && description.length <= 500
    property bool isSubmitting: false
    property var currentUser: null
    // Max width for the form content area — keeps left/right margins equal on wide screens
    readonly property int maxFormWidth: 680
    // Unified typography
    property string fontFamily: "Microsoft YaHei"
    property int fontSizeTitle: 28
    property int fontSizeLabel: 14
    property int fontSizeBody: 16
    property int fontSizeCaption: 14

    signal submit
    signal cancel

    // Reset form when it becomes visible
    onVisibleChanged: {
        if (visible) {
            resetForm();
        }
    }

    // Function to reset all form fields
    function resetForm() {
        isSubmitting = false;
        domainName = "";
        payer = "";
        visibleUsers = [];
        description = "";
        if (nameInput) {
            nameInput.text = "";
        }
        if (descriptionArea) {
            descriptionArea.text = "";
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            width: parent.width
            height: 79.993
            color: Theme.Colors.backgroundWhite
            border.width: 0

            SelectableText {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Create Security Domain")
                font.family: root.fontFamily
                font.pixelSize: root.fontSizeTitle
                font.weight: Font.Medium
                color: Theme.Colors.textTitle
            }
        }

        // Form content area
        Rectangle {
            width: parent.width
            height: parent.height - 79.993 - 79.993
            color: Theme.Colors.backgroundWhite  // White background for main content area
            clip: true

            Item {
                id: scrollView
                anchors.fill: parent
                clip: true  // Prevent overflow; layout uses responsive widths

                Flickable {
                    id: formFlickable
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: formContent.height
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                    }

                    Item {
                        id: formContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Math.max(32, (parent.width - root.maxFormWidth) / 2)
                        anchors.rightMargin: Math.max(32, (parent.width - root.maxFormWidth) / 2)
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        property int spacingRow: 40
                        property int labelWidth: 110  // 固定宽度，确保标签对齐
                        property int fieldWidth: Math.max(240, width - labelWidth - spacingRow)  // 根据formContent宽度计算
                        height: descriptionRow.y + descriptionRow.height + 16  // 动态计算高度，底部边距从24改为16

                        // Background MouseArea to clear focus when clicking empty space
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: {
                                nameInput.focus = false;
                                descriptionArea.focus = false;
                                root.forceActiveFocus();
                            }
                        }
                        FormField {
                            id: nameRow
                            anchors.top: parent.top
                            anchors.topMargin: 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            label: qsTr("Name:")
                            required: true
                            errorText: root.domainNameError
                            labelWidth: formContent.labelWidth
                            fieldSpacing: formContent.spacingRow

                            Rectangle {
                                width: parent.width
                                height: 36
                                radius: 8
                                antialiasing: true
                                smooth: true
                                clip: true
                                color: {
                                    if (nameInput.activeFocus)
                                        return Theme.Colors.backgroundWhite;
                                    if (nameInput.text.length > 0)
                                        return Theme.Colors.backgroundWhite;
                                    return nameInputMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite;
                                }
                                border.color: root.domainNameError.length > 0 ? Theme.Colors.requiredMarker : Theme.Colors.borderField
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 180
                                    }
                                }

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeBody
                                    color: Theme.Colors.textLabel
                                    selectByMouse: true
                                    selectionColor: Theme.Colors.accent
                                    selectedTextColor: Theme.Colors.textHeading

                                    onTextChanged: {
                                        root.domainName = text;
                                    }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: qsTr("Please enter security domain name")
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSizeBody
                                        color: Theme.Colors.textSecondary
                                        visible: !nameInput.text && !nameInput.activeFocus
                                    }
                                }

                                // Right-click context menu for name input
                                InputContextMenu {
                                    anchors.fill: parent
                                    target: nameInput
                                }

                                // Hover detection area
                                MouseArea {
                                    id: nameInputMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor
                                }
                            }
                        }

                        // Instance Fee Payer field - radio button selector
                        PayerSelector {
                            id: payerRow
                            anchors.top: nameRow.bottom
                            anchors.topMargin: 40
                            anchors.left: parent.left
                            anchors.right: parent.right
                            labelWidth: formContent.labelWidth
                            fieldWidth: formContent.fieldWidth
                            fieldSpacing: formContent.spacingRow
                            selectedPayer: root.payer
                            creatorValue: root.payerOptions.length > 0 ? root.payerOptions[0] : ""
                            userValue: root.payerOptions.length > 1 ? root.payerOptions[1] : ""
                            fontFamily: root.fontFamily
                            fontSizeLabel: root.fontSizeLabel
                            fontSizeBody: root.fontSizeBody
                            onPayerSelected: function (payer) {
                                root.payer = payer;
                            }
                        }

                        VisibleUserTable {
                            id: visibleUsersColumn
                            anchors.top: payerRow.bottom
                            anchors.topMargin: 40
                            anchors.left: parent.left
                            anchors.right: parent.right
                            users: root.visibleUsers
                            labelWidth: formContent.labelWidth
                            fieldWidth: formContent.fieldWidth
                            fieldSpacing: formContent.spacingRow
                            fontFamily: root.fontFamily
                            fontSizeLabel: root.fontSizeLabel
                            fontSizeBody: root.fontSizeBody
                            onAddUserRequested: {
                                addUserDialog.domainCreator = root.currentUser ? (root.currentUser.userName || "") : "";
                                addUserDialog.open();
                            }
                            onRemoveUserRequested: function (index) {
                                var users = root.visibleUsers ? root.visibleUsers.slice() : [];
                                users.splice(index, 1);
                                root.visibleUsers = users;
                            }
                        }

                        // Description field - dynamically positioned below user list
                        FormField {
                            id: descriptionRow
                            anchors.top: visibleUsersColumn.bottom
                            anchors.topMargin: 40  // 与其他字段间距保持一致
                            anchors.left: parent.left
                            anchors.right: parent.right
                            label: qsTr("Description:")
                            required: false
                            labelWidth: formContent.labelWidth
                            fieldSpacing: formContent.spacingRow
                            height: Math.max(140, Math.min(280, scrollView.height - y - 50))  // 动态计算高度，最小140，最大280，50为底部留白

                            // Text area
                            Item {
                                width: parent.width
                                height: descriptionRow.height  // 与 FormField 高度一致，自动调整

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    antialiasing: true
                                    smooth: true
                                    clip: true
                                    color: {
                                        if (descriptionArea.activeFocus)
                                            return Theme.Colors.backgroundWhite;
                                        if (descriptionArea.text.length > 0)
                                            return Theme.Colors.backgroundWhite;
                                        return descriptionHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite;
                                    }
                                    border.color: Theme.Colors.borderField
                                    border.width: 1
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 180
                                        }
                                    }

                                    ScrollView {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        anchors.topMargin: 8
                                        anchors.bottomMargin: 24
                                        clip: true
                                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                        TextArea {
                                            id: descriptionArea
                                            width: parent.width
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSizeBody
                                            color: Theme.Colors.textLabel  // 输入文字颜色
                                            background: null
                                            wrapMode: TextArea.Wrap
                                            selectByMouse: true
                                            selectionColor: Theme.Colors.accent
                                            selectedTextColor: Theme.Colors.textHeading

                                            // Remove default padding to align with placeholder
                                            leftPadding: 0
                                            rightPadding: 0
                                            topPadding: 0
                                            bottomPadding: 0

                                            property int maxLength: 500

                                            onTextChanged: {
                                                if (text.length <= maxLength) {
                                                    root.description = text;
                                                } else {
                                                    var cursorPos = cursorPosition;
                                                    text = root.description;
                                                    cursorPosition = Math.min(cursorPos - 1, text.length);
                                                }
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 0  // Align with TextArea text position
                                                anchors.top: parent.top
                                                anchors.topMargin: 0  // Align with TextArea text position
                                                verticalAlignment: Text.AlignTop
                                                text: qsTr("Please describe the security domain's purpose so other users can understand it.")
                                                font.family: root.fontFamily
                                                font.pixelSize: root.fontSizeBody
                                                color: Theme.Colors.textSecondary
                                                visible: !descriptionArea.text && !descriptionArea.activeFocus
                                            }
                                        }
                                    }

                                    // Right-click context menu for description input
                                    InputContextMenu {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12  // Match ScrollView margins
                                        anchors.rightMargin: 12
                                        anchors.topMargin: 8
                                        anchors.bottomMargin: 24
                                        target: descriptionArea
                                        z: 1  // Above ScrollView content
                                    }

                                    // Hover detection area
                                    MouseArea {
                                        id: descriptionHoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        propagateComposedEvents: true
                                    }
                                    SelectableText {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        text: descriptionArea.text.length + "/500"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSizeCaption
                                        color: Theme.Colors.textCounter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 79.993
            color: Theme.Colors.backgroundWhite
            border.color: Theme.Colors.borderSlate
            border.width: 0.653

            PrimaryButton {
                id: submitButton
                anchors.centerIn: parent
                text: root.isSubmitting ? qsTr("Creating...") : qsTr("Create Security Domain")
                enabled: root.isValid && !root.isSubmitting
                onClicked: {
                    if (root.isValid && !root.isSubmitting && root.description.length <= 500) {
                        root.isSubmitting = true;
                        root.submit();
                    }
                }
            }
        }
    }

    // Background overlay for dialog
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: addUserDialog.opened
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: {
                addUserDialog.close();
            }
        }
    }

    // Add Visible User Dialog
    AddVisibleUserDialog {
        id: addUserDialog
        parent: root
        dim: false  // We handle dimming ourselves

        onOpened: {
            // Reset account input when dialog opens
            account = "";
        }

        onAddClicked: function (account) {
            var trimmed = account ? account.trim() : "";
            if (!trimmed)
                return;

            // 从 addUserDialog 获取用户详细信息
            var userInfo = addUserDialog.currentUserInfo || {};
            var userId = (userInfo.user_id || userInfo.authUserId || "").trim();
            var userName = (userInfo.user_name || userInfo.authUserName || "").trim();
            var newAccount = (userInfo.account || "").trim();
            var displayName = (userInfo.displayName || newAccount).trim();
            if (!newAccount || !userId || !userName) {
                return;
            }

            // 仅按 username/account 去重
            for (var i = 0; i < root.visibleUsers.length; i++) {
                var user = root.visibleUsers[i];
                if (user && user.account === newAccount) {
                    return;
                }
            }
            var newUser = {
                account: newAccount,
                displayName: displayName,
                authUserId: userId,
                authUserName: userName
            };

            // Add user to visibleUsers list
            var users = root.visibleUsers;
            users.push(newUser);
            root.visibleUsers = users;
        }

        onCancelClicked:
        // Handled by Popup's closePolicy
        {}
    }
}
