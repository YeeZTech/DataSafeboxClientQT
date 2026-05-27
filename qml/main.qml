import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import "." as Theme

ApplicationWindow {
    id: window
    readonly property int sidebarWidth: 208
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
    title: qsTr("Data SafeBox Console")
    color: "#f8fafc"  // slate-50 background

    // Authentication state
    property string authPage: "login"
    property var currentUser: null
    property bool isLoggedIn: currentUser !== null
    property bool logoutInProgress: false

    // State to control which page is shown (within main app)
    property string currentPage: "home"  // "home", "createSecurityDomain", "securityDomainDetail", "instantiateForm", or "securityInstanceDetail"

    property bool hasUpdateNotification: false
    property string settingsStatusText: ""
    property int loginRetryCount: 0
    property bool showLoginError: false
    property string loginErrorMessage: ""
    readonly property int maxLoginRetries: 3

    // Arrears / paused state
    property bool isAccountArrears: false
    property bool isAccountPaused: false
    readonly property string arrearsBillUrl: AppConfig ? AppConfig.apiBaseUrl().replace("api", "wallet") : "https://test-dsbox.dianshudata.com/wallet"
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

    Component.onCompleted: {
        Qt.callLater(function () {
            // 初始化时检查是否有可用更新
            if (UpdateManager && UpdateManager.checkForUpdates) {
                UpdateManager.checkForUpdates();
            }
            if (dataManager && dataManager.currentUser !== undefined) {
                dataManager.currentUser = window.currentUser;
            }
            // authPage 初始值为 "login" 时 onAuthPageChanged 不会触发，手动启动登录流程
            if (window.authPage === "login") {
                window.startCasdoorLoginFlow();
            }
        });
    }

    function startCasdoorLoginFlow() {
        if (window.authPage !== "login")
            return;
        if (casdoorLoginWebView && casdoorLoginWebView.startLogin) {
            casdoorLoginWebView.startLogin();
        }
    }

    function formatByteSize(bytes) {
        var value = Number(bytes || 0);
        if (value <= 0)
            return "0 B";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var idx = 0;
        while (value >= 1024 && idx < units.length - 1) {
            value = value / 1024;
            idx++;
        }
        if (idx === 0) {
            return Math.round(value) + " " + units[idx];
        }
        return value.toFixed(2) + " " + units[idx];
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
            });
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
            console.warn("[Arrears] overview fetch failed:", error);
            window.isAccountArrears = false;
            window.isAccountPaused = false;
            window.dataManager.arrearsOverviewData = ({});
            if (arrearsAlertPopup.opened)
                arrearsAlertPopup.close();
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
            // 安全域关闭成功：返回首页并刷新侧边栏列表
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

    // Back button to return to username/password login page (only shown on QR code page)
    Rectangle {
        id: backLoginBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        width: 28
        height: 28
        radius: 14
        color: backLoginArea.containsMouse ? "#f0f4f8" : "transparent"
        border.color: backLoginArea.containsMouse ? "#cad5e2" : "transparent"
        border.width: 1
        visible: window.authPage === "login" && !window.showLoginError && casdoorLoginWebView.canGoBack
        z: 202
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        Text {
            anchors.centerIn: parent
            text: "×"
            font.pixelSize: 20
            color: "#8a9bb0"
        }

        MouseArea {
            id: backLoginArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                casdoorLoginWebView.goBack();
            }
        }
    }

    // Login error overlay
    Rectangle {
        anchors.fill: parent
        visible: window.showLoginError && window.authPage === "login"
        z: 201
        color: "#f5f8fb"

        Column {
            anchors.centerIn: parent
            spacing: 20
            width: 320

            Text {
                width: parent.width
                text: qsTr("Login Failed")
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#0f172a"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: window.loginErrorMessage || qsTr("Network error, please check network and retry")
                font.pixelSize: 13
                color: "#64748b"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }

            Rectangle {
                width: parent.width
                height: 40
                radius: 6
                color: "#0f4c81"

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Re-login")
                    font.pixelSize: 14
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.showLoginError = false;
                        window.loginRetryCount = 0;
                        window.loginErrorMessage = "";
                        window.startCasdoorLoginFlow();
                    }
                }
            }
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
            }
            onPageRequested: function (page) {
                if (page === "settings") {
                    window.settingsStatusText = "";
                    if (PathManager && PathManager.refreshCacheSize)
                        PathManager.refreshCacheSize();
                }
                window.currentPage = page;
            }
            onLogoutRequested: dataManager.logoutUser()
            onCheckUpdateClicked: {
                if (UpdateManager.hasPendingInstall) {
                    pendingInstallWarningDialog.open();
                    return;
                }
                if (UpdateManager.isDownloading) {
                    checkFailedDialog.text = qsTr("Update is downloading, please install later");
                    checkFailedDialog.open();
                    return;
                }
                noUpdateLabel.text = qsTr("Current version: v") + UpdateManager.currentVersion;
                noUpdateDialog.open();
            }
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
                    font.pixelSize: 24
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
            }

            // Instantiation Help Dialog
            InstantiationHelpDialog {
                id: instantiationHelpDialog
                parent: Overlay.overlay
                x: (Overlay.overlay ? (window.sidebarWidth + (Overlay.overlay.width - window.sidebarWidth - width) / 2) : 0)
                y: (Overlay.overlay ? (Overlay.overlay.height - height) / 2 : 0)
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
            Item {
                id: settingsPage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: mainContentArea.contentTopOffset
                visible: window.currentPage === "settings"

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    Text {
                        text: qsTr("Settings")
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        color: "#303542"
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: qsTr("Default Cache Path:")
                            font.pixelSize: 16
                            color: "#7f8793"
                        }

                        Text {
                            width: parent.width - 130
                            text: PathManager && PathManager.cacheDir ? PathManager.cacheDir : ""
                            font.pixelSize: 16
                            color: "#687180"
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: qsTr("Change Path")
                            font.pixelSize: 16
                            color: settingsChangePathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsChangePathMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: settingsChangePathMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tempFolderDialog.open()
                            }
                        }

                        Text {
                            text: "|"
                            font.pixelSize: 16
                            color: "#c6ccd4"
                        }

                        Text {
                            text: qsTr("Open Path")
                            font.pixelSize: 16
                            color: settingsOpenPathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsOpenPathMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: settingsOpenPathMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (PathManager && PathManager.openTempDir) {
                                        var opened = PathManager.openTempDir();
                                        if (!opened) {
                                            window.settingsStatusText = qsTr("Failed to open directory, please check if path is accessible");
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "|"
                            font.pixelSize: 16
                            color: "#c6ccd4"
                        }

                        Text {
                            text: qsTr("Clear Cache")
                            font.pixelSize: 16
                            color: settingsClearCacheMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsClearCacheMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                id: settingsClearCacheMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (PathManager && PathManager.clearCache) {
                                        var cleaned = PathManager.clearCache();
                                        window.settingsStatusText = qsTr("Cache cleared:") + window.formatByteSize(cleaned);
                                    }
                                }
                            }
                        }

                        Text {
                            text: "(" + qsTr("approx.") + " " + window.formatByteSize(PathManager && PathManager.cacheSizeBytes ? PathManager.cacheSizeBytes : 0) + ")"
                            font.pixelSize: 16
                            color: "#8f96a1"
                        }
                    }

                    Text {
                        text: window.settingsStatusText
                        font.pixelSize: 14
                        color: "#3b4ed6"
                        visible: window.settingsStatusText.length > 0
                    }
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
        color: csiBtnArea.pressed ? Qt.darker("#0f4c81", 1.3) : (csiBtnArea.containsMouse ? Qt.lighter("#0f4c81", 1.2) : "#0f4c81")
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
            source: Qt.resolvedUrl("icons/icon-customer-service-white.svg")
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

    Platform.FolderDialog {
        id: tempFolderDialog
        title: qsTr("Select Cache Directory")
        onAccepted: {
            var selectedPath = "";
            if (tempFolderDialog.folder) {
                if (typeof tempFolderDialog.folder.toLocalFile === "function") {
                    selectedPath = tempFolderDialog.folder.toLocalFile();
                } else {
                    var rawUrl = tempFolderDialog.folder.toString();
                    if (rawUrl.indexOf("file:///") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(8));
                        if (Qt.platform.os === "windows" && selectedPath.length > 0 && selectedPath[0] === "/") {
                            selectedPath = selectedPath.substring(1);
                        }
                    } else if (rawUrl.indexOf("file://") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(7));
                    }
                }
            }
            if (selectedPath && PathManager && PathManager.setTempDir) {
                var ok = PathManager.setTempDir(selectedPath);
                window.settingsStatusText = ok ? qsTr("Cache directory updated, new tasks will use it immediately") : qsTr("Failed to set path, please check directory permissions");
            }
        }
    }

    UpdateDialog {
        id: updateDialog
    }

    // 错误通知卡片（顶部滑入）
    Popup {
        id: errorDialog
        leftPadding: 14
        rightPadding: 14
        topPadding: 0
        bottomPadding: 0
        implicitWidth: Math.min(errorRow.implicitWidth + leftPadding + rightPadding, parent ? parent.width - 48 : 600)
        implicitHeight: 46
        x: parent ? sidebarWidth + (parent.width - sidebarWidth - width) / 2 : 0
        y: 24
        modal: false
        focus: false
        parent: Overlay.overlay

        property string errorMessage: ""

        background: Rectangle {
            color: "#ffffff"
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

            // 单行错误描述
            Label {
                Layout.alignment: Qt.AlignVCenter
                text: errorDialog.errorMessage
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#0f172b"
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
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: "#ffffff"
            radius: 28
            border.color: "#e2e8f0"
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
                font.pixelSize: 14
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

    Popup {
        id: checkFailedDialog
        padding: 0
        width: 320
        height: 60
        property alias text: msgLabel.text
        x: (parent.width - width) / 2
        y: 60
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: "#ffffff"
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
                font.pixelSize: 14
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

    Dialog {
        id: pendingInstallWarningDialog
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 380
        height: 186

        background: Rectangle {
            color: "white"
            border.color: "#e2e8f0"
            border.width: 1
            radius: 12
        }

        padding: 0
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        contentItem: ColumnLayout {
            Layout.fillWidth: true
            anchors.margins: 20
            anchors.fill: parent
            spacing: 10

            Text {
                text: qsTr("Software Update")
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#0f172b"
            }

            Text {
                text: qsTr("New version downloaded. Install now?")
                font.pixelSize: 14
                color: "#334155"
                wrapMode: Text.WordWrap
                lineHeight: 1.25
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("Version v") + UpdateManager.latestVersion
                font.pixelSize: 12
                color: "#64748b"
                visible: UpdateManager.latestVersion !== ""
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.alignment: Qt.AlignBottom

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: laterMa.pressed ? Qt.darker("#f1f5f9", 1.08) : (laterMa.containsMouse ? Qt.lighter("#f1f5f9", 1.04) : "#f1f5f9")
                    border.color: laterMa.containsMouse ? "#cbd5e1" : "transparent"
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Later")
                        font.pixelSize: 14
                        color: "#62748e"
                    }

                    MouseArea {
                        id: laterMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pendingInstallWarningDialog.close();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: installMa.pressed ? Qt.darker("#0f4c81", 1.2) : (installMa.containsMouse ? Qt.lighter("#0f4c81", 1.08) : "#0f4c81")
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Install Now")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        id: installMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pendingInstallWarningDialog.close();
                            UpdateManager.installUpdate();
                        }
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
            noUpdateLabel.text = qsTr("Already up to date, current version is v") + UpdateManager.currentVersion;
            noUpdateDialog.open();
        }

        function onCheckUpdateFailed(message) {
            checkFailedDialog.text = message;
            checkFailedDialog.open();
        }

        function onPendingInstallReminder(filePath) {
            pendingInstallWarningDialog.open();
        }
    }

    // 欠费提醒弹窗（账号暂停时点击创建安全域触发）
    PausedReminderDialog {
        id: createDomainPausedReminder
        dataManager: window.dataManager
        billUrl: AppConfig ? AppConfig.apiBaseUrl().replace("api", "wallet") : "https://test-dsbox.dianshudata.com/wallet"
    }

    // 欠费顶部悬浮提示（登录后如发现欠费/暂停则自动弹出）
    Popup {
        id: arrearsAlertPopup
        parent: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 0

        // 宽度跟随内容，居中悬浮于主内容区域
        x: sidebarWidth + (mainContentArea.width - width) / 2
        y: 12

        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "#fca5a5"
            border.width: 1
        }

        contentItem: Item {
            implicitWidth: arrearsAlertRow.implicitWidth + 32
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
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#b91c1c"
                    }
                }

                Text {
                    id: arrearsAlertText
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.RichText
                    text: {
                        var raw = window.arrearsAlertMessage;
                        var linkText = window.arrearsBillLinkText;
                        return raw.replace(linkText, '<a href="wallet" style="color:#b91c1c;text-decoration:underline;">' + linkText + '</a>');
                    }
                    font.pixelSize: 13
                    color: "#b91c1c"
                    onLinkActivated: Qt.openUrlExternally(window.arrearsBillUrl)
                }
            }
        }
    }
}
