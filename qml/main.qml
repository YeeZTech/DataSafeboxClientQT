import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Pages 1.0
import DataSafebox.Dialogs 1.0
import DataSafebox.Auth 1.0

ApplicationWindow {
    id: window
    readonly property int sidebarWidth: Math.ceil(sidebar.preferredWidth)
    readonly property int mainContentMinWidth: sidebarWidth * 2
    readonly property int mainContentMaxWidth: 842
    readonly property int windowWidth: sidebarWidth + mainContentMaxWidth
    readonly property int windowHeight: 801

    width: windowWidth
    height: windowHeight
    minimumWidth: windowWidth
    maximumWidth: windowWidth
    minimumHeight: 600
    maximumHeight: 10000
    visible: true
    title: qsTr("DataSafeBox Console")
    color: Theme.Colors.backgroundGray  // slate-50 background

    // Authentication state
    property string authPage: "login"
    property var currentUser: null
    property bool isLoggedIn: currentUser !== null
    property bool logoutInProgress: false

    // State to control which page is shown (within main app)
    property string currentPage: "home"  // "home", "createSecurityDomain", "securityDomainDetail", "instantiateForm", or "securityInstanceDetail"

    property bool hasUpdateNotification: false
    property int loginRetryCount: 0
    property bool showLoginError: false
    property string loginErrorMessage: ""
    readonly property int maxLoginRetries: 3

    // Arrears / paused state
    property bool isAccountArrears: false
    property bool isAccountPaused: false
    // 账单页地址取各环境 profile 里配好的 walletUrl（AppConfig.h），与侧边栏「我的账单」
    // 同一来源。曾经是 apiBaseUrl().replace("api", "wallet")：正式环境的 API 域名是
    // dsbox-api.dianshudata.com，替换后得到 dsbox-wallet.dianshudata.com——这个域名不
    // 存在，点进去只有 DNS 解析失败。
    readonly property string arrearsBillUrl: AppConfig ? AppConfig.walletUrl() : "https://test-dsbox.dianshudata.com/wallet"
    readonly property string arrearsBillLinkText: qsTr("\"My Bills\"")
    readonly property string arrearsAlertMessage: {
        if (window.isAccountPaused) {
            return qsTr("Your account has been suspended and the related functions are unavailable. Please recharge in %1 as soon as possible to ensure business continuity.").arg(window.arrearsBillLinkText);
        }
        if (window.isAccountArrears) {
            return qsTr("Your account is in arrears and related services will be suspended soon. Please recharge in %1 as soon as possible to ensure business continuity.").arg(window.arrearsBillLinkText);
        }
        return "";
    }

    function showError(rawMessage, prefix) {
        var msg = rawMessage || "";
        var idx = msg.indexOf("due to ");
        if (idx !== -1) {
            msg = msg.substring(idx + 7).replace(/\.$/, "").trim();
        }
        if (!msg)
            msg = qsTr("Operation incomplete, please try again later");
        if (prefix)
            msg = prefix + ": " + msg;
        errorDialog.errorMessage = msg;
        if (errorDialog.opened) {
            errorTimer.restart();
        } else {
            errorDialog.open();
        }
    }
    readonly property string currentUserAvatar: {
        if (window.currentUser && window.currentUser.avatar) {
            return String(window.currentUser.avatar);
        }
        return "";
    }

    // Data manager for persistent storage
    property var dataManager: Theme.DataManager

    // Property to track data changes for UI refresh
    property int dataVersion: 0

    // 未读消息计数器：由 MessageCenter 通过信号驱动，不依赖本地 SQLite
    property int unreadMessageCount: 0

    // 当前在侧栏选中的安全域 pubKey 和 domainCode
    property string selectedDomainPubKey: ""
    property string selectedDomainCode: ""

    // ── 归档功能 (PRD 3.1) ────────────────────────────────────────────────────
    // 归档/恢复经由 DSCC-SDK 持久化（服务端 + 本地 DB），归档状态由 loadDomainList /
    // loadDomainSummary 返回的 isArchived 字段驱动。归档是与状态无关的视图划分：
    // 把安全域在侧栏主列表与“归档”子列表之间移动，不改变安全域的任何状态。
    function showArchiveToast(message) {
        archiveToastLabel.text = message;
        if (archiveToast.opened)
            archiveToastTimer.restart();
        else
            archiveToast.open();
    }

    Component.onCompleted: {
        Qt.callLater(function () {
            // 进入登录页前检查版本。若已下载待安装的新版本，则只提醒安装，不再
            // 重复检查/下载；否则检查更新，需强制更新时由 forceUpdateDialog 弹出。
            if (UpdateManager.hasPendingInstall) {
                pendingInstallWarningDialog.open();
            } else {
                UpdateManager.checkUpdate(false);
            }
            if (dataManager && dataManager.currentUser !== undefined) {
                dataManager.currentUser = window.currentUser;
            }
            // authPage 初始值为 "login" 时 onAuthPageChanged 不会触发，手动启动登录流程
            if (window.authPage === "login") {
                window.startCasdoorLoginFlow();
                // 切换服务器后的重启带 --server-switched 标记，首次进入不再重复弹窗
                if (!AppConfig.startedAfterServerSwitch()) {
                    window.openServerSelectDialog();
                }
            }
        });
    }

    // Manual "Check for Updates" entry point, shared by the sidebar menu and
    // the About page button.
    function requestManualUpdateCheck() {
        if (UpdateManager.hasPendingInstall) {
            pendingInstallWarningDialog.open();
            return;
        }
        if (UpdateManager.isDownloading) {
            checkFailedDialog.text = qsTr("Update is downloading, please install later");
            checkFailedDialog.open();
            return;
        }
        UpdateManager.checkUpdate(true);
    }

    function startCasdoorLoginFlow() {
        if (window.authPage !== "login")
            return;
        if (casdoorLoginWebView && casdoorLoginWebView.startLogin) {
            casdoorLoginWebView.startLogin();
        }
    }

    // 登录前弹出"选择服务器"：按当前环境预选（测试环境视为自有服务器）
    function openServerSelectDialog() {
        serverSelectDialog.useOwnServer = AppConfig.isTestEnv();
        serverSelectDialog.open();
    }

    function switchToSecurityDomain(domainCode, pubKey, domainName) {
        if (securityDomainDetail) {
            securityDomainDetail.domainName = domainName || "";
            securityDomainDetail.domainPubKey = pubKey || "";
            securityDomainDetail.domainDetailLoading = false;
            securityDomainDetail.currentDomainCode = domainCode || "";
        }
        window.selectedDomainCode = domainCode || "";
        window.selectedDomainPubKey = pubKey || "";
        window.currentPage = "securityDomainDetail";
        return true;
    }

    function resetDsccUserState() {
        window.selectedDomainCode = "";
        window.selectedDomainPubKey = "";
        sidebar.domainList = [];
        sidebar.domainRefreshing = false;
        if (securityDomainDetail) {
            securityDomainDetail.currentDomainCode = "";
            securityDomainDetail.domainName = "";
            securityDomainDetail.domainPubKey = "";
            securityDomainDetail.domainDetailLoading = false;
        }
    }

    // Handle successful login
    function handleLoginSuccess(user) {
        casdoorRetryTimer.stop();      // stop any pending retry before switching to main page
        window.loginRetryCount = 0;
        window.showLoginError = false;
        window.loginErrorMessage = "";
        window.currentUser = user;
        if (dataManager) {
            dataManager.currentUser = user;
        }
        // 向 DSCC 业务层传递登录用户凭证
        DsccBridge.setCurrentUser(user.authUserId || "", user.userName || "", user.token || "", "");
        window.resetDsccUserState();
        DsccBridge.loadDomainList();
        // 登录后立即拉取未读消息数, 使红点在进入消息页之前即可显示
        messageCenter.fetchUnreadCount();
        window.authPage = "main";
        ArrearsManager.getArrearsOverview(user.token || "");
    }

    // Handle logout — starts async server-side logout, then transitions to login page
    function handleLogout() {
        if (window.logoutInProgress)
            return;
        casdoorRetryTimer.stop();
        window.loginRetryCount = 0;
        window.showLoginError = false;
        window.loginErrorMessage = "";
        window.logoutInProgress = true;
        if (customerServiceDialog.opened)
            customerServiceDialog.close();

        // Stop WebView timers/state but do NOT clear cookies yet —
        // CasdoorHelper needs casdoor_session_id for the server logout request.
        if (casdoorLoginWebView && casdoorLoginWebView.clearState) {
            casdoorLoginWebView.clearState();
        }

        // Trigger async logout: POST /api/logout with cached casdoor_session_id.
        // logoutCompleted / logoutFailed signals will call finishLogout().
        CasdoorHelper.logout();
    }

    function finishLogout() {
        window.logoutInProgress = false;
        DsccBridge.clearCurrentUser();
        window.resetDsccUserState();
        window.currentUser = null;
        if (dataManager) {
            dataManager.currentUser = null;
            dataManager.arrearsOverviewData = ({});
        }
        window.isAccountArrears = false;
        window.isAccountPaused = false;
        window.currentPage = "home";
        window.unreadMessageCount = 0;
        window.hasUpdateNotification = false;
        window.authPage = "login";     // triggers onAuthPageChanged → Qt.callLater(startCasdoorLoginFlow)
    }

    onAuthPageChanged: {
        if (window.authPage === "login") {
            Qt.callLater(function () {
                window.startCasdoorLoginFlow();
                window.openServerSelectDialog();
            });
        }
    }

    // 充值只能在浏览器里完成，而欠费状态客户端只在登录时查过一次，所以窗口重新拿到
    // 焦点时必须重查，否则充完钱横幅还一直挂着。只在横幅亮着时查，正常账户不会因为
    // 来回切窗口产生额外请求。
    onActiveChanged: {
        if (window.active && window.isLoggedIn && (window.isAccountArrears || window.isAccountPaused)) {
            ArrearsManager.getArrearsOverview(window.currentUser.token || "");
        }
    }

    Timer {
        id: casdoorRetryTimer
        interval: 800
        repeat: false
        onTriggered: {
            window.startCasdoorLoginFlow();
        }
    }

    // Connect to DataManager user signals
    Connections {
        target: dataManager
        function onUserLoggedOut() {
            handleLogout();
        }
    }

    Connections {
        target: CasdoorHelper

        function onLoginSuccess(user) {
            window.handleLoginSuccess(user);
        }

        function onLoginFailed(message) {
            if (window.authPage !== "login")
                return;
            window.loginRetryCount++;
            if (window.loginRetryCount < window.maxLoginRetries) {
                casdoorRetryTimer.restart();
            } else {
                window.loginErrorMessage = message || qsTr("Login failed, please check network and retry");
                window.showLoginError = true;
            }
        }

        function onLogoutCompleted() {
            if (window.logoutInProgress) {
                window.finishLogout();
            }
        }

        function onLogoutFailed(errorMessage) {
            console.warn("[main] Casdoor server logout failed:", errorMessage);
        // finishLogout is called by logoutCompleted which fires after logoutFailed
        }
    }

    Connections {
        target: ArrearsManager

        function onArrearsOverviewFetched(result) {
            window.dataManager.arrearsOverviewData = result;
            window.isAccountArrears = !!result.isArrears;
            window.isAccountPaused = !!result.isPaused;
            if (window.isAccountArrears || window.isAccountPaused) {
                if (!arrearsAlertPopup.opened)
                    arrearsAlertPopup.open();
            } else {
                if (arrearsAlertPopup.opened)
                    arrearsAlertPopup.close();
            }
        }

        function onArrearsOverviewFetchFailed(error) {
            // 查询失败保持现状，不清空：窗口重新激活时还会再查一次，而在这里清空会让一次
            // 网络抖动就把正在显示的欠费横幅抹掉。登录首次查询失败时状态本来就是 false，
            // 行为与之前一致。
            console.warn("[Arrears] overview fetch failed:", error);
        }
    }

    Connections {
        target: DsccBridge

        function onDomainCreated(operationId, domainCode) {
            createSecurityDomainForm.resetForm();
            window.switchToSecurityDomain(domainCode || "", "", "");
            if (securityDomainDetail)
                securityDomainDetail.showGuide();
            // 创建成功后刷新侧边栏列表
            DsccBridge.loadDomainList();
        }

        function onDomainListLoaded(domains) {
            sidebar.domainList = domains;
            sidebar.domainRefreshing = false;
        }

        function onDataSynced() {
            // 多端同步：后台同步已把最新服务器状态合并到本地缓存。侧边栏列表由
            // loadDomainList 自动刷新；若正打开某安全域详情，重载其概要/实例/审核。
            if (securityDomainDetail && window.selectedDomainCode)
                securityDomainDetail.reloadAllData();
        }

        function onDomainCreateFailed(operationId, notification) {
            createSecurityDomainForm.isSubmitting = false;
            var msg = DsccBridge.notificationMessage(notification, qsTr("Security domain creation failed"));
            window.showError(msg, qsTr("Security Domain Creation"));
            DsccBridge.loadDomainList();
        }

        function onCoreErrorOccurred(notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Database encryption initialization failed"));
            window.showError(msg, qsTr("Database Encryption"));
        }

        function onDomainClosed(operationId, domainCode) {
            // 安全域停用成功：保持在详情页，刷新侧边栏列表；若当前正打开该安全域，
            // 刷新其概要使详情页翻转为停用（只读）态。
            DsccBridge.loadDomainList();
            if (securityDomainDetail && domainCode === window.selectedDomainCode)
                DsccBridge.loadDomainSummary(domainCode);
        }

        function onDomainDeleted(operationId, domainCode) {
            // 安全域移除成功（PRD 3.2）：返回首页并刷新侧边栏列表
            if (securityDomainDetail) {
                securityDomainDetail.domainPubKey = "";
                securityDomainDetail.domainName = "";
                securityDomainDetail.currentDomainCode = "";
            }
            window.selectedDomainCode = "";
            window.selectedDomainPubKey = "";
            window.currentPage = "home";
            DsccBridge.loadDomainList();
        }

        function onDomainArchived(operationId, domainCode) {
            // 归档成功 (PRD 3.1)：刷新侧栏列表使其移入“归档”子列表；若当前正打开该安全域，
            // 刷新其概要使详情页按钮翻转为“恢复”。保持在详情页、不改变安全域状态。
            window.showArchiveToast(qsTr("Archived successfully"));
            DsccBridge.loadDomainList();
            if (securityDomainDetail && domainCode === window.selectedDomainCode)
                DsccBridge.loadDomainSummary(domainCode);
        }

        function onDomainArchiveFailed(operationId, domainCode, notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Failed to archive security domain"));
            window.showError(msg, qsTr("Archive Security Domain"));
        }

        function onDomainUnarchived(operationId, domainCode) {
            // 恢复成功 (PRD 3.1)：刷新侧栏列表使其移回主列表；若当前正打开该安全域，
            // 刷新其概要使详情页按钮翻转为“归档”。
            window.showArchiveToast(qsTr("Restored successfully"));
            DsccBridge.loadDomainList();
            if (securityDomainDetail && domainCode === window.selectedDomainCode)
                DsccBridge.loadDomainSummary(domainCode);
        }

        function onDomainUnarchiveFailed(operationId, domainCode, notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Failed to restore security domain"));
            window.showError(msg, qsTr("Restore Security Domain"));
        }

        function onMessageReadFailed(operationId, messageCode, notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Failed to mark message as read"));
            window.showError(msg, qsTr("Message"));
        }

        function onAllMessagesReadFailed(operationId, notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Failed to mark all messages as read"));
            window.showError(msg, qsTr("Message"));
        }

        function onMessageDeleteFailed(operationId, messageCode, notification) {
            var msg = DsccBridge.notificationMessage(notification, qsTr("Failed to delete message"));
            window.showError(msg, qsTr("Message"));
        }
    }

    function getInstanceStatusColor(status) {
        var style = Theme.Colors.getStatusColor(status || Theme.Colors.statusRunning);
        return style.dot || style.text;
    }

    // Casdoor Login Page
    CasdoorWebView {
        id: casdoorLoginWebView
        anchors.fill: parent
        visible: window.authPage === "login"
        z: 200

        // 登录页是原生 WebView 窗口，永远绘制在 QML 内容之上（z 不起作用），
        // 因此任何需要盖在登录页上的弹窗打开时，都要把网页内容移出可视区，
        // 否则弹窗会被完全遮住。此处只需列出登录阶段可能出现的弹窗：登录成功后
        // authPage 不再是 "login"，webContentOnScreen 已经为 false。
        // 新增登录前弹窗时，记得一并加到这里。
        webContentSuppressed: serverSelectDialog.visible || serverAddressDialog.visible || pendingInstallWarningDialog.visible || forceUpdateDialog.visible || errorDialog.visible || checkFailedDialog.visible || noUpdateDialog.visible

        onAuthCodeReceived: function (code, state) {
            CasdoorHelper.handleAuthCode(code, state);
        }

        onLoadError: function (errorMsg) {
            if (window.authPage !== "login")
                return;
            window.loginRetryCount++;
            if (window.loginRetryCount < window.maxLoginRetries) {
                casdoorRetryTimer.restart();
            } else {
                window.loginErrorMessage = qsTr("Cannot load login page, please check network connection");
                window.showLoginError = true;
            }
        }
    }

    // Login error overlay
    Rectangle {
        anchors.fill: parent
        visible: window.showLoginError && window.authPage === "login"
        z: 201
        color: Theme.Colors.backgroundSidebar

        Column {
            anchors.centerIn: parent
            spacing: 20
            width: 320

            Text {
                width: parent.width
                text: qsTr("Login Failed")
                font.pixelSize: Theme.Typography.h2
                font.weight: Font.Medium
                color: "#0f172a"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: window.loginErrorMessage || qsTr("Network error, please check network and retry")
                font.pixelSize: Theme.Typography.caption
                color: "#64748b"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }

            PrimaryButton {
                width: parent.width
                text: qsTr("Re-login")
                onClicked: {
                    window.showLoginError = false;
                    window.loginRetryCount = 0;
                    window.loginErrorMessage = "";
                    window.startCasdoorLoginFlow();
                }
            }
        }
    }

    // 登录前服务器选择（官方 / 自有服务器）。切换环境时持久化选择并重启应用，
    // 关闭弹窗（×/Esc/点击外部）则停留在当前环境继续登录。
    ServerSelectDialog {
        id: serverSelectDialog

        onConnectRequested: function (ownServer) {
            if (!ownServer) {
                AppConfig.selectServer("prod"); // 已是正式环境时为 no-op，直接继续登录
                return;
            }
            serverAddressDialog.address = AppConfig.isTestEnv() ? AppConfig.apiBaseUrl() : "";
            serverAddressDialog.open();
        }
    }

    ServerAddressDialog {
        id: serverAddressDialog

        onConfirmed: function (address) {
            var serverId = AppConfig.serverIdForBaseUrl(address);
            if (serverId === "") {
                serverAddressDialog.hasError = true;
                return;
            }
            serverAddressDialog.close();
            AppConfig.selectServer(serverId); // 与当前环境一致时为 no-op，直接继续登录
        }
    }

    // Main Application Content
    Row {
        anchors.fill: parent
        spacing: 0
        visible: window.authPage === "main"

        // Left Sidebar
        Sidebar {
            id: sidebar
            width: sidebarWidth
            height: parent.height
            currentUser: window.currentUser
            currentUserAvatar: window.currentUserAvatar
            selectedDomainCode: window.selectedDomainCode
            hasUpdateNotification: window.hasUpdateNotification
            unreadMessageCount: window.unreadMessageCount

            onCreateDomainRequested: window.currentPage = "createSecurityDomain"
            onDomainSelected: function (domainCode, pubKey, name) {
                window.switchToSecurityDomain(domainCode, pubKey, name);
            }
            onRefreshDomainsRequested: {
                sidebar.domainRefreshing = true;
                DsccBridge.loadDomainList();
                // 主动向服务器拉取一轮，纳入他端（如命令行）新建的安全域；
                // 拉取完成后经 DataSyncFinished 再次刷新列表。
                DsccBridge.refresh();
            }
            onPageRequested: function (page) {
                window.currentPage = page;
            }
            onLogoutRequested: dataManager.logoutUser()
            onCheckUpdateClicked: window.requestManualUpdateCheck()
            onMinimizeWindowRequested: window.showMinimized()
        }

        // Main Content Area
        Item {
            id: mainContentArea
            width: Math.min(mainContentMaxWidth, Math.max(mainContentMinWidth, window.width - sidebarWidth))
            height: parent.height
            property int contentTopOffset: arrearsAlertPopup.opened ? (arrearsAlertPopup.y + arrearsAlertPopup.height + 8) : 0

            // Default home page (empty or list view)
            Rectangle {
                id: homePage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                color: Theme.Colors.backgroundGray
                visible: window.currentPage === "home"

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Welcome to DataSafeBox Console")
                    font.pixelSize: Theme.Typography.h1
                    color: Theme.Colors.textSecondary
                }
            }

            // Create Security Domain Form
            SecurityDomainForm {
                id: createSecurityDomainForm
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "createSecurityDomain"
                currentUser: window.currentUser

                // Reset form when page becomes visible
                onVisibleChanged: {
                    if (visible) {
                        resetForm();
                    }
                }

                onCancel: {
                    window.currentPage = "home";
                }

                onSubmit: {
                    var formData = {
                        domainName: createSecurityDomainForm.domainName,
                        payer: createSecurityDomainForm.payer,
                        remarks: createSecurityDomainForm.description,
                        visibleUsers: createSecurityDomainForm.visibleUsers
                    };
                    DsccBridge.createDomain(formData);
                }
            }

            // Security Domain Detail Page
            SecurityDomainDetail {
                id: securityDomainDetail
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "securityDomainDetail"
                domainName: ""
                domainPubKey: ""
                dataVersion: window.dataVersion
                domainDetailLoading: false
                currentUser: window.currentUser  // Pass current user for permission check

                onInstantiateRequested: {
                    instantiationHelpDialog.open();
                }

                onContactSupportRequested: {
                    if (customerServiceDialog.opened)
                        customerServiceDialog.close();
                    else
                        customerServiceDialog.open();
                }

                onArchiveRequested: DsccBridge.archiveDomain(window.selectedDomainCode)

                onRestoreRequested: DsccBridge.unarchiveDomain(window.selectedDomainCode)

                onErrorOccurred: function (message, title) {
                    window.showError(message, title);
                }
            }

            // Instantiation Help Dialog
            InstantiationHelpDialog {
                id: instantiationHelpDialog
                parent: Overlay.overlay
                dim: false  // Dimming handled by instantiationHelpBackdrop so the sidebar stays interactive
                x: (Overlay.overlay ? (window.sidebarWidth + (Overlay.overlay.width - window.sidebarWidth - width) / 2) : 0)
                y: (Overlay.overlay ? (Overlay.overlay.height - height) / 2 : 0)
            }

            // Scoped dim backdrop for the instantiation help dialog: covers only the
            // main content area so the left sidebar stays bright and interactive.
            Rectangle {
                id: instantiationHelpBackdrop
                anchors.fill: parent
                z: 50
                color: Qt.rgba(0, 0, 0, 0.5)
                visible: instantiationHelpDialog.opened

                MouseArea {
                    anchors.fill: parent
                    onClicked: instantiationHelpDialog.close()
                }
            }

            // Instantiate Form Page
            InstantiateForm {
                id: instantiateForm
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "instantiateForm"
                domainName: ""
                domainPubKey: ""

                onCanceled: {
                    window.currentPage = "securityDomainDetail";
                }

                onSubmitted: function (name, duration, diskPartition, diskSizeMB, processes) {
                    // NOTE: 后端实例化（创建安全域实例）API 接入尚未完成，目前仅做前端跳转。
                    // 接入完成后，请在此处调用 NetworkManager 上报实例参数，
                    // 成功回调中再切换到 securityInstanceDetail 页面。
                    window.currentPage = "securityInstanceDetail";
                }
            }

            // Security Instance Detail Page
            SecurityInstanceDetail {
                id: securityInstanceDetail
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "securityInstanceDetail"
                instanceName: ""
                currentUser: window.currentUser

                onImportFileRequested: {
                    if (importFileDialog) {
                        importFileDialog.openForInstance("", "", "");
                    }
                }

                onExportFileRequested: function (filePaths, reasonText) {}

                onDeleteRequested: {
                    window.currentPage = "home";
                }

                onBackRequested: {
                    window.currentPage = "home";
                }
            }

            // Message Center page
            MessageCenter {
                id: messageCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "messageCenter"

                onBackRequested: {
                    window.currentPage = "home";
                }
            }

            // Settings page
            SettingsPage {
                id: settingsPage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "settings"
            }

            // About page
            AboutPage {
                id: aboutPage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "about"

                userAgreementUrl: "https://dianshudata.com/user-protocol"
                historyVersionUrl: "https://help.yeez.tech/docs/2026dsdox-client-update-history"

                onCheckUpdateRequested: window.requestManualUpdateCheck()
            }

            // Update-available dialog — centered within the main content area.
            UpdateDialog {
                id: updateDialog
                parent: mainContentArea
                dim: false  // Dimming is handled by updateDialogBackdrop so the sidebar stays bright
                // Only the post-login app shows the optional "new version" prompt; the
                // pre-login force variant is handled by forceUpdateDialog.
                autoOpenEnabled: window.authPage === "main"
                onContactCustomerServiceRequested: customerServiceDialog.open()
            }

            // Scoped dim backdrop for the update dialog: covers only the main content
            // area so the left sidebar stays bright and visible. A press here closes the
            // dialog (mirrors CloseOnPressOutside, which no longer fires with dim off).
            Rectangle {
                id: updateDialogBackdrop
                anchors.fill: parent
                z: 50
                color: Qt.rgba(0, 0, 0, 0.5)
                visible: updateDialog.opened

                MouseArea {
                    anchors.fill: parent
                    onClicked: updateDialog.close()
                }
            }

            // Scoped dim backdrop for the pending-install ("Software Update") dialog:
            // covers only the main content area so the left sidebar stays bright. A press
            // here closes the dialog (mirrors CloseOnPressOutside, off when dim is off).
            Rectangle {
                id: pendingInstallBackdrop
                anchors.fill: parent
                z: 50
                color: Qt.rgba(0, 0, 0, 0.5)
                visible: pendingInstallWarningDialog.opened

                MouseArea {
                    anchors.fill: parent
                    onClicked: pendingInstallWarningDialog.close()
                }
            }

            // 未读消息计数器驱动：监听 MessageCenter 的三种事件
            Connections {
                target: messageCenter
                // 打开消息页时服务端返回总未读数 → 直接设置
                function onUnreadCountFetched(count) {
                    window.unreadMessageCount = count;
                }
                // 点击单条未读消息 → 计数器减一
                function onUnreadMessageMarkedRead() {
                    if (window.unreadMessageCount > 0)
                        window.unreadMessageCount--;
                }
                // 一键已读 → 计数器清零
                function onAllMessagesMarkedRead() {
                    window.unreadMessageCount = 0;
                }
                function onDomainMessageClicked(domainCode) {
                    if (securityDomainDetail) {
                        securityDomainDetail.domainPubKey = domainCode || "";
                        securityDomainDetail.domainName = "";
                    }
                    window.currentPage = "securityDomainDetail";
                }
            }

            // Import File Dialog
            ImportFileDialog {
                id: importFileDialog
                anchors.centerIn: parent

                onImportStarted: function (filePath) {}

                onImportSuccess: function (filePath) {}

                onImportFailed: function (filePath, reason) {
                    window.showError(reason || qsTr("File import failed"), qsTr("File Import"));
                }
            }
        }
    }

    // 客服悬浮按钮：登录后显示在主窗口右下角
    Rectangle {
        id: customerServiceBtn
        visible: window.authPage === "main"
        width: 35
        height: 35
        radius: 17.5
        color: csiBtnArea.pressed ? Qt.darker(Theme.Colors.primary, 1.3) : (csiBtnArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary)
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        z: 100

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        // 悬停提示
        ToolTip.visible: csiBtnArea.containsMouse
        ToolTip.text: qsTr("Help")
        ToolTip.delay: 500

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: "qrc:/icons/icon-customer-service-white.svg"
            fillMode: Image.PreserveAspectFit
        }

        MouseArea {
            id: csiBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (customerServiceDialog.opened)
                    customerServiceDialog.close();
                else
                    customerServiceDialog.open();
            }
        }
    }

    // 客服聊天弹窗
    // 定位：浮动按钮正上方（底距50 + 按钮35 + 间隔8 = 93），右边对齐按钮右边
    CustomerServiceDialog {
        id: customerServiceDialog
        parent: Overlay.overlay
        x: parent.width - width - 15
        y: Math.max(8, parent.height - height - 93)
    }

    // Mandatory (force) update dialog. Parented to the overlay so it covers the
    // whole window — including the login WebView — when the backend requires a
    // force update. Per product decision, dismissing it exits the application.
    UpdateDialog {
        id: forceUpdateDialog
        parent: Overlay.overlay
        forceMode: true
        onContactCustomerServiceRequested: customerServiceDialog.open()
        onClosed: Qt.quit()
    }

    // 错误通知卡片（顶部滑入）
    Popup {
        id: errorDialog
        leftPadding: 14
        rightPadding: 14
        topPadding: 12
        bottomPadding: 12
        implicitWidth: Math.min(errorRow.implicitWidth + leftPadding + rightPadding, maxWidth)
        // 短提示仍是原来的单行高度，长提示按换行后的实际行数长高。
        implicitHeight: Math.max(46, errorRow.implicitHeight + topPadding + bottomPadding)
        x: parent ? sidebarWidth + (parent.width - sidebarWidth - width) / 2 : 0
        y: 24
        modal: false
        focus: false
        parent: Overlay.overlay

        property string errorMessage: ""

        // 提示条最宽只占到主内容区（不压侧边栏，两侧各留 24）。后端把接口路径和欠费
        // 原因整句带回来时，单行远放不下：以前文案宽度直接决定 implicitWidth，被这里
        // 的上限一夹就从右边裁掉，用户只能看到半句话。现在超出上限的部分换行。
        readonly property real maxWidth: parent ? Math.max(320, parent.width - sidebarWidth - 48) : 600
        // 文案可用宽度 = 卡片上限 - 左右内边距 - 图标(18) - 图标与文字的间距。
        readonly property real maxTextWidth: maxWidth - leftPadding - rightPadding - 18 - errorRow.spacing

        background: Rectangle {
            color: Theme.Colors.backgroundWhite
            radius: 8
            border.color: "#fecaca"
            border.width: 1

            ShadowBox {
                cornerRadius: 8
                shadowColor: "#14000000"
            }
        }

        contentItem: RowLayout {
            id: errorRow
            spacing: 10

            // 错误图标
            Image {
                source: "qrc:/icons/icon-error.svg"
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter
            }

            // 错误描述：放得下就单行，放不下按 maxTextWidth 换行。
            // 宽度取自 TextMetrics（单行排版宽度）而不是让布局去协商，避免
            // "宽度取决于高度、高度又取决于宽度" 的绑定回环。
            Label {
                id: errorLabel
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.min(Math.ceil(errorMetrics.advanceWidth) + 1, errorDialog.maxTextWidth)
                text: errorDialog.errorMessage
                // Wrap 而不是 WordWrap：报错里常有 /api/instanceApply/approve 这种
                // 不含空格的长串，WordWrap 断不开它，仍会溢出。
                wrapMode: Text.Wrap
                font.pixelSize: Theme.Typography.caption
                font.weight: Font.Medium
                color: Theme.Colors.textHeading

                TextMetrics {
                    id: errorMetrics
                    font: errorLabel.font
                    text: errorDialog.errorMessage
                }
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
            NumberAnimation {
                property: "y"
                from: 4
                to: 24
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 180
            }
            NumberAnimation {
                property: "y"
                from: 24
                to: 10
                duration: 180
                easing.type: Easing.InCubic
            }
        }

        Timer {
            id: errorTimer
            interval: 4000
            onTriggered: errorDialog.close()
        }

        onOpened: errorTimer.restart()
    }

    Popup {
        id: noUpdateDialog
        padding: 0
        width: Math.min(280, noUpdateLabel.implicitWidth + 80)
        height: 56
        x: sidebarWidth + (mainContentArea.width - width) / 2
        y: (parent.height - height) / 2
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: Theme.Colors.backgroundWhite
            radius: 28
            border.color: Theme.Colors.borderSeparator
            border.width: 1

            ShadowBox {
                cornerRadius: 28
                shadowColor: "#08000000"
            }
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 10

            Image {
                source: "qrc:/icons/icon-check-success.svg"
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                fillMode: Image.PreserveAspectFit
            }

            Label {
                id: noUpdateLabel
                text: qsTr("Already up to date")
                font.pixelSize: Theme.Typography.body
                font.weight: Font.Medium
                color: "#1e293b"
                Layout.fillWidth: true
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250
            }
            NumberAnimation {
                property: "y"
                from: 30
                to: 60
                duration: 400
                easing.type: Easing.OutBack
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250
            }
        }

        Timer {
            id: noUpdateTimer
            interval: 3000
            onTriggered: noUpdateDialog.close()
        }

        onOpened: noUpdateTimer.start()
    }

    // 归档/恢复成功提示 Toast (PRD 3.1.2.6)
    Popup {
        id: archiveToast
        padding: 0
        width: Math.min(280, archiveToastLabel.implicitWidth + 80)
        height: 56
        x: sidebarWidth + (mainContentArea.width - width) / 2
        y: (parent.height - height) / 2
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: Theme.Colors.backgroundWhite
            radius: 28
            border.color: Theme.Colors.borderSeparator
            border.width: 1

            ShadowBox {
                cornerRadius: 28
                shadowColor: "#08000000"
            }
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 10

            Image {
                source: "qrc:/icons/icon-check-success.svg"
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                fillMode: Image.PreserveAspectFit
            }

            Label {
                id: archiveToastLabel
                text: ""
                font.pixelSize: Theme.Typography.body
                font.weight: Font.Medium
                color: "#1e293b"
                Layout.fillWidth: true
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250
            }
            NumberAnimation {
                property: "y"
                from: 30
                to: 60
                duration: 400
                easing.type: Easing.OutBack
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250
            }
        }

        Timer {
            id: archiveToastTimer
            interval: 2000
            onTriggered: archiveToast.close()
        }

        onOpened: archiveToastTimer.restart()
    }

    Popup {
        id: checkFailedDialog
        padding: 0
        width: 320
        height: 60
        property alias text: msgLabel.text
        x: sidebarWidth + (mainContentArea.width - width) / 2
        y: 60
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: Theme.Colors.backgroundWhite
            radius: 30
            border.color: "#fee2e2"
            border.width: 1

            ShadowBox {
                cornerRadius: 30
                shadowColor: "#08000000"
            }
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12

            Image {
                source: "qrc:/icons/icon-warnning.svg"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                fillMode: Image.PreserveAspectFit
            }

            Label {
                id: msgLabel
                text: qsTr("Cannot connect to server")
                font.pixelSize: Theme.Typography.body
                font.weight: Font.Medium
                color: "#ef4444"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250
            }
            NumberAnimation {
                property: "y"
                from: 30
                to: 60
                duration: 400
                easing.type: Easing.OutBack
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250
            }
        }

        Timer {
            id: failedTimer
            interval: 4000
            onTriggered: checkFailedDialog.close()
        }

        onOpened: failedTimer.start()
    }

    BaseDialog {
        id: pendingInstallWarningDialog
        // Before login there is no sidebar, so center over the whole window via the
        // overlay; inside the app keep the About-page placement within the content area.
        readonly property bool preLogin: window.authPage === "login"
        // Set when the user chooses to install, so the install path isn't treated as a dismissal.
        property bool installRequested: false
        parent: preLogin ? Overlay.overlay : mainContentArea
        modal: preLogin
        dim: preLogin
        focus: true
        closePolicy: Popup.CloseOnEscape
        dialogWidth: 448
        title: qsTr("Software Update")

        onOpened: installRequested = false
        // Pre-login this is a mandatory prompt: dismissing it (×, Later, Esc) exits the app.
        onClosed: {
            if (preLogin && !installRequested)
                Qt.quit();
        }

        Column {
            width: parent.width
            spacing: 0

            Text {
                width: parent.width
                text: qsTr("New version downloaded. Install now?")
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textMenu
                wrapMode: Text.WordWrap
                lineHeight: 1.6
            }

            Item {
                width: parent.width
                height: 12
            }

            Text {
                width: parent.width
                text: qsTr("Version v") + UpdateManager.latestVersion
                font.pixelSize: Theme.Typography.caption
                color: Theme.Colors.textCaption
            }

            Item {
                width: parent.width
                height: 28
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                SecondaryButton {
                    text: qsTr("Later")
                    accent: true
                    onClicked: pendingInstallWarningDialog.close()
                }

                PrimaryButton {
                    text: qsTr("Install Now")
                    fontWeight: Font.Medium
                    onClicked: {
                        pendingInstallWarningDialog.installRequested = true;
                        pendingInstallWarningDialog.close();
                        UpdateManager.installUpdate();
                    }
                }
            }
        }
    }

    Connections {
        target: UpdateManager
        function onUpdateAvailable(version, desc, force) {
            window.hasUpdateNotification = true;
        }

        function onNoUpdateAvailable() {
            window.hasUpdateNotification = false;
            noUpdateLabel.text = qsTr("Already up to date");
            noUpdateDialog.open();
        }

        function onCheckUpdateFailed(message) {
            checkFailedDialog.text = message;
            checkFailedDialog.open();
        }

        function onPendingInstallReminder(filePath) {
            // The in-dialog update flow shows its own success screen; only fall back to
            // the standalone reminder when neither update dialog is driving the flow.
            if (!updateDialog.opened && !forceUpdateDialog.opened)
                pendingInstallWarningDialog.open();
        }
    }

    // 欠费提醒弹窗（账号暂停时点击创建安全域触发）
    PausedReminderDialog {
        id: createDomainPausedReminder
        dataManager: window.dataManager
        billUrl: window.arrearsBillUrl
    }

    // 欠费顶部悬浮提示（登录后如发现欠费/暂停则自动弹出）
    Popup {
        id: arrearsAlertPopup
        parent: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 0

        // 宽度跟随内容，居中悬浮于主内容区域；最宽不超过主内容区（两侧各留 24），
        // 超出部分由文案换行承担——中文文案单行放得下，英文同一句要长得多，
        // 没有上限时整条会顶出内容区被窗口边缘裁掉。
        readonly property real maxWidth: Math.max(320, mainContentArea.width - 48)
        // 文案可用宽度 = 卡片上限 - 内容左右留白(32) - 图标(20) - 图标与文字的间距(8)。
        readonly property real maxTextWidth: maxWidth - 32 - 20 - 8
        x: sidebarWidth + (mainContentArea.width - width) / 2
        y: 12

        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "#fca5a5"
            border.width: 1
        }

        contentItem: Item {
            implicitWidth: Math.min(arrearsAlertRow.implicitWidth + 32, arrearsAlertPopup.maxWidth)
            implicitHeight: arrearsAlertRow.implicitHeight + 20

            Row {
                id: arrearsAlertRow
                anchors.centerIn: parent
                spacing: 8

                // 描边圆形警告图标
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.color: "#b91c1c"
                    border.width: 1.5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        font.pixelSize: Theme.Typography.caption
                        font.weight: Font.Bold
                        color: "#b91c1c"
                    }
                }

                // 放得下就单行，放不下按 maxTextWidth 换行。宽度取自 TextMetrics
                // （单行排版宽度）而不是让 Row 去协商，避免宽高互相依赖。
                Text {
                    id: arrearsAlertText
                    anchors.verticalCenter: parent.verticalCenter
                    // +2 是排版余量：富文本里链接带下划线，实际排版可能比纯文本量出来的
                    // 宽半个像素，卡得太死会把最后一个字挤到第二行。
                    width: Math.min(Math.ceil(arrearsAlertMetrics.advanceWidth) + 2, arrearsAlertPopup.maxTextWidth)
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText
                    text: {
                        var raw = window.arrearsAlertMessage;
                        var linkText = window.arrearsBillLinkText;
                        return raw.replace(linkText, '<a href="wallet" style="color:#b91c1c;text-decoration:underline;">' + linkText + '</a>');
                    }
                    font.pixelSize: Theme.Typography.caption
                    color: "#b91c1c"
                    onLinkActivated: Qt.openUrlExternally(window.arrearsBillUrl)

                    // 只为了在链接上把光标换成手型。acceptedButtons: Qt.NoButton 让点击
                    // 继续落到 Text 上触发 onLinkActivated；hoverEnabled 保持默认的 false，
                    // 否则会截走 hover 事件，Text 的 hoveredLink 就一直是空。
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: arrearsAlertText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    // 量的是纯文案：带 <a> 标签的富文本串比渲染出来的宽得多，
                    // 拿它测宽会把上限判早，短提示也被迫换行。
                    TextMetrics {
                        id: arrearsAlertMetrics
                        font: arrearsAlertText.font
                        text: window.arrearsAlertMessage
                    }
                }
            }
        }
    }
}
