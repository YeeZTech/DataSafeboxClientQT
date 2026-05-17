import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as Theme

Item {
    id: root
    width: 778
    height: 1000
    
    // Instance name property - should be set from parent
    property string instanceName: ""
    // Current user - should be set from parent
    property var currentUser: null
    
    // Instance data - will be loaded from DataManager or use static data
    property var instanceData: _emptyInstanceData()
    readonly property bool isInstanceActive: instanceData && instanceData.status !== "已关闭"
    // Only "运行中" instances can import/export files
    readonly property bool canImportExportFiles: instanceData && instanceData.status === "运行中"
    // "已授权" 实例用于显示“实例化此安全域”按钮
    readonly property bool isAuthorizedInstance: instanceData && instanceData.status === "已授权"
    readonly property bool isPendingInstance: instanceData && instanceData.status === "待审核"
    readonly property bool showManagementPanels: !(isPendingInstance || isAuthorizedInstance)

    // Signals
    signal backRequested()
    signal importFileRequested()
    signal exportFileRequested(var filePaths, string reasonText)
    signal deleteRequested()
    signal instantiateRequested(string durationText)

    // Check expiration when component loads or becomes visible
    Component.onCompleted: {
        checkAndUpdateExpiration()
    }
    
    onVisibleChanged: {
        if (visible) {
            checkAndUpdateExpiration()
        }
    }
    
    function _emptyInstanceData() {
        return {
            id: "",
            name: instanceName || "",
            status: "",
            creator: "",
            path: "",
            createdAt: "",
            duration: ""
        }
    }

    function formatDurationLabel(durationText) {
        if (durationText === undefined || durationText === null) {
            return "-"
        }
        var text = durationText.toString().trim()
        if (!text.length) {
            return "-"
        }
        return text.indexOf("月") !== -1 ? text : text + "个月"
    }

    // Parse date/time string safely
    function parseDateTime(value) {
        if (!value) {
            return null
        }
        if (value instanceof Date) {
            return value
        }
        var parsed = null
        if (typeof value === "string") {
            var trimmed = value.trim()
            parsed = new Date(trimmed.replace(" ", "T"))
            if (isNaN(parsed.getTime())) {
                parsed = new Date(trimmed.replace(/-/g, "/"))
            }
        } else {
            parsed = new Date(value)
        }
        return isNaN(parsed.getTime()) ? null : parsed
    }

    // Calculate expiry date object based on creation time and duration (自然月)
    function calculateExpiryDateValue(createdAt, durationMonths) {
        if (!createdAt || !durationMonths) {
            return null
        }
        
        // Parse duration months
        var months = 0
        if (typeof durationMonths === "string") {
            var match = durationMonths.match(/(\d+)/)
            if (match) {
                months = parseInt(match[1])
            }
        } else {
            months = parseInt(durationMonths)
        }
        
        if (!months || months <= 0) {
            return null
        }
        
        var createdDate = parseDateTime(createdAt)
        if (!createdDate) {
            return null
        }
        
        // 按自然月计算到期时间，确保不出现2月30日等错误
        // 1月7日 + 1个月 = 2月7日（自然月）
        var expiryDate = new Date(createdDate.getTime())
        var targetMonth = expiryDate.getMonth() + months
        var yearsToAdd = Math.floor(targetMonth / 12)
        var newMonth = targetMonth % 12
        
        expiryDate.setFullYear(expiryDate.getFullYear() + yearsToAdd)
        
        // 处理月末溢出（如1月31日 + 1个月 = 2月28/29日）
        var originalDay = createdDate.getDate()
        expiryDate.setMonth(newMonth, 1) // 先设为目标月的1号
        
        // 获取目标月的最后一天
        var lastDayOfNewMonth = new Date(expiryDate.getFullYear(), newMonth + 1, 0).getDate()
        
        // 设为原日期或月末最后一天（取较小值）
        expiryDate.setDate(Math.min(originalDay, lastDayOfNewMonth))
        
        // 保留时间部分
        expiryDate.setHours(createdDate.getHours())
        expiryDate.setMinutes(createdDate.getMinutes())
        expiryDate.setSeconds(createdDate.getSeconds())
        
        return isNaN(expiryDate.getTime()) ? null : expiryDate
    }

    // Calculate expiry date string using natural months
    function calculateExpiryDate(createdAt, durationMonths) {
        var expiryDate = calculateExpiryDateValue(createdAt, durationMonths)
        if (!expiryDate) {
            return "-"
        }
        if (Theme.Utils && Theme.Utils.formatDateTime) {
            return Theme.Utils.formatDateTime(expiryDate)
        }
        function pad(num) {
            return num < 10 ? "0" + num : "" + num
        }
        return expiryDate.getFullYear() + "-" + pad(expiryDate.getMonth() + 1) + "-" + pad(expiryDate.getDate()) + " " + pad(expiryDate.getHours()) + ":" + pad(expiryDate.getMinutes()) + ":" + pad(expiryDate.getSeconds())
    }

    function displayExpiredTime(instance) {
        if (!instance) {
            return "-"
        }
        var status = instance.status || ""
        if (status === "待审核" || status === "已拒绝") {
            return "-"
        }
        // duration stores duration in months, calculate expiry date from createdAt (updated at approval)
        var durationMonths = instance.duration
        var startTime = instance.createdAt

        // Prefer persisted expiry time when available to keep UI consistent
        var expiryDate = null
        if (instance.expiresAt) {
            expiryDate = parseDateTime(instance.expiresAt)
        }
        if (!expiryDate) {
            expiryDate = calculateExpiryDateValue(startTime, durationMonths)
        }
        if (!expiryDate) {
            return "-"
        }
        if (Theme.Utils && Theme.Utils.formatDateTime) {
            return Theme.Utils.formatDateTime(expiryDate)
        }
        function pad(num) { return num < 10 ? "0" + num : "" + num }
        return expiryDate.getFullYear() + "-" + pad(expiryDate.getMonth() + 1) + "-" + pad(expiryDate.getDate()) + " " + pad(expiryDate.getHours()) + ":" + pad(expiryDate.getMinutes()) + ":" + pad(expiryDate.getSeconds())
    }

    // Check if instance has expired and update status if needed
    function checkAndUpdateExpiration() {
        var instance = root.instanceData
        if (!instance || !instance.id) {
            return
        }
        
        // Only check running instances
        if (instance.status !== "运行中") {
            return
        }
        
        if (!instance.createdAt && !instance.expiresAt) {
            return
        }
        var expiryDate = null
        if (instance.expiresAt) {
            expiryDate = parseDateTime(instance.expiresAt)
        }
        if (!expiryDate) {
            expiryDate = calculateExpiryDateValue(instance.createdAt, instance.duration)
        }
        if (!expiryDate) {
            return
        }

        var now = new Date()
        
        if (now > expiryDate) {
            root.instanceData = _emptyInstanceData()
        }
    }

    function applyPaymentSuccess(durationText) {
        var currentInstance = root.instanceData
        if (!currentInstance || !currentInstance.id) {
            return
        }

        root.instanceData = root._emptyInstanceData()
    }
    
    // Update instanceData when instanceName changes
    onInstanceNameChanged: {
        instanceData = _emptyInstanceData()
    }

    // 根据实例大小（MB）、实例时长（月）和计费规则（如“30元/GB/月”）计算预计费用
    function calculateEstimatedFee(sizeValue, durationText, billingRule) {
        // 解析月份
        var months = 0
        if (durationText && typeof durationText === "string") {
            var m = durationText.match(/(\d+)/)
            if (m) {
                months = parseInt(m[1])
            }
        } else if (durationText) {
            months = parseInt(durationText)
        }

        if (!months || months <= 0)
            return "0.00"

        // 解析容量（以 MB 为单位）
        var sizeMB = 0
        if (!sizeValue && sizeValue !== 0) {
            return "0.00"
        }
        if (typeof sizeValue === "string") {
            var match = sizeValue.match(/^(\d+)/)
            if (match) {
                sizeMB = parseInt(match[1])
            } else {
                return "0.00"
            }
        } else {
            sizeMB = parseInt(sizeValue)
        }

        if (isNaN(sizeMB) || sizeMB <= 0)
            return "0.00"

        // 转成 GB
        var sizeGB = sizeMB / 1024.0

        // 从计费规则字符串中提取单价（元/GB/月）
        var pricePerGBPerMonth = 0
        if (billingRule && typeof billingRule === "string") {
            var pm = billingRule.match(/(\d+(\.\d+)?)/)
            if (pm) {
                pricePerGBPerMonth = parseFloat(pm[1])
            }
        }

        if (!pricePerGBPerMonth || pricePerGBPerMonth <= 0)
            return "0.00"

        var fee = sizeGB * months * pricePerGBPerMonth
        if (!isFinite(fee) || fee < 0)
            return "0.00"

        return fee.toFixed(2)
    }
    
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentArea.height + 64
        
        background: Rectangle {
            color: "#e8edf3"  // 与安全域详情界面相同的灰色背景
        }
        
        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }
        
        Item {
            id: contentArea
            width: 778
            height: 970
            
            // Header section with title and import button
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: parent.top
                anchors.topMargin: 32
                width: 778
                height: 36
                
                // Title
                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: instanceData.name || "安全域实例"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    color: "#0f172b"
                }
                
                // Import File Button（仅运行中实例显示）
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 112
                    height: 36
                    radius: 8
                    property bool hovered: false
                    color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                    Behavior on color { ColorAnimation { duration: 120 } }
                    visible: root.canImportExportFiles

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            source: "icons/icon-import-file.svg"
                            width: 16
                            height: 16
                        }

                        Text {
                            text: "导入文件"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.primaryText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: root.importFileRequested()
                    }
                }

                // 实例化此安全域 按钮（仅已授权实例显示，使用蓝色背景、白色文字和图标）
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: startInstanceRow.width + 26   // 动态宽度
                    height: 36
                    radius: 8
                    property bool hovered: false
                    color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary  // 蓝色背景
                    border.color: Theme.Colors.primary    // 同色描边
                    border.width: 1
                    visible: root.isAuthorizedInstance

                    Row {
                        id: startInstanceRow
                        anchors.left: parent.left
                        anchors.leftMargin: 13   // 与安全域详情页按钮的 leftMargin 保持一致
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // 图标（使用白色版本 icon-domain-instance-white.svg，略微缩小以与安全域页面视觉一致）
                        Image {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("icons/icon-domain-instance-white.svg")
                            fillMode: Image.PreserveAspectFit
                        }

                        // 文案
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "加密文件至此安全域"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.primaryText   // 白色文字
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // 直接打开付款确认弹窗，使用创建实例时设置的时长（存储在 duration 中）
                            var durationText = instanceData.duration ? instanceData.duration.toString() : "1"
                            
                            instantiationPaymentDialog.durationText = durationText
                            
                            // 显示用的实例大小（人类可读）
                            var rawSize = instanceData.volumnSize || instanceData.size
                            var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(rawSize)
                            instantiationPaymentDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes)
                            
                            // 显示的实例时长文案
                            instantiationPaymentDialog.instanceFee = (durationText && durationText.length > 0 ? (durationText + "个月") : "-")
                            
                            // 当前计费规则
                            instantiationPaymentDialog.billingRule = "30元/GB/月"
                            
                            // 计算预计费用
                            instantiationPaymentDialog.estimatedFee = calculateEstimatedFee(rawSize, durationText, instantiationPaymentDialog.billingRule)
                            
                            instantiationPaymentDialog.open()
                        }
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                    }
                }
            }
            Rectangle {
                id: basicInfoCard
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: parent.top
                anchors.topMargin: 92
                width: 778
                height: 314
                color: "white"
                border.color: "#e2e8f0"  // border-slate-200
                border.width: 1
                radius: 14
                
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 25
                    anchors.topMargin: 25
                    anchors.rightMargin: 1
                    anchors.bottomMargin: 25
                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "实例ID"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        SelectableText {
                            text: instanceData.id || "-"
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 451
                        anchors.top: parent.top
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "状态"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        Rectangle {
                            width: 54
                            height: 22
                            radius: 8
                            property var statusBadgeStyle: Theme.Colors.getStatusColor(instanceData.status || "运行中")
                            color: statusBadgeStyle.bg
                            border.color: statusBadgeStyle.border
                            border.width: 1
                            
                            Text {
                                anchors.centerIn: parent
                                text: instanceData.status || "运行中"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: parent.statusBadgeStyle.text
                            }
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 72
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "名称"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        SelectableText {
                            text: instanceData.name || "-"
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 451
                        anchors.top: parent.top
                        anchors.topMargin: 72
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "所属安全域"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        SelectableText {
                            text: "-"
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 144
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "路径"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        Row {
                            spacing: 4
                            
                            SelectableText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: instanceData.diskPartition || "-"
                                font.pixelSize: 16
                                color: "#0f4c81"
                            }
                            
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "icons/icon-directory.svg"
                                width: 12
                                height: 12
                            }
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 451
                        anchors.top: parent.top
                        anchors.topMargin: 144
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "创建时间"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        SelectableText {
                            text: instanceData.createdAt || "-"
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 216
                        width: 427
                        spacing: 4
                        
                        SelectableText {
                            text: "到期时间"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        SelectableText {
                            text: displayExpiredTime(instanceData)
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                }
            }
            
            // Authorized Instance Notification Card - shown only for authorized instances
            Rectangle {
                id: authorizedNotificationCard
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: basicInfoCard.bottom
                anchors.topMargin: 25  // Spacing between Basic Info Card and notification card
                width: 778
                height: isAuthorizedInstance ? 73 : 0  // Height based on content (24.651px padding top + 24px content + 24.651px padding bottom)
                visible: root.isAuthorizedInstance
                color: "#E6F7FF"  // bg-blue-50 equivalent
                border.color: "#BEDBFF"  // Light blue border
                border.width: 1
                radius: 14
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 25
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    
                    // Info icon
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("icons/icon-info.svg")
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    // Notification text
                    SelectableText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "此安全域实例化申请已被授权通过，请点击\"启动安全域\"按钮进行实例化操作。"
                        font.pixelSize: 16
                        font.weight: Font.Normal
                        color: "#314158"
                        wrapMode: Text.WordWrap
                        width: 574
                    }
                }
            }
            
            // Process Whitelist Card - dynamic height based on table rows
            Rectangle {
                id: whitelistCard
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: root.isAuthorizedInstance ? authorizedNotificationCard.bottom : basicInfoCard.bottom
                anchors.topMargin: root.showManagementPanels ? 25 : 0  // Spacing between Basic Info Card and Process Whitelist Card
                width: 778
                property int whitelistCount: instanceData.processWhitelist ? instanceData.processWhitelist.length : 0
                property bool hasWhitelist: whitelistCount > 0

                height: root.showManagementPanels ? (20 + 16 + (hasWhitelist ? whitelistTable.height : 24) + 48) : 0  // Title + spacing + (table or "无") + margins
                color: "white"
                border.color: "#e2e8f0"
                border.width: 1
                radius: 14
                visible: root.showManagementPanels
                
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.bottomMargin: 24
                    
                    SelectableText {
                        id: whitelistTitle
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "应用白名单"
                        font.pixelSize: 14
                        color: "#62748e"
                    }

                    Item {
                        id: whitelistEmptyState
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: whitelistTitle.bottom
                        anchors.topMargin: 16
                        height: 24
                        visible: !whitelistCard.hasWhitelist

                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: "#0f172b"
                        }
                    }
                    
                    Rectangle {
                        id: whitelistTable
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: whitelistTitle.bottom
                        anchors.topMargin: 16
                        height: whitelistCard.hasWhitelist ? (40 + whitelistCard.whitelistCount * 36) : 0  // Header (40) + rows (36 each)
                        radius: 10
                        border.color: "#1a000000"
                        border.width: 1
                        color: "white"
                        visible: whitelistCard.hasWhitelist
                        
                        // Inner Rectangle for clipping content while preserving border visibility
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: parent.radius - 1  // Slightly smaller radius for inner clipping
                            color: "transparent"
                            clip: true
                            
                            Item {
                                id: whitelistHeader
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 40
                                visible: whitelistCard.hasWhitelist
                                
                                Rectangle {
                                    anchors.left: parent.left
                                    width: 130
                                    height: parent.height
                                    color: "transparent"
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: "#1a000000"
                                    }
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "程序文件名称"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: "#0f172b"
                                    }
                                }
                                
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 130
                                    anchors.right: parent.right
                                    height: parent.height
                                    color: "transparent"
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: "#1a000000"
                                    }
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "程序路径"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: "#0f172b"
                                    }
                                }
                            }
                            
                            // Dynamic rows based on processWhitelist data
                            Repeater {
                                model: instanceData.processWhitelist || []
                                visible: whitelistCard.hasWhitelist
                                
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: whitelistHeader.bottom
                                    anchors.topMargin: index * 36
                                    height: 36
                                    color: "white"
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        width: 130
                                        height: parent.height
                                        color: "transparent"
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name || ""
                                            font.pixelSize: 14
                                            color: "#0f172b"
                                            width: parent.width - 16
                                            clip: true
                                        }
                                    }
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 130
                                        anchors.right: parent.right
                                        height: parent.height
                                        color: "transparent"
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.diskPartition || ""
                                            font.pixelSize: 14
                                            color: "#0f172b"
                                            width: parent.width - 16
                                            clip: true

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                                cursorShape: Qt.IBeamCursor
                                                
                                                ToolTip.delay: 500
                                                ToolTip.visible: containsMouse
                                                ToolTip.text: modelData.diskPartition || ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
            
            // File Export Application Card - positioned below Process Whitelist Card
            Rectangle {
                id: exportApplicationCard
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: whitelistCard.bottom
                anchors.topMargin: root.showManagementPanels ? 25 : 0  // Spacing between Process Whitelist and File Export Application cards
                width: 778
                property int exportRequestCount: instanceData.exportRequests ? instanceData.exportRequests.length : 0
                property bool hasExportRequests: exportRequestCount > 0
                height: root.showManagementPanels ? (24 + 36 + 16 + (hasExportRequests ? exportTable.height : 24) + 25) : 0  // Header + spacing + table or "无" + margins
                color: "white"
                border.color: "#e2e8f0"  // border-slate-200
                border.width: 1
                radius: 14
                visible: root.showManagementPanels
                
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.bottomMargin: 25
                    
                    Item {
                        id: exportHeader
                        width: parent.width
                        height: 36
                        
                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "文件导出申请"
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: exportFileRow.width + 24  // Dynamic width
                            height: 36
                            radius: 8
                            property bool hovered: false
                            color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                            visible: root.canImportExportFiles

                            Row {
                                id: exportFileRow
                                anchors.centerIn: parent
                                spacing: 8

                                Image {
                                    source: "icons/icon-export-file.svg"
                                    width: 16
                                    height: 16
                                }

                                Text {
                                    text: "导出文件"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: Theme.Colors.primaryText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    var exportBasePath = root.instanceData && root.instanceData.diskPartition ? root.instanceData.diskPartition : ""
                                    exportFileDialog.allowedDirectory = exportBasePath
                                    exportFileDialog.resetForm()
                                    exportFileDialog.open()
                                }
                            }
                        }
                    }

                    Item {
                        id: exportEmptyState
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: exportHeader.bottom
                        anchors.topMargin: 16
                        height: 24
                        visible: !exportApplicationCard.hasExportRequests

                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: "#0f172b"
                        }
                    }
                    
                    // Table
                    Rectangle {
                        id: exportTable
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: exportHeader.bottom
                        anchors.topMargin: 16
                        height: exportApplicationCard.hasExportRequests ? (40 + exportApplicationCard.exportRequestCount * 38) : 0  // Header (40) + rows (38 each)
                        border.color: "#1a000000"
                        border.width: 1
                        radius: 10
                        color: "white"
                        visible: exportApplicationCard.hasExportRequests
                        
                        // Inner Rectangle for clipping content while preserving border visibility
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: parent.radius - 1  // Slightly smaller radius for inner clipping
                            color: "transparent"
                            clip: true
                            
                            Item {
                                anchors.fill: parent
                                visible: exportApplicationCard.hasExportRequests
                                
                                // Table Header
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 40
                                    property bool hovered: false
                                    property real headerCornerRadius: Math.max(0, exportTable.radius - 1)
                                    color: hovered ? "#f2f7fd" : "transparent"
                                    radius: hovered ? headerCornerRadius : 0
                                    
                                    HoverHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onHoveredChanged: parent.hovered = hovered
                                    }

                                    // Maintain rounded top corners but keep bottom corners square
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: parent.headerCornerRadius
                                        color: parent.color
                                        visible: parent.hovered && parent.headerCornerRadius > 0
                                    }

                                    Row {
                                        anchors.fill: parent
                                        
                                        Rectangle {
                                        width: 160
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "申请编号"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 100
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "文件数量"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 100
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "总文件大小"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 100
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "状态"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 160
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "申请时间"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: parent.parent.width - 160 - 100 - 100 - 100 - 160
                                        height: parent.height
                                        color: "transparent"
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 1
                                            color: "#1a000000"
                                        }
                                        
                                        SelectableText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "操作"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: "#0f172b"
                                        }
                                    }
                                    }
                                }
                                
                                // Table Body - Use absolute positioning for rows
                                Repeater {
                                    id: exportRequestRepeater
                                    model: instanceData.exportRequests || []
                                    visible: exportApplicationCard.hasExportRequests
                                    
                                    Item {
                                        anchors.top: parent.top
                                        anchors.topMargin: 40 + index * 38  // 40 (header) + row index * 38
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 38
                                        property bool hovered: false
                                        property bool isLastRow: exportRequestRepeater.count > 0 && index === exportRequestRepeater.count - 1
                                        property real hoverCornerRadius: Math.max(0, exportTable.radius - 1)
                                        property bool showRoundedHover: hovered && isLastRow
                                        
                                        Rectangle {
                                            id: rowHoverBackground
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                top: parent.top
                                                bottom: parent.bottom
                                                bottomMargin: showRoundedHover ? 1 : 0
                                            }
                                            color: hovered ? "#f2f7fd" : "transparent"
                                            radius: showRoundedHover ? hoverCornerRadius : 0
                                            antialiasing: showRoundedHover
                                        }
                                        
                                        // Mask to keep the top edge square when rounding the bottom corners
                                        Rectangle {
                                            anchors.left: rowHoverBackground.left
                                            anchors.right: rowHoverBackground.right
                                            anchors.top: rowHoverBackground.top
                                            height: showRoundedHover ? rowHoverBackground.radius : 0
                                            color: rowHoverBackground.color
                                            visible: showRoundedHover && rowHoverBackground.radius > 0
                                        }
                                        
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: index < exportRequestRepeater.count - 1 ? 1 : 0
                                            color: "#1a000000"
                                            visible: index < exportRequestRepeater.count - 1
                                        }

                                        HoverHandler {
                                            acceptedDevices: PointerDevice.Mouse
                                            onHoveredChanged: parent.hovered = hovered
                                        }
                                    
                                        Row {
                                            anchors.fill: parent
                                            
                                            Rectangle {
                                                width: 160
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SelectableText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.id || "-"
                                                    font.pixelSize: 14
                                                    color: "#0f172b"
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SelectableText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.fileCount || "-"
                                                    font.pixelSize: 14
                                                    color: "#0f172b"
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SelectableText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: Theme.Utils.formatSize(modelData.fileSize)
                                                    font.pixelSize: 14
                                                    color: "#0f172b"
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 54
                                                    height: 22
                                                    radius: 8
                                                    property var auditStatusStyle: Theme.Colors.getStatusColor(modelData.status || "已授权")
                                                    color: auditStatusStyle.bg
                                                    border.color: auditStatusStyle.border
                                                    border.width: 1
                                                    
                                                    SelectableText {
                                                        anchors.centerIn: parent
                                                        text: modelData.status || "已授权"
                                                        font.pixelSize: 12
                                                        font.weight: Font.Medium
                                                        color: parent.auditStatusStyle.text
                                                    }
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 160
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SelectableText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.applyTime || "-"
                                                    font.pixelSize: 14
                                                    color: "#0f172b"
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: parent.parent.width - 160 - 100 - 100 - 100 - 160
                                                height: parent.height
                                                color: "transparent"
                                                property bool hovered: false
                                                
                                                SelectableText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "查看"
                                                    font.pixelSize: 14
                                                    color: "#0f4c81"
                                                    font.underline: parent.hovered
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onEntered: parent.hovered = true
                                                    onExited: parent.hovered = false
                                                    onClicked: {
                                                        exportDetailDialog.exportId = modelData.applyCode || ""
                                                        exportDetailDialog.applicant = modelData.applicant || root.instanceData.creator || "-"
                                                        exportDetailDialog.fileSize = Number(modelData.fileSize) || 0
                                                        exportDetailDialog.status = modelData.status || "待审核"
                                                        exportDetailDialog.applyTime = modelData.applyTime || ""
                                                        exportDetailDialog.instanceName = root.instanceData.name || ""
                                                        exportDetailDialog.files = modelData.files || []
                                                        exportDetailDialog.reason = modelData.reason || ""
                                                        exportDetailDialog.fileCode = modelData.fileCode || ""
                                                        exportDetailDialog.fileHash = modelData.fileHash || ""
                                                        exportDetailDialog.open()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Delete Button - positioned below File Export Application Card
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: exportApplicationCard.bottom
                anchors.topMargin: (root.isInstanceActive && root.showManagementPanels) ? 25 : 0  // Spacing between File Export Application Card and Delete Button
                width: 155
                height: (root.isInstanceActive && root.showManagementPanels) ? 36 : 0
                radius: 8
                property bool hovered: false
                color: hovered ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                visible: root.isInstanceActive && root.showManagementPanels

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: "icons/icon-delete.svg"
                        width: 16
                        height: 16
                    }

                    Text {
                        text: "删除安全域实例"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onClicked: {
                        deleteInstanceConfirmDialog.domainName = root.instanceData && root.instanceData.name ? root.instanceData.name : root.instanceName
                        deleteInstanceConfirmDialog.open()
                    }
                }
            }
        }
    }

    // 运行时长设置弹窗
    SetDurationDialog {
        id: setDurationDialog

        onConfirmClicked: function(durationText) {
            // 打开付款确认弹窗并传入展示数据
            instantiationPaymentDialog.durationText = durationText

            // 显示用的实例大小（人类可读）
            var rawSize = instanceData.volumnSize || instanceData.size
            var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(rawSize)
            instantiationPaymentDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes)

            // 显示的实例时长文案
            instantiationPaymentDialog.instanceFee = (durationText && durationText.length > 0 ? (durationText + "个月") : "-")

            // 当前计费规则（可根据实际配置调整）
            instantiationPaymentDialog.billingRule = "30元/GB/月"

            // 按照：实例大小(GB) × 实例时长(月) × 计费单价(元/GB/月) 计算预计费用
            instantiationPaymentDialog.estimatedFee = calculateEstimatedFee(rawSize, durationText, instantiationPaymentDialog.billingRule)

            instantiationPaymentDialog.open()
        }

        onCancelClicked: {
        }
    }

    // 实例化付款确认弹窗
    InstantiationPaymentDialog {
        id: instantiationPaymentDialog

        onConfirmClicked: function(durationText) {
            // 关闭付款确认弹窗
            instantiationPaymentDialog.close()
            // 打开支付成功弹窗
            paymentSuccessDialog.open()
            // 将运行时长回传给上层，由上层决定如何真正执行实例化/扣费
            root.instantiateRequested(durationText)
        }

        onCancelClicked: {
        }
    }

    // 支付成功弹窗
    PaymentSuccessDialog {
        id: paymentSuccessDialog

        onConfirmClicked: {
            var instanceName = root.instanceData && root.instanceData.name
                               ? root.instanceData.name
                               : root.instanceName
            var msg = "支付成功确认: 实例=" + instanceName
                      + ", 时长=" + (instantiationPaymentDialog.durationText || "-")
            SentryBridge.captureMessage(msg, 0)
            root.applyPaymentSuccess(instantiationPaymentDialog.durationText)
            instantiationPaymentDialog.durationText = ""
        }

        onCancelClicked: {
        }
    }

    // 删除实例确认弹窗（复用关闭安全域弹窗）
    DeactivateConfirmDialog {
        id: deleteInstanceConfirmDialog
        titleText: "删除安全域实例确认"
        questionPrefix: "确定要删除安全域实例"
        confirmButtonText: "确认删除"
        showDescription: false
        onConfirmClicked: {
            root.deleteRequested()
        }
    }

    // 导出文件弹窗
    ExportFileDialog {
        id: exportFileDialog

        onConfirmClicked: function(filePaths, reasonText) {
            root.exportFileRequested(filePaths, reasonText)
        }
    }

    // 导出文件详情弹窗
    ExportDetailDialog {
        id: exportDetailDialog
        isCreator: root.currentUser
                   && root.instanceData
                   && root.currentUser.userName === root.instanceData.creator
        allowApproveReject: false  // From SecurityInstanceDetail, always show close button

        onApproveClicked: {
        }

        onRejectClicked: {
        }

        onCancelClicked: {
        }
    }

}
