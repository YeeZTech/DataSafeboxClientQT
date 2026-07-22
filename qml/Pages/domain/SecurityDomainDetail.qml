import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0
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

    // 当前安全域是否已归档：派生自后端返回的 domainData.isArchived 字段（经 DSCC-SDK
    // 持久化）。归档是与状态无关的视图划分，不改变安全域的任何状态 (PRD 3.1)。
    readonly property bool isArchived: !!(domainData && domainData.isArchived)

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

    // Check if current user is the creator of this domain
    property bool isCreator: {
        if (!currentUser || !domainData)
            return false;
        return DomainUtils.isCurrentUserDomainCreator(currentUser, domainData);
    }
    property bool isDomainInactive: {
        if (root.domainData && root.domainData.isInactive !== undefined) {
            return !!root.domainData.isInactive || DomainUtils.isDomainInactiveStatus(root.domainData.status);
        }
        return DomainUtils.isDomainInactiveStatus(root.domainData ? root.domainData.status : "");
    }
    property bool isDomainReadOnly: root.isDomainInactive || (!root.isCreator)

    // Domain data - loaded from DataManager or provided by parent
    property int dataVersion: 0
    property bool domainDetailLoading: false
    // 初始化为空对象，后续由 *Loaded 信号 / reloadAllData 显式赋值
    // 不要在 binding 中调用读取 root.domainData 的函数，否则形成自引用 binding loop
    property var domainData: DomainUtils.emptyDomainDetail(root.domainName, root.domainPubKey)

    // Signals
    signal instantiateRequested
    signal contactSupportRequested
    signal archiveRequested
    signal restoreRequested
    signal errorOccurred(string message, string title)

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
        return root.visible && root.width > 0 && root.height > 0 && domainInfoHeader.encryptFileButton.width > 0 && domainInfoHeader.encryptFileButton.height > 0 && onboardingGuide.steps.length > 0;
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
        domainData = DomainUtils.emptyDomainDetail(root.domainName, root.domainPubKey);
        reloadAllData();
        auditDataLoaded = DomainUtils.canRenderAuditEmptyState(domainData);
    }

    // Function to clear all pending operation states
    function clearAllPendingStates() {
        // Clear deactivate domain pending state
        if (deactivateDomainState.isPending) {
            deactivateDomainState.isPending = false;
            deactivateDomainState.pendingDomainPubKey = "";
            deactivateDomainState.pendingDomainCode = "";
        }

        // Clear remove domain pending state
        if (removeDomainState.isPending) {
            removeDomainState.isPending = false;
            removeDomainState.pendingDomainCode = "";
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
        if (removeDomainDialog.opened) {
            removeDomainDialog.close();
        }
    }

    function resetAllPagedCardsToFirstPage() {
        if (typeof domainTabView !== "undefined" && domainTabView) {
            if (domainTabView.visibleUsersCard)
                domainTabView.visibleUsersCard.currentPage = 1;
            if (domainTabView.relatedInstancesCard)
                domainTabView.relatedInstancesCard.currentPage = 1;
            if (domainTabView.appWhitelistAuditCard)
                domainTabView.appWhitelistAuditCard.currentPage = 1;
            if (domainTabView.exportAuditCard)
                domainTabView.exportAuditCard.currentPage = 1;
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
            domainData = DomainUtils.emptyDomainDetail(root.domainName, root.domainPubKey);
            return;
        }
        auditDataLoaded = DomainUtils.canRenderAuditEmptyState(domainData);
    }

    onDomainDataChanged: {
        if (domainData && domainData.name && domainData.name !== domainName) {
            domainName = domainData.name;
        }
        if (domainData && domainData.pubKey && domainData.pubKey !== domainPubKey) {
            domainPubKey = domainData.pubKey;
        }
        if (!auditDataLoaded && DomainUtils.canRenderAuditEmptyState(domainData)) {
            auditDataLoaded = true;
        }
    }

    Component.onCompleted: {
        auditDataLoaded = DomainUtils.canRenderAuditEmptyState(domainData);
    }

    // removeUserState properties promoted to root for QML delegate scope access

    // Pending state for deactivating domain
    QtObject {
        id: deactivateDomainState
        property bool isPending: false
        property string pendingDomainPubKey: ""
        property string pendingDomainCode: ""
    }

    // Pending state for removing (deleting) domain
    QtObject {
        id: removeDomainState
        property bool isPending: false
        property string pendingDomainCode: ""
    }

    // Add Visible User Dialog
    AddVisibleUserDialog {
        id: addUserDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
        domainInactive: root.isDomainInactive

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
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
        domainName: root.domainName
        domainPubKey: root.domainPubKey
        domainInactive: root.isDomainInactive

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

        onContactSupportRequested: {
            root.contactSupportRequested();
        }

        onSendToCliRequested: function (filePath) {
            sendToCliDialog.filePath = filePath;
            sendToCliDialog.open();
        }
    }

    // 把刚加密好的 .sealed 点对点发给命令行客户端（替代 U 盘 / scp 搬运）
    SendToCliDialog {
        id: sendToCliDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
    }

    // User (non-creator) encrypt hint dialog (PRD 3.6)
    UserEncryptHintDialog {
        id: userEncryptHintDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
    }

    // Deactivate Confirm Dialog
    DeactivateConfirmDialog {
        id: deactivateDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
        domainName: root.domainData.name

        onConfirmClicked: {
            handleDeactivateDomain();
        }
    }

    // Remove Domain Confirm Dialog (PRD 3.2)
    RemoveDomainConfirmDialog {
        id: removeDomainDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered

        onConfirmClicked: {
            handleDeleteDomain();
        }
    }

    // Export Detail Dialog
    ExportDetailDialog {
        id: exportDetailDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
        isCreator: root.isCreator
        allowApproveReject: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = exportDetailDialog.exportId || "";
            var _fileCode = exportDetailDialog.fileCode || "";
            var _fileHash = exportDetailDialog.fileHash || "";
            if (!_applyCode) {
                root.errorOccurred(qsTr("Application ID is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileCode) {
                root.errorOccurred(qsTr("File code is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileHash) {
                root.errorOccurred(qsTr("File hash is required"), qsTr("File Export Review"));
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
                root.errorOccurred(qsTr("Application ID is required"), qsTr("File Export Review"));
                return;
            }
            if (!_fileCode) {
                root.errorOccurred(qsTr("File code is required"), qsTr("File Export Review"));
                return;
            }
            root.auditRequestPending = true;
            DsccBridge.auditRequest(_applyCode, _fileCode, false, "");
        }
    }

    // Instance Detail Dialog (shared for all statuses, including pending)
    InstanceDetailDialog {
        id: instanceDetailDialog
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
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
        parent: root
        dim: false  // Dimming is handled by dialogBackdrop so only this page is covered
        showActionButtons: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending)
                return;
            var _applyCode = appWhitelistDetailDialog.applyCode || "";
            var _fileCode = appWhitelistDetailDialog.fileCode || "";
            var _fileHash = appWhitelistDetailDialog.fileHash || "";
            if (!_applyCode) {
                root.errorOccurred(qsTr("Application ID is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileCode) {
                root.errorOccurred(qsTr("File code is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileHash) {
                root.errorOccurred(qsTr("File hash is required"), qsTr("App Whitelist Review"));
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
                root.errorOccurred(qsTr("Application ID is required"), qsTr("App Whitelist Review"));
                return;
            }
            if (!_fileCode) {
                root.errorOccurred(qsTr("File code is required"), qsTr("App Whitelist Review"));
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

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

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

            DomainInfoHeader {
                id: domainInfoHeader
                width: parent.width
                domainName: root.domainData.name
                isCreator: root.isCreator
                isDomainInactive: root.isDomainInactive
                encryptButtonBusy: root.encryptButtonBusy
                domainPubKey: root.domainPubKey || (root.domainData && root.domainData.pubKey ? root.domainData.pubKey : "")

                onInstantiateRequested: root.instantiateRequested()
                onGuideRequested: onboardingGuide.show()
                onErrorOccurred: function (message, title) {
                    root.errorOccurred(message, title);
                }
                onEncryptRequested: {
                    root.encryptButtonBusy = true;
                    encryptFileDialog.open();
                }
                onEncryptUserHintRequested: userEncryptHintDialog.open()
            }

            DomainTabView {
                id: domainTabView
                width: parent.width
                domainData: root.domainData
                isDomainReadOnly: root.isDomainReadOnly
                isCreator: root.isCreator
                isDomainInactive: root.isDomainInactive
                isArchived: root.isArchived
                currentUser: root.currentUser
                isEditingDescription: root.isEditingDescription
                editedDescription: root.editedDescription
                isDescriptionSaving: root.isDescriptionSaving
                descriptionErrorMessage: root.descriptionErrorMessage
                domainCreatorText: DomainUtils.domainCreatorDisplayText(root.domainData)
                payerText: DomainUtils.formatPayerText(root.domainData.payer, qsTr("Creator"), qsTr("User"), "-")
                operationBusy: root.visibleUserOperationState_busy
                pendingRemovedAccount: root.removeUserState_pendingRemovedAccount
                actionRightMargin: root.actionRightMargin
                actionTextPixelSize: root.actionTextPixelSize
                actionTextWeight: root.actionTextWeight

                onEditedDescriptionUpdated: function (text) {
                    root.editedDescription = text;
                }
                onDescriptionErrorMessageUpdated: function (text) {
                    root.descriptionErrorMessage = text;
                }

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

                onAddUserRequested: {
                    addUserDialog.domainCreator = root.domainData.creator || "";
                    addUserDialog.currentUserName = root.currentUser ? (root.currentUser.userName || "") : "";
                    addUserDialog.currentUserId = root.currentUser ? (root.currentUser.authUserId || "") : "";
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

                onViewInstanceRequested: function (instanceData, isApprover) {
                    instanceDetailDialog.instanceId = instanceData.instanceCode || instanceData.id || "";
                    instanceDetailDialog.status = instanceData.status || "";
                    instanceDetailDialog.creator = DomainUtils.resolveInstanceApplicantText(instanceData, root.domainData ? root.domainData.visibleUsers : []);
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

                onViewWhitelistAuditRequested: function (auditData) {
                    appWhitelistDetailDialog.instanceCode = auditData.applyCode || "";
                    appWhitelistDetailDialog.applyCode = auditData.applyCode || "";
                    appWhitelistDetailDialog.status = auditData.status || "";
                    appWhitelistDetailDialog.creator = auditData.applicantUserName || auditData.applicant || "";
                    appWhitelistDetailDialog.instanceName = auditData.instanceName || "";
                    appWhitelistDetailDialog.appliedTime = Theme.Utils.formatDateTime(auditData.applyTime || "");
                    appWhitelistDetailDialog.duration = auditData.duration ? (auditData.duration + qsTr(" months")) : "-";
                    appWhitelistDetailDialog.cost = auditData.cost || "";
                    var whlProcs = DomainUtils.resolveWhitelistProcessesByRow(auditData);
                    appWhitelistDetailDialog.appName = (whlProcs.length > 0 ? (whlProcs[0].masterFileName || "") : "") || qsTr("App Name");
                    appWhitelistDetailDialog.processes = whlProcs;
                    appWhitelistDetailDialog.selectedProcessIndex = 0;
                    appWhitelistDetailDialog.fileCode = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileCode || "") : "";
                    appWhitelistDetailDialog.fileHash = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileHash || "") : "";
                    appWhitelistDetailDialog.open();
                }

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

                onDeactivateRequested: deactivateDialog.open()

                onRemoveDomainRequested: removeDomainDialog.open()

                onArchiveRequested: root.archiveRequested()

                onRestoreRequested: root.restoreRequested()
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

        // 调用 DSCC 接口关闭安全域，结果在本页 onDomainClosed / onDomainCloseFailed 中处理，
        // 成功后保持在详情页，列表/概要刷新由 main.qml 的 onDomainClosed 处理
        DsccBridge.closeDomain(domainCode);
    }

    // Function to handle domain removal (PRD 3.2)
    function handleDeleteDomain() {
        // 仅创建方可移除创建失败/已关闭状态的安全域
        if (!root.isCreator || !root.isDomainInactive) {
            return;
        }

        // Prevent duplicate clicks - check if already pending
        if (removeDomainState.isPending) {
            return;
        }
        var domainCode = root.currentDomainCode || "";
        if (!domainCode) {
            return;
        }
        removeDomainState.isPending = true;
        removeDomainState.pendingDomainCode = domainCode;

        // 调用 DSCC 接口移除安全域，结果在 main.qml 的 onDomainDeleted / 本页 onDomainDeleteFailed 中处理
        DsccBridge.deleteDomain(domainCode);
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
            updated.instances = DateTimeUtils.sortByTimeDesc(DomainUtils.normalizeInstances(instances || []), "createdAt", "appliedTime");
            root.domainData = updated;
        }

        function onAuditsLoaded(domainCode, applyType, audits) {
            if (domainCode !== root.currentDomainCode)
                return;
            var updated = Object.assign({}, root.domainData);
            if (applyType === 1) {
                updated.appWhitelistAudits = DateTimeUtils.sortByTimeDesc(DomainUtils.dedupeWhitelistAudits(audits || []), "applyTime", "createdAt");
            } else if (applyType === 2) {
                updated.exportAudits = DateTimeUtils.sortByTimeDesc(DomainUtils.dedupeExportAudits(audits || []), "applyTime", "createdAt");
            }
            updated._syncedFromBackend = true;
            root.domainData = updated;
            auditDataLoaded = DomainUtils.canRenderAuditEmptyState(root.domainData);
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
            root.errorOccurred(errorMessage || qsTr("Failed to add user"), qsTr("Add Visible User"));
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
            root.errorOccurred(errorMessage || qsTr("Failed to remove user"), qsTr("Remove Visible User"));
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
            root.errorOccurred(errorMessage || qsTr("Failed to save description"), qsTr("Edit Description"));
        }

        function onDomainCloseFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            deactivateDomainState.isPending = false;
            deactivateDomainState.pendingDomainPubKey = "";
            deactivateDomainState.pendingDomainCode = "";
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to disable security domain"));
            root.errorOccurred(errorMessage || qsTr("Failed to disable security domain"), qsTr("Disable Security Domain"));
        }

        function onDomainClosed(operationId, domainCode) {
            if (domainCode !== root.currentDomainCode)
                return;
            deactivateDomainState.isPending = false;
            deactivateDomainState.pendingDomainPubKey = "";
            deactivateDomainState.pendingDomainCode = "";
        // 列表/概要刷新由 main.qml 统一处理（保持在详情页）
        }

        function onDomainDeleteFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode)
                return;
            removeDomainState.isPending = false;
            removeDomainState.pendingDomainCode = "";
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to remove security domain"));
            root.errorOccurred(errorMessage || qsTr("Failed to remove security domain"), qsTr("Remove Security Domain"));
        }

        // 注意：onDomainDeleted 成功的导航/刷新由 main.qml 统一处理（切换至 home + 刷新列表）

        function onAuditInstanceRequestSuccess(operationId, instanceCode) {
            root.instanceAuditPending = false;
            DsccBridge.loadInstances(root.currentDomainCode);
        }

        function onAuditInstanceRequestFailed(operationId, instanceCode, notification) {
            root.instanceAuditPending = false;
            var errorMessage = DsccBridge.notificationMessage(notification, qsTr("Failed to audit instance"));
            root.errorOccurred(errorMessage || qsTr("Failed to audit instance"), qsTr("Instance Audit"));
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
            root.errorOccurred(errorMessage || qsTr("Failed to audit request"), qsTr("Audit Request"));
            DsccBridge.loadAudits(root.currentDomainCode, 1);
            DsccBridge.loadAudits(root.currentDomainCode, 2);
        }
    }

    // Scoped dim backdrop for all dialogs on this page.
    // The dialogs use dim:false so Qt's default window-wide modal dim is suppressed;
    // this rectangle fills only the detail page, keeping the left sidebar bright and
    // interactive. A press here closes the open dialog (mirrors CloseOnPressOutside,
    // which no longer fires once the modal dimmer is disabled).
    Rectangle {
        id: dialogBackdrop
        anchors.fill: parent
        z: 50
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: addUserDialog.opened || encryptFileDialog.opened || userEncryptHintDialog.opened || deactivateDialog.opened || removeDomainDialog.opened || exportDetailDialog.opened || instanceDetailDialog.opened || appWhitelistDetailDialog.opened || encryptFileDialog.successPopup.opened || encryptFileDialog.failurePopup.opened || sendToCliDialog.opened

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // The encrypt dialog must stay open while an encryption is running.
                if (encryptFileDialog.opened) {
                    if (!encryptFileDialog._encrypting)
                        encryptFileDialog.close();
                } else if (userEncryptHintDialog.opened) {
                    userEncryptHintDialog.close();
                } else if (addUserDialog.opened) {
                    addUserDialog.close();
                } else if (deactivateDialog.opened) {
                    deactivateDialog.close();
                } else if (removeDomainDialog.opened) {
                    removeDomainDialog.close();
                } else if (exportDetailDialog.opened) {
                    exportDetailDialog.close();
                } else if (instanceDetailDialog.opened) {
                    instanceDetailDialog.close();
                } else if (appWhitelistDetailDialog.opened) {
                    appWhitelistDetailDialog.close();
                } else if (encryptFileDialog.successPopup.opened) {
                    encryptFileDialog.successPopup.close();
                } else if (encryptFileDialog.failurePopup.opened) {
                    encryptFileDialog.failurePopup.close();
                } else if (sendToCliDialog.opened) {
                    // 传输进行中不能被点外部误关，否则等于悄悄中止传输。
                    if (!sendToCliDialog._active)
                        sendToCliDialog.close();
                }
            }
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
                targetItem: domainInfoHeader.encryptFileButton
            },
            {
                title: qsTr("Create Security Domain Instance"),
                desc: qsTr("Create an encrypted storage instance on your device. Requires review and approval by the security domain creator before use."),
                targetItem: domainInfoHeader.createInstanceButton
            },
            {
                title: qsTr("Visible User Management"),
                desc: qsTr("Manage who can view this security domain and apply for instances. Creator can add or remove users anytime."),
                targetItem: domainTabView.visibleUsersCard
            },
            {
                title: qsTr("Related Security Domain Instances"),
                desc: qsTr("View all instances under this security domain. Creator can review and manage the full lifecycle of instance applications.\n\nStatus:\n- Pending Review: Awaiting creator's approval\n- Authorized: Ready to start\n- Running: Instance is active\n- Rejected: Application denied\n- Ended: Instance stopped"),
                targetItem: domainTabView.relatedInstancesCard
            },
            {
                title: qsTr("App Whitelist Review"),
                desc: qsTr("Review process/app whitelist applications. Approved apps can read/write files in the instance. Unapproved apps cannot access encrypted data."),
                targetItem: domainTabView.appWhitelistAuditCard
            },
            {
                title: qsTr("File Export Review"),
                desc: qsTr("Review file export applications. Creator can approve or reject. Only approved files can be exported, ensuring data security."),
                targetItem: domainTabView.exportAuditCard
            }
        ]

        // Show the guide only when user clicks "View Feature Guide" button.
    }
}
