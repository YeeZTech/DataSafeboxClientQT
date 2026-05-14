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
    title: "数据安全柜"
    color: "#f8fafc"  // slate-50 background
    
    // Authentication state
    property string authPage: "login"
    property var currentUser: null
    property bool isLoggedIn: currentUser !== null
    
    // State to control which page is shown (within main app)
    property string currentPage: "home"  // "home", "createSecurityDomain", "securityDomainDetail", "instantiateForm", or "securityInstanceDetail"

    property bool hasUpdateNotification: false
    property string settingsStatusText: ""
    property int loginRetryCount: 0
    property bool showLoginError: false
    property string loginErrorMessage: ""
    readonly property int maxLoginRetries: 3

    // 欠费 / 暂停状态
    property bool isAccountArrears: false
    property bool isAccountPaused: false
    readonly property string arrearsBillUrl: AppConfig ? AppConfig.apiBaseUrl().replace("api", "wallet") : "https://test-dsbox.dianshudata.com/wallet"
    readonly property string arrearsAlertMessage: {
        if (window.isAccountPaused) { return "您的账号已暂停服务，相关功能不可用。为确保业务连续性，请尽快在 \"我的账单\" 中进行充值。" }
        if (window.isAccountArrears) { return "您的账号已欠费，相关服务即将暂停。为确保业务连续性，请尽快在 \"我的账单\" 中进行充值。" }
        return ""
    }

    // prefix: 可选场景前缀，如 "安全域创建"；会自动拼成 "安全域创建：<原因>"
    function showError(rawMessage, prefix) {
        var msg = rawMessage || ""
        // SDK 格式: "API /api/xxx resultCode is NNN, due to <用户可读原因>."
        var idx = msg.indexOf("due to ")
        if (idx !== -1) {
            msg = msg.substring(idx + 7).replace(/\.$/, "").trim()
        }
        if (!msg) msg = "操作未完成，请稍后重试"
        if (prefix) msg = prefix + "：" + msg
        errorDialog.errorMessage = msg
        if (errorDialog.opened) {
            errorTimer.restart()
        } else {
            errorDialog.open()
        }
    }
    readonly property string currentUserAvatar: {
        if (window.currentUser && window.currentUser.avatar) {
            return String(window.currentUser.avatar)
        }
        return ""
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
        Qt.callLater(function() {
            // 初始化时检查是否有可用更新
            if (UpdateManager && UpdateManager.checkForUpdates) {
                UpdateManager.checkForUpdates()
            }
            if (dataManager && dataManager.currentUser !== undefined) {
                dataManager.currentUser = window.currentUser
            }
            // authPage 初始值为 "login" 时 onAuthPageChanged 不会触发，手动启动登录流程
            if (window.authPage === "login") {
                window.startCasdoorLoginFlow()
            }
        })
    }

    function startCasdoorLoginFlow() {
        if (window.authPage !== "login") return
        if (casdoorLoginWebView && casdoorLoginWebView.startLogin) {
            casdoorLoginWebView.startLogin()
        }
    }

    function formatByteSize(bytes) {
        var value = Number(bytes || 0)
        if (value <= 0) return "0 B"
        var units = ["B", "KB", "MB", "GB", "TB"]
        var idx = 0
        while (value >= 1024 && idx < units.length - 1) {
            value = value / 1024
            idx++
        }
        if (idx === 0) {
            return Math.round(value) + " " + units[idx]
        }
        return value.toFixed(2) + " " + units[idx]
    }

    function switchToSecurityDomain(domainCode, pubKey, domainName) {
        if (securityDomainDetail) {
            securityDomainDetail.currentDomainCode = domainCode || ""
            securityDomainDetail.domainPubKey = pubKey || ""
            securityDomainDetail.domainName = domainName || ""
        }
        window.selectedDomainCode = domainCode || ""
        window.selectedDomainPubKey = pubKey || ""
        window.currentPage = "securityDomainDetail"
        window.dataVersion++
        return true
    }
    
    // Handle successful login
    function handleLoginSuccess(user) {
        casdoorRetryTimer.stop()      // stop any pending retry before switching to main page
        window.loginRetryCount = 0
        window.showLoginError = false
        window.loginErrorMessage = ""
        window.currentUser = user
        if (dataManager) {
            dataManager.currentUser = user
        }
        // 向 DSCC 业务层传递登录用户凭证
        DsccBridge.setCurrentUser(
            user.authUserId || "",
            user.userName   || "",
            user.token      || "",
            ""
        )
        DsccBridge.loadDomainList()
        window.authPage = "main"
        ArrearsManager.getArrearsOverview(user.token || "")
    }
    
    // Handle logout
    function handleLogout() {
        casdoorRetryTimer.stop()      // discard any pending login retry before clearing state
        window.loginRetryCount = 0
        window.showLoginError = false
        window.loginErrorMessage = ""

        if (customerServiceDialog.opened)
            customerServiceDialog.close()

        // Invalidate Casdoor server session (uses m_sessionToken to call /api/signout)
        CasdoorHelper.logout()

        if (casdoorLoginWebView && casdoorLoginWebView.clearState) {
            casdoorLoginWebView.clearState()
        }
        
        window.currentUser = null
        if (dataManager) {
            dataManager.currentUser = null
            dataManager.arrearsOverviewData = ({})
        }
        window.isAccountArrears = false
        window.isAccountPaused = false
        window.authPage = "login"     // triggers onAuthPageChanged → Qt.callLater(startCasdoorLoginFlow)
        window.currentPage = "home"
        window.unreadMessageCount = 0  // 退出登录时清零未读计数
        window.hasUpdateNotification = false

        // NOTE: startCasdoorLoginFlow() is triggered via onAuthPageChanged above — no extra Qt.callLater needed here.
    }

    onAuthPageChanged: {
        if (window.authPage === "login") {
            Qt.callLater(function() {
                window.startCasdoorLoginFlow()
            })
        }
    }

    Timer {
        id: casdoorRetryTimer
        interval: 800
        repeat: false
        onTriggered: {
            window.startCasdoorLoginFlow()
        }
    }
    
    // Connect to DataManager user signals
    Connections {
        target: dataManager
        function onUserLoggedOut() {
            handleLogout()
        }
    }

    Connections {
        target: CasdoorHelper

        function onLoginSuccess(user) {
            window.handleLoginSuccess(user)
        }

        function onLoginFailed(message) {
            if (window.authPage !== "login") return
            window.loginRetryCount++
            if (window.loginRetryCount < window.maxLoginRetries) {
                casdoorRetryTimer.restart()
            } else {
                window.loginErrorMessage = message || "登录失败，请检查网络后重试"
                window.showLoginError = true
            }
        }
    }

    Connections {
        target: ArrearsManager

        function onArrearsOverviewFetched(result) {
            window.dataManager.arrearsOverviewData = result
            window.isAccountArrears = !!result.isArrears
            window.isAccountPaused = !!result.isPaused
            if (window.isAccountArrears || window.isAccountPaused) {
                if (!arrearsAlertPopup.opened) arrearsAlertPopup.open()
            } else {
                if (arrearsAlertPopup.opened) arrearsAlertPopup.close()
            }
        }

        function onArrearsOverviewFetchFailed(error) {
            console.warn("[Arrears] overview fetch failed:", error)
            window.isAccountArrears = false
            window.isAccountPaused = false
            window.dataManager.arrearsOverviewData = ({})
            if (arrearsAlertPopup.opened) arrearsAlertPopup.close()
        }
    }

    Connections {
        target: DsccBridge

        function onDomainCreated(operationId, domainCode, domainName) {
            createSecurityDomainForm.resetForm()
            if (securityDomainDetail) {
                securityDomainDetail.currentDomainCode = domainCode
                securityDomainDetail.domainName = domainName
                securityDomainDetail.domainPubKey = ""
                securityDomainDetail.domainDetailLoading = false
            }
            window.selectedDomainCode = domainCode || ""
            window.currentPage = "securityDomainDetail"
            if (securityDomainDetail) securityDomainDetail.showGuide()
            // 创建成功后刷新侧边栏列表
            DsccBridge.loadDomainList()
        }

        function onDomainListLoaded(domains) {
            securityDomainRepeater.model = domains
            domainRefreshAnim.running = false
        }

        function onDomainCreateFailed(operationId, errorMessage) {
            createSecurityDomainForm.isSubmitting = false
            window.showError(errorMessage || "安全域创建失败", "安全域创建")
        }

        function onDomainClosed(operationId, domainCode) {
            // 安全域关闭成功：返回首页并刷新侧边栏列表
            if (securityDomainDetail) {
                securityDomainDetail.domainPubKey = ""
                securityDomainDetail.domainName = ""
                securityDomainDetail.currentDomainCode = ""
            }
            window.selectedDomainCode = ""
            window.selectedDomainPubKey = ""
            window.currentPage = "home"
            DsccBridge.loadDomainList()
        }
    }

    function getInstanceStatusColor(status) {
        var style = Theme.Colors.getStatusColor(status || "运行中")
        return style.dot || style.text
    }

    // Casdoor Login Page
    CasdoorWebView {
        id: casdoorLoginWebView
        anchors.fill: parent
        visible: window.authPage === "login"
        z: 200

        onAuthCodeReceived: function(code, state) {
            CasdoorHelper.handleAuthCode(code, state)
        }

        onLoadError: function(errorMsg) {
            if (window.authPage !== "login") return
            window.loginRetryCount++
            if (window.loginRetryCount < window.maxLoginRetries) {
                casdoorRetryTimer.restart()
            } else {
                window.loginErrorMessage = "无法加载登录页，请检查网络连接"
                window.showLoginError = true
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
                text: "登录失败"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#0f172a"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: window.loginErrorMessage || "网络错误，请检查网络后重试"
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
                    text: "重新登录"
                    font.pixelSize: 14
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.showLoginError = false
                        window.loginRetryCount = 0
                        window.loginErrorMessage = ""
                        window.startCasdoorLoginFlow()
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
        Rectangle {
            width: sidebarWidth
            height: parent.height
            color: Theme.Colors.backgroundSidebar  // #f5f8fb
            border.color: Theme.Colors.borderSlate
            border.width: 1
            
            Item {
                id: sidebarContent
                anchors.fill: parent
                
                Item {
                    width: 175.342
                    height: 24
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    
                    Text {
                        id: companyNameText
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 0
                        text: AppConfig.vendorCompanyName()
                        font.pixelSize: 16
                        font.weight: Font.Bold  // Bold font, same as "安全域" and "安全域实例"
                        color: Theme.Colors.primary
                    }

                    MouseArea {
                        id: companyNameMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(AppConfig.vendorUrl())
                    }
                }
                
                Item {
                    width: parent.width
                    height: 36
                    anchors.top: parent.top
                    anchors.topMargin: 68
                    
                    Rectangle {
                        id: createButton
                        width: 183.341
                        height: 36
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: createButtonMouseArea.containsMouse
                            ? (createButtonMouseArea.pressed
                               ? Qt.darker(Theme.Colors.primary, 1.2)
                               : Qt.lighter(Theme.Colors.primary, 1.2))
                            : Theme.Colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "创建安全域"
                            font.pixelSize: 14
                            font.weight: Font.Normal
                            color: Theme.Colors.primaryText
                        }

                        MouseArea {
                            id: createButtonMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                window.currentPage = "createSecurityDomain"
                            }
                        }
                    }
                }
                
                // Navigation menu area
                Item {
                    id: navigationArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 116
                    anchors.bottom: userProfileSection.top
                    anchors.bottomMargin: 8
                    clip: true
                    
                    ScrollView {
                        id: navigationScrollView
                        anchors.fill: parent
                        // Keep content width aligned to viewport so text elide is calculated in visible width.
                        contentWidth: availableWidth
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            anchors.right: parent ? parent.right : undefined
                            anchors.top: parent ? parent.top : undefined
                            anchors.bottom: parent ? parent.bottom : undefined
                        }
                        
                        Column {
                            id: navContent
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            spacing: 8  // Space between sections

                        Item {
                            id: securityDomainSection
                            width: parent.width  // Full width of nav content
                            
                            property bool securityDomainExpanded: true  // Default expanded
                            
                            // Calculate height dynamically based on content
                            property int headerHeight: 36  // Header height
                            property int listTopMargin: 44  // Top margin for list container
                            property int itemHeight: 32  // Height of each list item
                            // Section height = max(header height, list container bottom)
                            // When expanded with items: max(36, 44 + items * 32)
                            // When expanded without items: 36 (same as header)
                            // When collapsed: 36 (header only)
                            height: {
                                if (!securityDomainExpanded) {
                                    return headerHeight
                                }
                                if (securityDomainRepeater.model && securityDomainRepeater.model.length > 0) {
                                    // List container bottom position
                                    var listBottom = listTopMargin + securityDomainRepeater.model.length * itemHeight
                                    // Section height is the maximum of header height and list bottom
                                    return Math.max(headerHeight, listBottom)
                                }
                                // Expanded but no items - just header height
                                return headerHeight
                            }
                            
                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            
                            Rectangle {
                                id: securityDomainHeader
                                width: parent.width
                                height: 36
                                anchors.left: parent.left
                                anchors.leftMargin: 0
                                radius: 4
                                property bool hovered: false
                                color: hovered ? "#eaf2fb" : "transparent"
                                
                                Row {
                                    spacing: 8
                                    height: parent.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 8
                                    Image {
                                        id: dropdownIcon1
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-dropdown.svg")
                                        fillMode: Image.PreserveAspectFit
                                        rotation: securityDomainSection.securityDomainExpanded ? 0 : -90
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: securityDomainHeader.hovered = true
                                            onExited: securityDomainHeader.hovered = false
                                            onClicked: {
                                                securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded
                                            }
                                        }
                                        
                                        Behavior on rotation {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                        

                                    }
                                    
                                    Image {
                                        id: securityDomainIcon
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-security-domain.svg")
                                        fillMode: Image.PreserveAspectFit
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: securityDomainHeader.hovered = true
                                            onExited: securityDomainHeader.hovered = false
                                            onClicked: {
                                                securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "安全域"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold  // Bold font
                                        color: Theme.Colors.primary
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: securityDomainHeader.hovered = true
                                            onExited: securityDomainHeader.hovered = false
                                            onClicked: {
                                                securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded
                                            }
                                        }
                                    }

                                    // 刷新按钮 — 放在“安全域”右侧，避免窄侧栏被裁剪
                                    Rectangle {
                                        id: domainRefreshBtn
                                        width: 24
                                        height: 24
                                        radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: domainRefreshArea.containsMouse ? "#dce6f0" : "transparent"

                                        Image {
                                            id: domainRefreshIcon
                                            width: 16
                                            height: 16
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("icons/icon-update-refresh.svg")
                                            fillMode: Image.PreserveAspectFit
                                            opacity: domainRefreshArea.containsMouse ? 1.0 : 0.85
                                        }

                                        RotationAnimator {
                                            id: domainRefreshAnim
                                            target: domainRefreshIcon
                                            from: 0; to: 360
                                            duration: 800
                                            loops: Animation.Infinite
                                            running: false
                                        }

                                        MouseArea {
                                            id: domainRefreshArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                domainRefreshAnim.running = true
                                                DsccBridge.loadDomainList()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Security Domain list items container - dynamic height
                            Item {
                                id: securityDomainListContainer
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.right: parent.right
                                anchors.rightMargin: 0
                                anchors.top: parent.top
                                anchors.topMargin: 36
                                
                                // Calculate height dynamically based on number of items
                                // Height is only for the list items themselves, topMargin (44px) handles spacing
                                height: securityDomainRepeater.model && securityDomainRepeater.model.length > 0 ? 
                                    (securityDomainRepeater.model.length * 32) : 0
                                visible: securityDomainSection.securityDomainExpanded
                                opacity: securityDomainSection.securityDomainExpanded ? 1 : 0
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                
                                Repeater {
                                    id: securityDomainRepeater
                                    model: []
                                    
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: index * 32  // Dynamic positioning: 32px per item
                                        anchors.left: parent.left
                                        // Align with "安全域" title and with security instance list
                                        anchors.leftMargin: 8  // same as securityInstanceRepeater items
                                        height: 32
                                        width: Math.max(0, parent.width - 8)
                                        radius: 4
                                        property bool hovered: false
                                        readonly property bool isSelected: (modelData.domainCode || "") === window.selectedDomainCode && window.selectedDomainCode !== ""
                                        color: isSelected ? "#c2d8ef"
                                                          : (hovered ? "#d6e8f5" : Qt.rgba(194/255, 216/255, 239/255, 0))
                                        border.color: "transparent"
                                        border.width: 0
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        
                                        // 状态点
                                        Rectangle {
                                            x: 8
                                            width: 8
                                            height: 8
                                            radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Theme.Colors.getStatusColor(modelData.status || "运行中").dot
                                        }

                                        // 域名称
                                        Text {
                                            id: domainNameText
                                            x: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            font.pixelSize: 14
                                            font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                            color: parent.isSelected ? Theme.Colors.primary : (parent.hovered ? "#1e3a5f" : "#45556c")
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            maximumLineCount: 1
                                            elide: Text.ElideMiddle
                                            width: Math.max(0, (pendingBadge.visible ? pendingBadge.x - 6 : parent.width - 8) - x)
                                            readonly property bool isOverflow: implicitWidth > width
                                            property bool showTooltip: domainItemMouseArea.containsMouse
                                                                       && domainNameText.isOverflow
                                                                       && domainItemMouseArea.mouseX >= domainNameText.x
                                                                       && domainItemMouseArea.mouseX <= (domainNameText.x + domainNameText.width)

                                            Popup {
                                                id: domainNameTooltip
                                                parent: Overlay.overlay
                                                modal: false
                                                focus: false
                                                closePolicy: Popup.NoAutoClose
                                                padding: 0
                                                visible: domainNameText.showTooltip
                                                z: 99999

                                                readonly property real maxBubbleWidth: Overlay.overlay ? Math.max(160, Overlay.overlay.width - 16) : 400
                                                readonly property real bubbleWidth: Math.min(Math.max(domainNameTooltipText.implicitWidth + 16, 120), maxBubbleWidth)

                                                x: {
                                                    var p = domainNameText.mapToItem(Overlay.overlay, 0, 0)
                                                    var desired = p.x + (domainNameText.width - bubbleWidth) / 2
                                                    var minX = 8
                                                    var maxX = Overlay.overlay ? (Overlay.overlay.width - bubbleWidth - 8) : desired
                                                    return Math.max(minX, Math.min(desired, maxX))
                                                }
                                                y: {
                                                    var p = domainNameText.mapToItem(Overlay.overlay, 0, 0)
                                                    return p.y - bubbleBackground.height - 8
                                                }

                                                background: Item {
                                                    Rectangle {
                                                        id: bubbleBackground
                                                        width: domainNameTooltip.bubbleWidth
                                                        height: Math.max(28, domainNameTooltipText.implicitHeight + 10)
                                                        color: "#1e5a8e"
                                                        radius: 4

                                                        Text {
                                                            id: domainNameTooltipText
                                                            anchors.centerIn: parent
                                                            width: Math.max(0, parent.width - 16)
                                                            text: domainNameText.text
                                                            font.pixelSize: 13
                                                            color: "white"
                                                            wrapMode: Text.WrapAnywhere
                                                            horizontalAlignment: Text.AlignHCenter
                                                        }

                                                        Canvas {
                                                            width: 10
                                                            height: 5
                                                            anchors.top: parent.bottom
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            onPaint: {
                                                                var ctx = getContext("2d")
                                                                ctx.reset()
                                                                ctx.fillStyle = "#1e5a8e"
                                                                ctx.beginPath()
                                                                ctx.moveTo(0, 0)
                                                                ctx.lineTo(5, 5)
                                                                ctx.lineTo(10, 0)
                                                                ctx.closePath()
                                                                ctx.fill()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 未审核角标 — 脱离 Row 布局，直接锚定到名称右侧
                                        Rectangle {
                                            id: pendingBadge
                                            property int auditCount: 0
                                            visible: auditCount > 0
                                            // x=130 aligns left edge with message badge (message x:166, list-item offset:28, shift:-8)
                                            x: 130
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: auditCount > 99 ? 32 : (auditCount > 9 ? 24 : 16)
                                            height: 16
                                            radius: 8
                                            color: "#D4183D"
                                            z: 10
                                            Text {
                                                anchors.centerIn: parent
                                                color: "#fff"
                                                font.pixelSize: 11
                                                font.bold: true
                                                text: pendingBadge.auditCount > 99 ? "99+" : pendingBadge.auditCount.toString()
                                            }
                                        }

                                        MouseArea {
                                            id: domainItemMouseArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: parent.hovered = false
                                            onClicked: {
                                                window.switchToSecurityDomain(modelData.domainCode || "", modelData.pubKey || "", modelData.name || "")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Security Instance section container - dynamic height
                        Item {
                            id: securityInstanceSection
                            visible: false
                            width: parent.width  // Full width of nav content
                            
                            property bool securityInstanceExpanded: true  // Default expanded
                            
                            // Calculate height dynamically based on content
                            property int headerHeight: 36  // Header height
                            property int listTopMargin: 44  // Top margin for list container
                            property int itemHeight: 32  // Height of each list item
                            // Section height = max(header height, list container bottom)
                            // When expanded with items: max(36, 44 + items * 32)
                            // When expanded without items: 36 (same as header)
                            // When collapsed: 36 (header only)
                            height: {
                                if (!securityInstanceExpanded) {
                                    return headerHeight
                                }
                                if (securityInstanceRepeater.model && securityInstanceRepeater.model.length > 0) {
                                    // List container bottom position
                                    var listBottom = listTopMargin + securityInstanceRepeater.model.length * itemHeight
                                    // Section height is the maximum of header height and list bottom
                                    return Math.max(headerHeight, listBottom)
                                }
                                // Expanded but no items - just header height
                                return headerHeight
                            }
                            
                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            
                            Rectangle {
                                id: securityInstanceHeader
                                width: parent.width
                                height: 36
                                anchors.left: parent.left
                                anchors.leftMargin: 0
                                radius: 4
                                property bool hovered: false
                                color: hovered ? "#eaf2fb" : "transparent"
                                
                                Row {
                                    spacing: 8
                                    height: parent.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 8
                                    Image {
                                        id: dropdownIcon2
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-dropdown.svg")
                                        fillMode: Image.PreserveAspectFit
                                        rotation: securityInstanceSection.securityInstanceExpanded ? 0 : -90
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded
                                            }
                                        }
                                        
                                        Behavior on rotation {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                    }
                                    
                                    Image {
                                        id: securityInstanceIcon
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-security-instance.svg")
                                        fillMode: Image.PreserveAspectFit
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: securityInstanceHeader.hovered = true
                                            onExited: securityInstanceHeader.hovered = false
                                            onClicked: {
                                                securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "安全域实例"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold  // Bold font
                                        color: Theme.Colors.primary
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: securityInstanceHeader.hovered = true
                                            onExited: securityInstanceHeader.hovered = false
                                            onClicked: {
                                                securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Security Instance list items container - dynamic height
                            Item {
                                id: securityInstanceListContainer
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.right: parent.right
                                anchors.rightMargin: 0
                                anchors.top: parent.top
                                anchors.topMargin: 36
                                
                                // Calculate height dynamically based on number of items
                                // Height is only for the list items themselves, topMargin (44px) handles spacing
                                height: securityInstanceRepeater.model && securityInstanceRepeater.model.length > 0 ? 
                                    (securityInstanceRepeater.model.length * 32) : 0
                                visible: securityInstanceSection.securityInstanceExpanded
                                opacity: securityInstanceSection.securityInstanceExpanded ? 1 : 0
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                
                                Repeater {
                                    id: securityInstanceRepeater
                                    model: []
                                    
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: index * 32  // Dynamic positioning: 32px per item
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        height: 32
                                        width: Math.max(0, parent.width - 8)
                                        radius: 4
                                        property bool hovered: false
                                        readonly property bool isSelected: false
                                        color: isSelected ? "#c8d9e8"
                                                          : (hovered ? "#eaf2fb" : "transparent")

                                        Rectangle {
                                            x: 8
                                            width: 8
                                            height: 8
                                            radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.color
                                        }

                                        Text {
                                            id: securityInstanceNameText
                                            x: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            font.pixelSize: 14
                                            font.weight: Font.Normal
                                            color: "#45556c"
                                            maximumLineCount: 1
                                            elide: Text.ElideMiddle
                                            width: Math.max(0, parent.width - x - 8)
                                            readonly property bool isOverflow: implicitWidth > width
                                            property bool showTooltip: securityInstanceItemMouseArea.containsMouse
                                                                       && securityInstanceNameText.isOverflow
                                                                       && securityInstanceItemMouseArea.mouseX >= securityInstanceNameText.x
                                                                       && securityInstanceItemMouseArea.mouseX <= (securityInstanceNameText.x + securityInstanceNameText.width)

                                            Rectangle {
                                                visible: parent.showTooltip
                                                width: Math.min(instanceNameTooltipText.implicitWidth + 16, 400)
                                                height: 28
                                                color: "#1e5a8e"
                                                radius: 4
                                                z: 1000
                                                y: -height - 8
                                                x: -8

                                                Text {
                                                    id: instanceNameTooltipText
                                                    anchors.centerIn: parent
                                                    text: parent.parent.text
                                                    font.pixelSize: 13
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
                                                        var ctx = getContext("2d")
                                                        ctx.reset()
                                                        ctx.fillStyle = "#1e5a8e"
                                                        ctx.beginPath()
                                                        ctx.moveTo(0, 0)
                                                        ctx.lineTo(5, 5)
                                                        ctx.lineTo(10, 0)
                                                        ctx.closePath()
                                                        ctx.fill()
                                                    }
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: securityInstanceItemMouseArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: parent.hovered = false
                                            onClicked: {
                                                window.currentPage = "securityInstanceDetail"
                                            }
                                        }
                                    }
                                }

                        Item {
                            width: parent.width
                            height: 36
                        }
                            }
                        }
                        }

                    }
                }

                Item {
                    id: userProfileSection
                    width: parent.width
                    height: 56
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    
                    // Top border only
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.1)  // Light black border
                        visible: !userMenu.visible
                    }
                    
                    // User info row - hidden when menu is open
                    Row {
                        id: userProfileRow
                        visible: !userMenu.visible
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: "#d4e4f1"
                            clip: true
                            
                            // Remote avatar (if available)
                            Image {
                                id: sidebarUserAvatar
                                anchors.fill: parent
                                source: window.currentUserAvatar
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                visible: window.currentUserAvatar !== ""
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                fillMode: Image.PreserveAspectFit
                                visible: window.currentUserAvatar === "" || sidebarUserAvatar.status === Image.Error
                            }
                        }
                        
                        Text {
                            id: sidebarUserNameText
                            width: 111
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!window.currentUser) return ""
                                return window.currentUser.displayName || window.currentUser.userName || ""
                            }
                            font.pixelSize: 14
                            font.weight: Font.Normal
                            color: "#314158"
                            lineHeight: 20
                            lineHeightMode: Text.FixedHeight
                            maximumLineCount: 1
                            elide: Text.ElideMiddle
                            readonly property bool isOverflow: implicitWidth > width
                            property bool showTooltip: userProfileToggleArea.containsMouse
                                                       && sidebarUserNameText.isOverflow
                                                       && userProfileToggleArea.mouseX >= (userProfileRow.x + sidebarUserNameText.x)
                                                       && userProfileToggleArea.mouseX <= (userProfileRow.x + sidebarUserNameText.x + sidebarUserNameText.width)

                            Rectangle {
                                visible: parent.showTooltip
                                width: Math.min(sidebarUserNameTooltipText.implicitWidth + 16, 400)
                                height: 28
                                color: "#1e5a8e"
                                radius: 4
                                z: 1000
                                y: -height - 8
                                x: -8

                                Text {
                                    id: sidebarUserNameTooltipText
                                    anchors.centerIn: parent
                                    text: parent.parent.text
                                    font.pixelSize: 13
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
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.fillStyle = "#1e5a8e"
                                        ctx.beginPath()
                                        ctx.moveTo(0, 0)
                                        ctx.lineTo(5, 5)
                                        ctx.lineTo(10, 0)
                                        ctx.closePath()
                                        ctx.fill()
                                    }
                                }
                            }
                        }
                        
                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("icons/icon-dropdown-arrow.svg")
                            fillMode: Image.PreserveAspectFit
                            rotation: userMenu.visible ? 0 : 180
                            
                            Behavior on rotation {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    
                    // Badge as sibling of Row so x:161 is absolute within userProfileSection,
                    // aligning with expanded-state menu item badges (also at x:166 in same coord space)
                    BadgeIndicator {
                        visible: !userMenu.visible && count > 0
                        x: 161
                        anchors.verticalCenter: parent.verticalCenter
                        count: window.hasUpdateNotification ? 1 : window.unreadMessageCount
                    }
                    
                    // Clickable area - only when menu is closed
                    MouseArea {
                        id: userProfileToggleArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        visible: !userMenu.visible
                        onClicked: {
                            userMenu.visible = true
                        }
                    }
                    
                    // User menu popup - anchored to bottom of sidebar
                    Rectangle {
                        id: userMenu
                        visible: false
                        width: parent.width
                        height: userMenuContent.height
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: "white"
                        border.color: "#e2e8f0"
                        border.width: 1
                        
                        Column {
                            id: userMenuContent
                            width: parent.width
                            
                            // User info header button
                            Rectangle {
                                width: parent.width
                                height: 56
                                color: userHeaderMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                
                                Row {
                                    id: userMenuHeaderRow
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    // Avatar circle
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: "#D4E4F1"
                                        clip: true
                                        
                                        Image {
                                            id: userMenuHeaderAvatar
                                            anchors.fill: parent
                                            source: window.currentUserAvatar
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            visible: window.currentUserAvatar !== ""
                                        }
                                        
                                        Image {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                            fillMode: Image.PreserveAspectFit
                                            visible: window.currentUserAvatar === "" || userMenuHeaderAvatar.status === Image.Error
                                        }
                                    }
                                    
                                    // Username - flex-1
                                    Text {
                                        id: userMenuHeaderUserNameText
                                        width: parent.width - 32 - 16 - 36  // minus avatar, arrow, spacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (!window.currentUser) return ""
                                            return window.currentUser.displayName || window.currentUser.userName || ""
                                        }
                                        font.pixelSize: 14
                                        color: "#334155"  // text-slate-700
                                        maximumLineCount: 1
                                        elide: Text.ElideMiddle
                                        readonly property bool isOverflow: implicitWidth > width
                                        property bool showTooltip: userHeaderMouseArea.containsMouse
                                                                   && userMenuHeaderUserNameText.isOverflow
                                                                   && userHeaderMouseArea.mouseX >= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x)
                                                                   && userHeaderMouseArea.mouseX <= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x + userMenuHeaderUserNameText.width)

                                        Rectangle {
                                            visible: parent.showTooltip
                                            width: Math.min(userMenuHeaderNameTooltipText.implicitWidth + 16, 400)
                                            height: 28
                                            color: "#1e5a8e"
                                            radius: 4
                                            z: 1000
                                            y: -height - 8
                                            x: -8

                                            Text {
                                                id: userMenuHeaderNameTooltipText
                                                anchors.centerIn: parent
                                                text: parent.parent.text
                                                font.pixelSize: 13
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
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    ctx.fillStyle = "#1e5a8e"
                                                    ctx.beginPath()
                                                    ctx.moveTo(0, 0)
                                                    ctx.lineTo(5, 5)
                                                    ctx.lineTo(10, 0)
                                                    ctx.closePath()
                                                    ctx.fill()
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Chevron down icon when expanded
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-dropdown-arrow.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                                
                                MouseArea {
                                    id: userHeaderMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                    }
                                }
                            }
                            
                            // Separator
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#e2e8f0"
                            }
                            
                            // User info menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: userInfoMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    Image {
                                        id: userInfoMenuAvatar
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: window.currentUserAvatar !== "" ? window.currentUserAvatar : Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                        fillMode: Image.PreserveAspectFit
                                        clip: true
                                        onStatusChanged: {
                                            if (status === Image.Error && source !== Qt.resolvedUrl("icons/icon-user-avatar.svg")) {
                                                source = Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "用户信息"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: userInfoMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                        Qt.openUrlExternally(AppConfig.userCenterUrl())
                                        window.showMinimized()
                                    }
                                }
                            }

                            // Bill menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: billMenuArea.containsMouse ? "#E8F1F8" : "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12

                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-bill.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        text: "我的账单"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: billMenuArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                        Qt.openUrlExternally(AppConfig.walletUrl())
                                    }
                                }
                            }

                            // Messages menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: messagesMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-message.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: "消息"
                                            font.pixelSize: 14
                                            color: "#334155"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                BadgeIndicator {
                                    x: 166
                                    anchors.verticalCenter: parent.verticalCenter
                                    count: window.unreadMessageCount
                                }
                                
                                MouseArea {
                                    id: messagesMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.currentPage = "messageCenter"
                                    }
                                }
                            }
                            
                            // Settings menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: settingsMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-settings.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Text {
                                        text: "设置"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: settingsMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                        window.settingsStatusText = ""
                                        if (PathManager && PathManager.refreshCacheSize) {
                                            PathManager.refreshCacheSize()
                                        }
                                        window.currentPage = "settings"
                                    }
                                }
                            }
                            
                            // Bill menu item
                            // (moved above, now shown after 用户信息)

                            // Customer Service menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: customerServiceMenuArea.containsMouse ? "#E8F1F8" : "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12

                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-help.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        text: "帮助"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: customerServiceMenuArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                        Qt.openUrlExternally(AppConfig.helpDocsUrl())
                                    }
                                }
                            }

                            // Check Update menu item
                            Rectangle {
                                id: updateMenuItem
                                width: parent.width
                                height: 40
                                color: updateMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                opacity: UpdateManager.isChecking ? 0.75 : 1.0
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-update-refresh.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Text {
                                        text: UpdateManager.isChecking ? "检查中..." : "检查更新"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                BadgeIndicator {
                                    visible: window.hasUpdateNotification
                                    x: 166
                                    anchors.verticalCenter: parent.verticalCenter
                                    count: 1
                                }
                                
                                MouseArea {
                                    id: updateMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: UpdateManager.isChecking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (UpdateManager.isChecking) {
                                            checkFailedDialog.text = "正在检查更新，请稍候"
                                            checkFailedDialog.open()
                                            return
                                        }

                                        if (UpdateManager.hasPendingInstall) {
                                            userMenu.visible = false
                                            pendingInstallWarningDialog.open()
                                            return
                                        }

                                        if (UpdateManager.isDownloading) {
                                            checkFailedDialog.text = "更新正在下载中，请稍后安装"
                                            checkFailedDialog.open()
                                            return
                                        }

                                        userMenu.visible = false
                                        window.hasUpdateNotification = false
                                        UpdateManager.checkUpdate(true) // Manual check
                                    }
                                }
                            }
                            
                            // Separator before logout
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#e2e8f0"
                            }
                            
                            // Logout menu item
                            Rectangle {
                                width: parent.width
                                height: 40
                                color: logoutMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: Qt.resolvedUrl("icons/icon-logout.svg")
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Text {
                                        text: "退出登录"
                                        font.pixelSize: 14
                                        color: "#334155"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: logoutMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userMenu.visible = false
                                        dataManager.logoutUser()
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
                    text: "欢迎使用数据安全柜"
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
                        resetForm()
                    }
                }
        
                onCancel: {
                    window.currentPage = "home"
                }
                
                onSubmit: {
                    var formData = {
                        domainName:   createSecurityDomainForm.domainName,
                        payer:        createSecurityDomainForm.payer,
                        remarks:      createSecurityDomainForm.description,
                        visibleUsers: createSecurityDomainForm.visibleUsers
                    }
                    DsccBridge.createDomain(formData)
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
                    instantiationHelpDialog.open()
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
                    window.currentPage = "securityDomainDetail"
                }
                
                onSubmitted: function(name, duration, diskPartition, diskSizeMB, processes) {
                    // NOTE: 后端实例化（创建安全域实例）API 接入尚未完成，目前仅做前端跳转。
                    // 接入完成后，请在此处调用 NetworkManager 上报实例参数，
                    // 成功回调中再切换到 securityInstanceDetail 页面。
                    window.currentPage = "securityInstanceDetail"
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
                        importFileDialog.openForInstance("", "", "")
                    }
                }
                
                onExportFileRequested: function(filePaths, reasonText) {
                    // NOTE: 后端导出审批 API 接入尚未完成，ExportFileDialog 收集到的
                    // filePaths / reasonText 当前不会上报。接入完成后请在此处调用
                    // NetworkManager 提交导出申请，并根据回调反馈结果。
                }
                
                onDeleteRequested: {
                    window.currentPage = "home"
                }
                
                onBackRequested: {
                    window.currentPage = "home"
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
                    window.currentPage = "home"
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
                        text: "设置"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        color: "#303542"
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: "默认缓存路径："
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
                            text: "更改路径"
                            font.pixelSize: 16
                            color: settingsChangePathMouse.containsMouse ? "#4a59cf" : "#5b67d6"
                            MouseArea {
                                id: settingsChangePathMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tempFolderDialog.open()
                            }
                        }

                        Text { text: "|"; font.pixelSize: 16; color: "#c6ccd4" }

                        Text {
                            text: "打开路径"
                            font.pixelSize: 16
                            color: settingsOpenPathMouse.containsMouse ? "#4a59cf" : "#5b67d6"
                            MouseArea {
                                id: settingsOpenPathMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (PathManager && PathManager.openTempDir) {
                                        var opened = PathManager.openTempDir()
                                        if (!opened) {
                                            window.settingsStatusText = "打开目录失败，请检查路径是否可访问"
                                        }
                                    }
                                }
                            }
                        }

                        Text { text: "|"; font.pixelSize: 16; color: "#c6ccd4" }

                        Text {
                            text: "清除缓存"
                            font.pixelSize: 16
                            color: settingsClearCacheMouse.containsMouse ? "#4a59cf" : "#5b67d6"
                            MouseArea {
                                id: settingsClearCacheMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (PathManager && PathManager.clearCache) {
                                        var cleaned = PathManager.clearCache()
                                        window.settingsStatusText = "已清理缓存：" + window.formatByteSize(cleaned)
                                    }
                                }
                            }
                        }

                        Text {
                            text: "（约" + window.formatByteSize(PathManager && PathManager.cacheSizeBytes ? PathManager.cacheSizeBytes : 0) + "）"
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
                    window.unreadMessageCount = count
                }
                // 点击单条未读消息 → 计数器减一
                function onUnreadMessageMarkedRead() {
                    if (window.unreadMessageCount > 0)
                        window.unreadMessageCount--
                }
                // 一键已读 → 计数器清零
                function onAllMessagesMarkedRead() {
                    window.unreadMessageCount = 0
                }
                function onDomainMessageClicked(domainCode) {
                    if (securityDomainDetail) {
                        securityDomainDetail.domainPubKey = domainCode || ""
                        securityDomainDetail.domainName = ""
                    }
                    window.currentPage = "securityDomainDetail"
                }
            }
            
            // Import File Dialog
            ImportFileDialog {
                id: importFileDialog
                anchors.centerIn: parent
                
                onImportStarted: function(filePath) {
                }
                
                onImportSuccess: function(filePath) {
                }
                
                onImportFailed: function(filePath, reason) {
                    window.showError(reason || "文件导入失败", "文件导入")
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
        color: csiBtnArea.pressed
               ? Qt.darker("#0f4c81", 1.3)
               : (csiBtnArea.containsMouse ? Qt.lighter("#0f4c81", 1.2) : "#0f4c81")
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        z: 100

        Behavior on color { ColorAnimation { duration: 120 } }

        // 悬停提示
        ToolTip.visible: csiBtnArea.containsMouse
        ToolTip.text: "帮助"
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
                    customerServiceDialog.close()
                else
                    customerServiceDialog.open()
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
        title: "选择缓存目录"
        onAccepted: {
            var selectedPath = ""
            if (tempFolderDialog.folder) {
                if (typeof tempFolderDialog.folder.toLocalFile === "function") {
                    selectedPath = tempFolderDialog.folder.toLocalFile()
                } else {
                    var rawUrl = tempFolderDialog.folder.toString()
                    if (rawUrl.indexOf("file:///") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(8))
                        if (Qt.platform.os === "windows" && selectedPath.length > 0 && selectedPath[0] === "/") {
                            selectedPath = selectedPath.substring(1)
                        }
                    } else if (rawUrl.indexOf("file://") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(7))
                    }
                }
            }

            if (selectedPath && PathManager && PathManager.setTempDir) {
                var ok = PathManager.setTempDir(selectedPath)
                window.settingsStatusText = ok
                    ? "缓存目录已更新，新任务立即生效"
                    : "路径设置失败，请检查目录权限"
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
        implicitWidth: Math.min(errorRow.implicitWidth + leftPadding + rightPadding,
                                parent ? parent.width - 48 : 600)
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

            ShadowBox { cornerRadius: 8; shadowColor: "#14000000" }
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
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "y"; from: 4; to: 24; duration: 280; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 180 }
            NumberAnimation { property: "y"; from: 24; to: 10; duration: 180; easing.type: Easing.InCubic }
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
        y: 60
        modal: false
        focus: false
        parent: Overlay.overlay

        background: Rectangle {
            color: "#ffffff"
            radius: 28
            border.color: "#e2e8f0"
            border.width: 1

            ShadowBox { cornerRadius: 28; shadowColor: "#08000000" }
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
                text: "当前已是最新版本"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#1e293b"
                Layout.fillWidth: true
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
            NumberAnimation { property: "y"; from: 30; to: 60; duration: 400; easing.type: Easing.OutBack }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 250 }
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

            ShadowBox { cornerRadius: 30; shadowColor: "#08000000" }
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
                text: "无法连接到服务器"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#ef4444"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
            NumberAnimation { property: "y"; from: 30; to: 60; duration: 400; easing.type: Easing.OutBack }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 250 }
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
                text: "软件更新"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#0f172b"
            }
            
            Text {
                text: "新版本已下载完成，是否立即安装？"
                font.pixelSize: 14
                color: "#334155"
                wrapMode: Text.WordWrap
                lineHeight: 1.25
                Layout.fillWidth: true
            }

            Text {
                text: "版本 v" + UpdateManager.latestVersion
                font.pixelSize: 12
                color: "#64748b"
                visible: UpdateManager.latestVersion !== ""
            }

            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.alignment: Qt.AlignBottom
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: laterMa.pressed ? Qt.darker("#f1f5f9", 1.08)
                         : (laterMa.containsMouse ? Qt.lighter("#f1f5f9", 1.04) : "#f1f5f9")
                    border.color: laterMa.containsMouse ? "#cbd5e1" : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "以后再说"
                        font.pixelSize: 14
                        color: "#62748e"
                    }
                    
                    MouseArea {
                        id: laterMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pendingInstallWarningDialog.close()
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: installMa.pressed ? Qt.darker("#0f4c81", 1.2)
                         : (installMa.containsMouse ? Qt.lighter("#0f4c81", 1.08) : "#0f4c81")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "立即安装"
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
                            pendingInstallWarningDialog.close()
                            UpdateManager.installUpdate()
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: UpdateManager
        function onUpdateAvailable(version, desc, force) {
            window.hasUpdateNotification = true
        }

        function onNoUpdateAvailable() {
            window.hasUpdateNotification = false
            noUpdateLabel.text = "当前已是最新版本 v" + UpdateManager.currentVersion
            noUpdateDialog.open()
        }
        
        function onCheckUpdateFailed(message) {
            checkFailedDialog.text = message
            checkFailedDialog.open()
        }
        
        function onPendingInstallReminder(filePath) {
            pendingInstallWarningDialog.open()
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

                // 文字，含可点击的"我的钱包"
                Text {
                    id: arrearsAlertText
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.RichText
                    text: {
                        var raw = window.arrearsAlertMessage
                        return raw.replace('"我的账单"',
                            '<a href="wallet" style="color:#b91c1c;text-decoration:underline;">"我的账单"</a>')
                    }
                    font.pixelSize: 13
                    color: "#b91c1c"
                    onLinkActivated: Qt.openUrlExternally(window.arrearsBillUrl)
                }
            }
        }
    }
}
