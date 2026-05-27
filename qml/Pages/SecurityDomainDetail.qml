import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as Theme
import "DomainUtils.js" as DomainUtils
import "DateTimeUtils.js" as DateTimeUtils

Item {
    id: root
    width: 992
    height: 801

    // Domain identification properties - set from parent
    property string domainPubKey: ""
    property string domainName: ""

    // Cached domainCode from current domain detail
    property string currentDomainCode: ""

    // Current user - set from parent (Main.qml)
    property var currentUser: null

    // Pending state for removing visible user (kept on root for delegate scope access)
    property string removeUserState_pendingRemovedAccount: ""
    property string removeUserState_pendingRemovedAuthUserId: ""
    property string removeUserState_pendingDomainPubKey: ""
    property string removeUserState_pendingDomainCode: ""
    // visibleUserOperationState promoted to root for delegate scope access
    property bool visibleUserOperationState_busy: false

    // Pending state for adding visible user
    property var pendingAddUserFullInfo: null

    // Pending state for instance audit
    property bool instanceAuditPending: false

    // Pending state for audit request (app whitelist / export)
    property bool auditRequestPending: false

    // Encrypt action state for header button
    property bool encryptButtonBusy: false

    // Description saving state
    property bool isDescriptionSaving: false

    function domainCreatorDisplayText(detail) {
        return DomainUtils.domainCreatorDisplayText(detail || root.domainData || {});
    }

    function isCurrentUserDomainCreator(detail) {
        return DomainUtils.isCurrentUserDomainCreator(currentUser, detail);
    }

    function isDomainInactiveStatus(statusText) {
        return DomainUtils.isDomainInactiveStatus(statusText);
    }

    // Check if current user is the creator of this domain
    property bool isCreator: {
        if (!currentUser || !domainData)
            return false;
        return isCurrentUserDomainCreator(domainData);
    }
    property bool isDomainInactive: {
        if (root.domainData && root.domainData.isInactive !== undefined) {
            return !!root.domainData.isInactive || isDomainInactiveStatus(root.domainData.status);
        }
        return isDomainInactiveStatus(root.domainData ? root.domainData.status : "");
    }
    property bool isDomainReadOnly: root.isDomainInactive || (!root.isCreator)

    // Domain data - loaded from DataManager or provided by parent
    property int dataVersion: 0
    property bool domainDetailLoading: false
    // 初始化为空对象，后续由 *Loaded 信号 / reloadAllData 显式赋值
    // 不要在 binding 中调用读取 root.domainData 的函数，否则形成自引用 binding loop
    property var domainData: emptyDomainDetail()

    // Signals
    signal instantiateRequested

    property bool _pendingGuideShow: false
    property int _guideShowRetryCount: 0

    /** 从外部触发功能引导弹窗显示（安全域创建成功后调用） */
    function showGuide() {
        _pendingGuideShow = true;
        _guideShowRetryCount = 0;
        guideShowTimer.restart();
    }

    // Description editing state
    property bool isEditingDescription: false
    property string editedDescription: ""
    property string _originalDescription: ""
    property string descriptionErrorMessage: ""
    // Shared right alignment baseline for 添加/操作/查看/移除
    readonly property int actionRightMargin: 6
    readonly property int actionTextPixelSize: 14
    readonly property int actionTextWeight: Font.Medium

    property bool auditDataLoaded: false

    function resetAuditDataLoading() {
        auditDataLoaded = false;
    }

    function canShowGuideNow() {
        return root.visible && root.width > 0 && root.height > 0 && encryptFileButton.width > 0 && encryptFileButton.height > 0 && onboardingGuide.steps.length > 0;
    }

    Timer {
        id: guideShowTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (!root._pendingGuideShow) {
                stop();
                return;
            }
            root._guideShowRetryCount++;
            if (root.canShowGuideNow()) {
                root._pendingGuideShow = false;
                stop();
                onboardingGuide.show();
                return;
            }
            if (root._guideShowRetryCount >= 30) {
                root._pendingGuideShow = false;
                stop();
            }
        }
    }

    function canRenderAuditEmptyState(detail) {
        var d = detail || root.domainData;
        if (!d) {
            return false;
        }
        if (d._syncedFromBackend) {
            return true;
        }
        // If backend returned audit arrays (even empty), we can render empty state
        if (Array.isArray(d.appWhitelistAudits) || Array.isArray(d.exportAudits)) {
            return true;
        }
        var hasWhitelist = !!(d.appWhitelistAudits && d.appWhitelistAudits.length > 0);
        var hasExport = !!(d.exportAudits && d.exportAudits.length > 0);
        return hasWhitelist || hasExport;
    }

    // Function to get domain data (called when domainName changes)
    function emptyDomainDetail() {
        return {
            name: domainName || "",
            creator: "",
            status: "",
            createdAt: "",
            payer: "",
            description: "",
            visibleUsers: [],
            instances: [],
            appWhitelistAudits: [],
            exportAudits: [],
            pubKey: domainPubKey || "",
            isInactive: false
        };
    }

    function toJsArray(value) {
        return DomainUtils.toJsArray(value);
    }
    function normalizeInstances(instances) {
        return DomainUtils.normalizeInstances(instances);
    }
    function sortByTimeDesc(list, p, s) {
        return DateTimeUtils.sortByTimeDesc(DomainUtils.toJsArray(list), p, s);
    }
    function dedupeWhitelistAudits(list) {
        return DomainUtils.dedupeWhitelistAudits(list);
    }
    function dedupeExportAudits(list) {
        return DomainUtils.dedupeExportAudits(list);
    }

    function resolveInstanceApplicantText(instance) {
        return DomainUtils.resolveInstanceApplicantText(instance, root.domainData ? root.domainData.visibleUsers : []);
    }
    function resolveWhitelistProcessesByRow(row) {
        return DomainUtils.resolveWhitelistProcessesByRow(row);
    }

    function reloadAllData() {
        if (!root.currentDomainCode)
            return;
        if (typeof DsccBridge === "undefined")
            return;
        DsccBridge.loadDomainSummary(root.currentDomainCode);
        DsccBridge.loadInstances(root.currentDomainCode);
        DsccBridge.loadAudits(root.currentDomainCode, 1);
        DsccBridge.loadAudits(root.currentDomainCode, 2);
    }

    function formatPayerText(payerValue) {
        if (!payerValue)
            return "-";
        if (payerValue === "创建方" || payerValue === "安全域创建方" || payerValue === "创建者")
            return qsTr("Creator");
        if (payerValue === "使用方" || payerValue === "安全域使用方" || payerValue === "使用者")
            return qsTr("User");
        return payerValue;
    }

    // Update domainData when domainName changes
    onDomainNameChanged: {
        // 仅清理状态，不重新加载数据（加载由 onCurrentDomainCodeChanged 驱动）
        clearAllPendingStates();
    }

    onDomainPubKeyChanged: {
        // 仅清理状态，不重新加载数据（加载由 onCurrentDomainCodeChanged 驱动）
        clearAllPendingStates();
    }

    onCurrentDomainCodeChanged: {
        // 切换安全域的唯一入口：清状态 + 重设分页 + 重加全量数据
        clearAllPendingStates();
        resetAllPagedCardsToFirstPage();
        resetAuditDataLoading();
        domainData = emptyDomainDetail();
        reloadAllData();
        auditDataLoaded = canRenderAuditEmptyState(domainData);
    }

    // Function to clear all pending operation states
    function clearAllPendingStates() {
        // Clear deactivate domain pending state
        if (deactivateDomainState.isPending) {
            deactivateDomainState.isPending = false;
            deactivateDomainState.pendingDomainPubKey = "";
            deactivateDomainState.pendingDomainCode = "";
        }

        // Clear remove user pending state
        if (root.removeUserState_pendingRemovedAccount) {
            root.removeUserState_pendingRemovedAccount = "";
            root.removeUserState_pendingDomainPubKey = "";
            root.removeUserState_pendingDomainCode = "";
        }

        // Clear add user pending state
        if (addUserDialog.pendingAccount) {
            addUserDialog.pendingAccount = "";
            addUserDialog.pendingVisibleUsers = [];
            addUserDialog.pendingDomainPubKey = "";
            addUserDialog.pendingDomainCode = "";
        }
        root.visibleUserOperationState_busy = false;

        // Reset description editing state
        isEditingDescription = false;
        editedDescription = "";
        if (addUserDialog.isVerifying) {
            addUserDialog.isVerifying = false;
        }
        addUserDialog.currentUserInfo = null;
        if (addUserDialog.opened) {
            addUserDialog.close();
        }
        if (deactivateDialog.opened) {
            deactivateDialog.close();
        }
    }

    function resetAllPagedCardsToFirstPage() {
        if (typeof visibleUsersCard !== "undefined" && visibleUsersCard) {
            visibleUsersCard.currentPage = 1;
        }
        if (typeof relatedInstancesCard !== "undefined" && relatedInstancesCard) {
            relatedInstancesCard.currentPage = 1;
        }
        if (typeof appWhitelistAuditCard !== "undefined" && appWhitelistAuditCard) {
            appWhitelistAuditCard.currentPage = 1;
        }
        if (typeof exportAuditCard !== "undefined" && exportAuditCard) {
            exportAuditCard.currentPage = 1;
        }
    }

    function isVisibleUserOperationInProgress() {
        return !!root.visibleUserOperationState_busy;
    }

    onDataVersionChanged: {
        // dataVersion 用于外部触发刷新，调用 reloadAllData
        if (root.currentDomainCode && !domainDetailLoading) {
            reloadAllData();
        }
    }

    onDomainDetailLoadingChanged: {
        if (domainDetailLoading) {
            resetAllPagedCardsToFirstPage();
            resetAuditDataLoading();
            domainData = emptyDomainDetail();
            return;
        }
        auditDataLoaded = canRenderAuditEmptyState(domainData);
    }

    onDomainDataChanged: {
        if (domainData && domainData.name && domainData.name !== domainName) {
            domainName = domainData.name;
        }
        if (domainData && domainData.pubKey && domainData.pubKey !== domainPubKey) {
            domainPubKey = domainData.pubKey;
        }
        if (!auditDataLoaded && canRenderAuditEmptyState(domainData)) {
            auditDataLoaded = true;
        }
    }

    Component.onCompleted: {
        auditDataLoaded = canRenderAuditEmptyState(domainData);
    }

    // removeUserState properties promoted to root for QML delegate scope access

    // Pending state for deactivating domain
    QtObject {
        id: deactivateDomainState
        property bool isPending: false
        property string pendingDomainPubKey: ""
        property string pendingDomainCode: ""
    }

    // Add Visible User Dialog
    AddVisibleUserDialog {
        id: addUserDialog

        property string pendingAccount: ""
        property var pendingVisibleUsers: []
        property string pendingDomainPubKey: ""  // 标识哪个域在等待更新
        property string pendingDomainCode: ""

        onAddClicked: function (account) {
            if (root.isDomainReadOnly) {
                return;
            }
            var trimmed = account ? account.trim() : "";
            if (!trimmed) {
                return;
            }
            if (root.isVisibleUserOperationInProgress()) {
                return;
            }
            root.visibleUserOperationState_busy = true;

            // Get current domain detail
            // 从 addUserDialog 获取用户详细信息
            var userInfo = addUserDialog.currentUserInfo || {};
            var userId = (userInfo.user_id || userInfo.authUserId || "").trim();
            var userName = (userInfo.user_name || userInfo.authUserName || "").trim();
            var newAccount = (userInfo.account || "").trim();
            var displayName = (userInfo.displayName || newAccount).trim();
            if (!newAccount || !userId || !userName) {
                root.visibleUserOperationState_busy = false;
                return;
            }

            // Create a copy of visible users list (don't modify original array)
            var existingUsers = (root.domainData && root.domainData.visibleUsers) || [];

            // Check if user already exists (仅按 username/account，大小写敏感)
            var userExists = false;
            for (var i = 0; i < existingUsers.length; i++) {
                if (newAccount && existingUsers[i] && existingUsers[i].account === newAccount) {
                    userExists = true;
                    break;
                }
            }
            if (!userExists) {
                var newUser = {
                    account: newAccount,
                    displayName: displayName,
                    authUserId: userId,
                    authUserName: userName
                };

                // Create new array with all users (existing + new)
                var updatedVisibleUsers = [];
                for (var j = 0; j < existingUsers.length; j++) {
                    updatedVisibleUsers.push(existingUsers[j]);
                }
                updatedVisibleUsers.push(newUser);
                var domainCode = root.currentDomainCode || "";
                if (!domainCode) {
                    root.visibleUserOperationState_busy = false;
                    return;
                }

                // 保存完整用户信息，供成功回调写入本地列表
                root.pendingAddUserFullInfo = newUser;
                DsccBridge.addUserToDomain(domainCode, userId);
            } else {
                root.visibleUserOperationState_busy = false;
            }
        }
    }

    // Encrypt File Dialog
    EncryptFileDialog {
        id: encryptFileDialog
        domainName: root.domainName
        domainPubKey: root.domainPubKey

        onOpened: {
            root.encryptButtonBusy = true;
        }

        onClosed: {
            if (!encryptFileDialog._encrypting) {
                root.encryptButtonBusy = false;
            }
        }

        onEncryptionStateChanged: function (encrypting) {
            if (!encrypting) {
                root.encryptButtonBusy = false;
            }
        }
    }

    // Deactivate Confirm Dialog
    DeactivateConfirmDialog {
        id: deactivateDialog
        domainName: root.domainData.name

        onConfirmClicked: {
            handleDeactivateDomain();
        }
    }

    // Export Detail Dialog
    ExportDetailDialog {
        id: exportDetailDialog
        isCreator: root.isCreator
        allowApproveReject: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = exportDetailDialog.exportId || "";
            var _fileCode = exportDetailDialog.fileCode || "";
            var _fileHash = exportDetailDialog.fileHash || "";
            if (!_applyCode) {
                window.showError(qsTr("Application ID is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileCode) {
                window.showError(qsTr("File code is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileHash) {
                window.showError(qsTr("File hash is required"), qsTr("File Export Review"));
                return;
            }
            root.auditRequestPending = true;
            DsccBridge.auditRequest(_applyCode, _fileCode, true, _fileHash);
        }

        onRejectClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = exportDetailDialog.exportId || "";
            var _fileCode = exportDetailDialog.fileCode || "";
            if (!_applyCode) {
                window.showError(qsTr("Application ID is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileCode) {
                window.showError(qsTr("File code is required"), qsTr("File Export Review"));
                return;
            }
            root.auditRequestPending = true;
            DsccBridge.auditRequest(_applyCode, _fileCode, false, "");
        }
    }

    // Instance Detail Dialog (shared for all statuses, including pending)
    InstanceDetailDialog {
        id: instanceDetailDialog
        parent: Overlay.overlay  // Use application overlay as parent for proper sizing
        allowApproveReject: !root.isDomainReadOnly && !root.instanceAuditPending

        onApproveClicked: {
            if (root.instanceAuditPending)
                return;
            var code = instanceDetailDialog.instanceId || "";
            if (!code)
                return;
            root.instanceAuditPending = true;
            DsccBridge.auditInstanceRequest(code, true);
        }

        onRejectClicked: {
            if (root.instanceAuditPending)
                return;
            var code = instanceDetailDialog.instanceId || "";
            if (!code)
                return;
            root.instanceAuditPending = true;
            DsccBridge.auditInstanceRequest(code, false);
        }
    }

    // App Whitelist Audit Detail Dialog
    AppWhitelistDetailDialog {
        id: appWhitelistDetailDialog
        parent: Overlay.overlay
        showActionButtons: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = appWhitelistDetailDialog.applyCode || "";
            var _fileCode = appWhitelistDetailDialog.fileCode || "";
            var _fileHash = appWhitelistDetailDialog.fileHash || "";
            if (!_applyCode) {
                window.showError(qsTr("Application ID is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileCode) {
                window.showError(qsTr("File code is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileHash) {
                window.showError(qsTr("File hash is required"), qsTr("App Whitelist Review"));
                return;
            }
            root.auditRequestPending = true;
            DsccBridge.auditRequest(_applyCode, _fileCode, true, _fileHash);
        }

        onRejectClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = appWhitelistDetailDialog.applyCode || "";
            var _fileCode = appWhitelistDetailDialog.fileCode || "";
            if (!_applyCode) {
                window.showError(qsTr("Application ID is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileCode) {
                window.showError(qsTr("File code is required"), qsTr("App Whitelist Review"));
                return;
            }
            root.auditRequestPending = true;
            DsccBridge.auditRequest(_applyCode, _fileCode, false, "");
        }
    }

    ScrollView {
        id: detailScrollView
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 64

        background: Rectangle {
            color: "#e8edf3"  // 稍微加深的灰色背景，增强与白色卡片的对比
        }

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // Transparent MouseArea to detect clicks outside descriptionBox for cancel editing
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            enabled: root.isEditingDescription
            z: -1  // Below content

            onPressed: {
                if (root.isEditingDescription) {
                    root.editedDescription = root._originalDescription;
                    root.descriptionErrorMessage = "";
                    root.isEditingDescription = false;
                }
            }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 16  // reduce gap to tighten title上下留白

            // Header with title and buttons
            Item {
                width: parent.width
                height: 32  // tighten header vertical whitespace

                // Title
                Text {
                    id: headerTitleText
                    anchors.left: parent.left
                    anchors.right: headerButtonRow.left
                    anchors.rightMargin: 48  // 2 Chinese chars at 24px ≈ 48px
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.domainData.name
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    color: "#0f172b"
                    elide: Text.ElideRight

                    ToolTip.visible: truncated && headerTitleHover.containsMouse
                    ToolTip.text: root.domainData.name
                    ToolTip.delay: 500

                    HoverHandler {
                        id: headerTitleHover
                        enabled: headerTitleText.truncated
                    }
                }

                // Buttons on the right
                Row {
                    id: headerButtonRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // 查看功能介绍 — 文字链接
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
                            color: guideArea.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : guideArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.3) : Theme.Colors.primary
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
                            onClicked: onboardingGuide.show()
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
                                if (root.isDomainReadOnly) {
                                    return;
                                }
                                root.instantiateRequested();
                            }
                        }
                    }

                    // Only visible to creator and when domain is active
                    Rectangle {
                        id: encryptFileButton
                        readonly property bool disabled: root.isDomainReadOnly || root.encryptButtonBusy
                        width: encryptRow.width + 24  // Dynamic width
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
                                source: Qt.resolvedUrl("icons/icon-encrypt-to-domain.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            // Text - positioned to match Figma design
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
                                if (encryptFileButton.disabled) {
                                    return;
                                }
                                var pubKey = root.domainPubKey || (root.domainData && root.domainData.pubKey ? root.domainData.pubKey : "");
                                if (pubKey && pubKey !== root.domainPubKey) {
                                    root.domainPubKey = pubKey;
                                }
                                if (!pubKey) {
                                    window.showError(qsTr("Security domain public key not found"), qsTr("Encrypt File"));
                                    return;
                                }
                                root.encryptButtonBusy = true;
                                encryptFileDialog.open();
                            }
                        }
                    }
                }
            }

            DomainBasicInfoCard {
                id: basicInfoCard
                width: parent.width
                domainData: root.domainData
                isDomainReadOnly: root.isDomainReadOnly
                isEditingDescription: root.isEditingDescription
                editedDescription: root.editedDescription
                isDescriptionSaving: root.isDescriptionSaving
                descriptionErrorMessage: root.descriptionErrorMessage
                domainCreatorText: root.domainCreatorDisplayText(root.domainData)
                payerText: root.formatPayerText(root.domainData.payer)

                onEditedDescriptionChanged: root.editedDescription = basicInfoCard.editedDescription
                onDescriptionErrorMessageChanged: root.descriptionErrorMessage = basicInfoCard.descriptionErrorMessage

                onEditDescriptionRequested: {
                    root._originalDescription = root.domainData.description || "";
                    root.editedDescription = root._originalDescription;
                    root.descriptionErrorMessage = "";
                    root.isEditingDescription = true;
                }

                onSaveDescriptionRequested: function (text) {
                    var domainCode = root.currentDomainCode || "";
                    if (!domainCode) {
                        root.isEditingDescription = false;
                        return;
                    }
                    root.isDescriptionSaving = true;
                    DsccBridge.updateDomainDesc(domainCode, text);
                }

                onCancelDescriptionRequested: {
                    root.editedDescription = root._originalDescription;
                    root.descriptionErrorMessage = "";
                    root.isEditingDescription = false;
                }
            }

            DomainVisibleUsersCard {
                id: visibleUsersCard
                width: parent.width
                visibleUsers: root.domainData.visibleUsers || []
                isDomainReadOnly: root.isDomainReadOnly
                operationBusy: root.visibleUserOperationState_busy
                pendingRemovedAccount: root.removeUserState_pendingRemovedAccount
                actionRightMargin: root.actionRightMargin
                actionTextPixelSize: root.actionTextPixelSize
                actionTextWeight: root.actionTextWeight

                onAddUserRequested: {
                    addUserDialog.domainCreator = root.domainData.creator || "";
                    addUserDialog.open();
                }

                onRemoveUserRequested: function (account, authUserId) {
                    root.visibleUserOperationState_busy = true;
                    var domainCode = root.currentDomainCode || "";
                    if (!domainCode) {
                        root.visibleUserOperationState_busy = false;
                        return;
                    }
                    root.removeUserState_pendingRemovedAccount = account;
                    root.removeUserState_pendingRemovedAuthUserId = authUserId;
                    root.removeUserState_pendingDomainPubKey = root.domainPubKey || "";
                    root.removeUserState_pendingDomainCode = domainCode;
                    DsccBridge.removeUserFromDomain(domainCode, authUserId);
                }
            }

            DomainInstancesCard {
                id: relatedInstancesCard
                width: parent.width
                instances: root.domainData.instances || []
                visibleUsers: root.domainData.visibleUsers || []
                currentUser: root.currentUser
                domainData: root.domainData
                isDomainReadOnly: root.isDomainReadOnly
                actionRightMargin: root.actionRightMargin
                actionTextPixelSize: root.actionTextPixelSize
                actionTextWeight: root.actionTextWeight

                onViewInstanceRequested: function (instanceData, isApprover) {
                    instanceDetailDialog.instanceId = instanceData.instanceCode || instanceData.id || "";
                    instanceDetailDialog.status = instanceData.status || "";
                    instanceDetailDialog.creator = resolveInstanceApplicantText(instanceData);
                    var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(instanceData.volumnSize !== undefined ? instanceData.volumnSize : instanceData.size);
                    instanceDetailDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes);
                    instanceDetailDialog.appliedTime = Theme.Utils.formatDateTime(instanceData.createdAt || instanceData.appliedTime);
                    instanceDetailDialog.instanceRemainingDays = formatRemainingDays(instanceData);
                    instanceDetailDialog.instanceCost = instanceData.cost || "15,500";
                    instanceDetailDialog.whitelistApps = [];
                    instanceDetailDialog.isApproverView = isApprover;
                    instanceDetailDialog.showActionButtons = (instanceData.status === Theme.Colors.statusPendingReview && !root.isDomainReadOnly);
                    instanceDetailDialog.currentPage = 1;
                    instanceDetailDialog.open();
                }
            }

            DomainWhitelistAuditCard {
                id: appWhitelistAuditCard
                width: parent.width
                audits: root.domainData.appWhitelistAudits || []
                actionRightMargin: root.actionRightMargin
                actionTextPixelSize: root.actionTextPixelSize
                actionTextWeight: root.actionTextWeight

                onViewAuditRequested: function (auditData) {
                    appWhitelistDetailDialog.instanceCode = auditData.applyCode || "";
                    appWhitelistDetailDialog.applyCode = auditData.applyCode || "";
                    appWhitelistDetailDialog.status = auditData.status || "";
                    appWhitelistDetailDialog.creator = auditData.applicantUserName || auditData.applicant || "";
                    appWhitelistDetailDialog.instanceName = auditData.instanceName || "";
                    appWhitelistDetailDialog.appliedTime = Theme.Utils.formatDateTime(auditData.applyTime || "");
                    appWhitelistDetailDialog.duration = auditData.duration ? (auditData.duration + qsTr(" months")) : "-";
                    appWhitelistDetailDialog.cost = auditData.cost || "";
                    var whlProcs = resolveWhitelistProcessesByRow(auditData);
                    appWhitelistDetailDialog.appName = (whlProcs.length > 0 ? (whlProcs[0].masterFileName || "") : "") || qsTr("App Name");
                    appWhitelistDetailDialog.processes = whlProcs;
                    appWhitelistDetailDialog.selectedProcessIndex = 0;
                    appWhitelistDetailDialog.fileCode = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileCode || "") : "";
                    appWhitelistDetailDialog.fileHash = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileHash || "") : "";
                    appWhitelistDetailDialog.open();
                }
            }

            DomainExportAuditCard {
                id: exportAuditCard
                width: parent.width
                audits: root.domainData.exportAudits || []
                actionRightMargin: root.actionRightMargin
                actionTextPixelSize: root.actionTextPixelSize
                actionTextWeight: root.actionTextWeight

                onViewExportRequested: function (auditData) {
                    exportDetailDialog.exportId = auditData.applyCode || auditData.id || "";
                    exportDetailDialog.applicant = auditData.applicantUserName || auditData.applicant || "";
                    exportDetailDialog.fileSize = Number(auditData.fileSize) || 0;
                    exportDetailDialog.status = auditData.status || Theme.Colors.statusPendingReview;
                    exportDetailDialog.applyTime = auditData.applyTime || "";
                    exportDetailDialog.instanceName = auditData.instanceName || "";
                    exportDetailDialog.files = auditData.files || [];
                    exportDetailDialog.reason = auditData.reason || "";
                    exportDetailDialog.fileCode = auditData.fileCode || "";
                    exportDetailDialog.fileHash = auditData.fileHash || "";
                    exportDetailDialog.open();
                }
            }

            // Disable button - only show when status is not "已关闭" and user is creator
            Rectangle {
                id: disableBtn
                height: 38
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 8
                property bool hovered: false
                property bool pressed: false
                color: pressed ? "#ffd5d5" : (hovered ? "#fff5f5" : "#ffffff")
                border.width: 1
                border.color: pressed ? "#ff5050" : (hovered ? "#ff9090" : "#ffa2a2")
                visible: !root.isDomainReadOnly  // Show only when domain is active and current user is creator
                implicitWidth: disableText.implicitWidth + 40  // Auto-size to content with padding

                Text {
                    id: disableText
                    anchors.centerIn: parent
                    text: qsTr("Disable This Security Domain")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: parent.pressed ? "#900006" : (parent.hovered ? "#c50009" : "#e7000b")
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.isDomainReadOnly
                    hoverEnabled: true
                    cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        deactivateDialog.open();
                    }
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                }
            }
        }
    }

    // Function to handle domain deactivation
    function handleDeactivateDomain() {
        if (root.isDomainReadOnly) {
            return;
        }

        // Prevent duplicate clicks - check if already pending
        if (deactivateDomainState.isPending) {
            return;
        }
        var domainCode = root.currentDomainCode || "";
        if (!domainCode) {
            return;
        }
        var pubKey = root.domainPubKey || "";
        deactivateDomainState.isPending = true;
        deactivateDomainState.pendingDomainPubKey = pubKey;
        deactivateDomainState.pendingDomainCode = domainCode;

        // 调用 DSCC 接口关闭安全域，结果在 main.qml 的 onDomainClosed / onDomainCloseFailed 中处理
        DsccBridge.closeDomain(domainCode);
    }

    function formatRemainingDays(instance) {
        var days = DateTimeUtils.remainingDays(instance);
        if (days < 0)
            return "-";
        if (days === 0)
            return "0" + qsTr(" days");
        return days + qsTr(" days");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DsccBridge 数据加载信号：填充 domainData 各字段
    // ──────────────────────────────────────────────────────────────────────────
    Connections {
        target: DsccBridge
        ignoreUnknownSignals: true

        function onDomainSummaryLoaded(domainCode, summary) {
            if (domainCode !== root.currentDomainCode)
                return;
            if (!summary || Object.keys(summary).length === 0)
                return;
            var updated = Object.assign({}, root.domainData, summary);
            // 保持 visibleUsers / instances / appWhitelistAudits / exportAudits 不被覆盖
            if (root.domainData) {
                if (summary.visibleUsers === undefined && root.domainData.visibleUsers !== undefined)
                    updated.visibleUsers = root.domainData.visibleUsers;
                if (root.domainData.instances !== undefined)
                    updated.instances = root.domainData.instances;
                if (root.domainData.appWhitelistAudits !== undefined)
                    updated.appWhitelistAudits = root.domainData.appWhitelistAudits;
                if (root.domainData.exportAudits !== undefined)
                    updated.exportAudits = root.domainData.exportAudits;
            }
            root.domainData = updated;
            if (summary.name && summary.name !== root.domainName)
                root.domainName = summary.name;
            if (summary.pubKey && summary.pubKey !== root.domainPubKey)
                root.domainPubKey = summary.pubKey;
        }

        function onInstancesLoaded(domainCode, instances) {
            if (domainCode !== root.currentDomainCode)
                return;
            var updated = Object.assign({}, root.domainData);
            updated.instances = sortByTimeDesc(normalizeInstances(instances || []), "createdAt", "appliedTime");
            root.domainData = updated;
        }

        function onAuditsLoaded(domainCode, applyType, audits) {
            if (domainCode !== root.currentDomainCode)
                return;
            var updated = Object.assign({}, root.domainData);
            if (applyType === 1) {
                updated.appWhitelistAudits = sortByTimeDesc(dedupeWhitelistAudits(audits || []), "applyTime", "createdAt");
            } else if (applyType === 2) {
                updated.exportAudits = sortByTimeDesc(dedupeExportAudits(audits || []), "applyTime", "createdAt");
            }
            updated._syncedFromBackend = true;
            root.domainData = updated;
            auditDataLoaded = canRenderAuditEmptyState(root.domainData);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DsccBridge 写操作结果信号：可见用户/描述/关闭安全域
    // 全部采用"成功后调用 loadXxx 局部刷新"的统一策略
    // ──────────────────────────────────────────────────────────────────────────
    Connections {
        target: DsccBridge

        function onAddUserToDomainSuccess(operationId, domainCode, userId) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.pendingAddUserFullInfo = null;
            root.visibleUserOperationState_busy = false;
            DsccBridge.loadDomainSummary(root.currentDomainCode);
        }

        function onAddUserToDomainFailed(operationId, domainCode, userId, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.pendingAddUserFullInfo = null;
            root.visibleUserOperationState_busy = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to add user"));
            window.showError(errorMessage || qsTr("Failed to add user"), qsTr("Add Visible User"));
        }

        function onRemoveUserFromDomainSuccess(operationId, domainCode, userId) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.removeUserState_pendingRemovedAccount = "";
            root.removeUserState_pendingRemovedAuthUserId = "";
            root.removeUserState_pendingDomainPubKey = "";
            root.removeUserState_pendingDomainCode = "";
            root.visibleUserOperationState_busy = false;
            DsccBridge.loadDomainSummary(root.currentDomainCode);
        }

        function onRemoveUserFromDomainFailed(operationId, domainCode, userId, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.removeUserState_pendingRemovedAccount = "";
            root.removeUserState_pendingRemovedAuthUserId = "";
            root.removeUserState_pendingDomainPubKey = "";
            root.removeUserState_pendingDomainCode = "";
            root.visibleUserOperationState_busy = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to remove user"));
            window.showError(errorMessage || qsTr("Failed to remove user"), qsTr("Remove Visible User"));
        }

        function onDomainDescUpdated(operationId, domainCode) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.isEditingDescription = false;
            root.isDescriptionSaving = false;
            DsccBridge.loadDomainSummary(root.currentDomainCode);
        }

        function onDomainDescUpdateFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            root.isDescriptionSaving = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to save description"));
            window.showError(errorMessage || qsTr("Failed to save description"), qsTr("Edit Description"));
        }

        function onDomainCloseFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            deactivateDomainState.isPending = false;
            deactivateDomainState.pendingDomainPubKey = "";
            deactivateDomainState.pendingDomainCode = "";
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to disable security domain"));
            window.showError(errorMessage || qsTr("Failed to disable security domain"), qsTr("Disable Security Domain"));
        }

        // 注意：onDomainClosed 成功的导航/刷新由 main.qml 统一处理（切换至 home + 刷新列表）

        function onAuditInstanceRequestSuccess(operationId, instanceCode) {
            root.instanceAuditPending = false;
            DsccBridge.loadInstances(root.currentDomainCode);
        }

        function onAuditInstanceRequestFailed(operationId, instanceCode, notification) {
            root.instanceAuditPending = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to audit instance"));
            window.showError(errorMessage || qsTr("Failed to audit instance"), qsTr("Instance Audit"));
            DsccBridge.loadInstances(root.currentDomainCode);
        }

        function onAuditRequestSuccess(operationId, auditCode, fileCode) {
            root.auditRequestPending = false;
            DsccBridge.loadAudits(root.currentDomainCode, 1);
            DsccBridge.loadAudits(root.currentDomainCode, 2);
        }

        function onAuditRequestFailed(operationId, auditCode, fileCode, notification) {
            root.auditRequestPending = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to audit request"));
            window.showError(errorMessage || qsTr("Failed to audit request"), qsTr("Audit Request"));
            DsccBridge.loadAudits(root.currentDomainCode, 1);
            DsccBridge.loadAudits(root.currentDomainCode, 2);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // First-visit onboarding guide
    // ──────────────────────────────────────────────────────────────────────────
    OnboardingGuide {
        id: onboardingGuide
        anchors.fill: parent
        z: 100
        flickable: detailScrollView.contentItem

        steps: [
            {
                title: qsTr("Encrypt Files to This Security Domain"),
                desc: qsTr("Encrypt files into security-domain-exclusive encrypted files usable only within this domain's instances. Ensures secure file transfer and usage."),
                targetItem: encryptFileButton
            },
            {
                title: qsTr("Create Security Domain Instance"),
                desc: qsTr("Create an encrypted storage instance on your device. Requires review and approval by the security domain creator before use."),
                targetItem: createInstanceButton
            },
            {
                title: qsTr("Visible User Management"),
                desc: qsTr("Manage who can view this security domain and apply for instances. Creator can add or remove users anytime."),
                targetItem: visibleUsersCard
            },
            {
                title: qsTr("Related Security Domain Instances"),
                desc: qsTr("View all instances under this security domain. Creator can review and manage the full lifecycle of instance applications.\n\nStatus:\n- Pending Review: Awaiting creator's approval\n- Authorized: Ready to start\n- Running: Instance is active\n- Rejected: Application denied\n- Ended: Instance stopped"),
                targetItem: relatedInstancesCard
            },
            {
                title: qsTr("App Whitelist Review"),
                desc: qsTr("Review process/app whitelist applications. Approved apps can read/write files in the instance. Unapproved apps cannot access encrypted data."),
                targetItem: appWhitelistAuditCard
            },
            {
                title: qsTr("File Export Review"),
                desc: qsTr("Review file export applications. Creator can approve or reject. Only approved files can be exported, ensuring data security."),
                targetItem: exportAuditCard
            }
        ]

        // Show the guide only when user clicks "View Feature Guide" button.
    }
}
