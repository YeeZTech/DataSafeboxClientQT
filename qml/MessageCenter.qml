import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as Theme

Item {
    id: root
    width: 992
    height: 734

    // Properties
    property string currentFilter: "all"  // "all" or "unread"
    property int currentPage: 1
    property int pageSize: AppConfig.messageCenterPageSize()

    // Server-side pagination state
    property var serverMessages: []
    property int serverTotalPages: 0
    property bool serverLoading: false



    // 通知父级更新计数器的三个信号
    signal unreadCountFetched(int count)    // 服务端总未读数
    signal unreadMessageMarkedRead()        // 单条消息被标已读
    signal allMessagesMarkedRead()          // 一键已读
    signal domainMessageClicked(string domainCode)  // 点击未读消息后触发域同步与跳转

    function getVisiblePages() {
        var total = root.serverTotalPages
        var current = root.currentPage
        var pages = []
        if (total <= 7) {
            for (var i = 1; i <= total; i++) pages.push(i)
        } else {
            if (current <= 4) {
                for (var i = 1; i <= 5; i++) pages.push(i)
                pages.push(-1)
                pages.push(total)
            } else if (current >= total - 3) {
                pages.push(1)
                pages.push(-1)
                for (var i = total - 4; i <= total; i++) pages.push(i)
            } else {
                pages.push(1)
                pages.push(-1)
                for (var i = current - 1; i <= current + 1; i++) pages.push(i)
                pages.push(-1)
                pages.push(total)
            }
        }
        return pages
    }

    // Signals
    signal backRequested()

    // Functions
    function resolveMessageDomainCode(msg) {
        if (!msg) return ""

        var directCode = msg.domainCode || ""
        if (directCode) return String(directCode).trim()

        var extInfoRaw = (msg.extInfo !== undefined && msg.extInfo !== null) ? msg.extInfo : msg.ext_info
        if (extInfoRaw === undefined || extInfoRaw === null || extInfoRaw === "") {
            return ""
        }

        var extInfoObj = extInfoRaw
        if (typeof extInfoObj === "string") {
            try {
                extInfoObj = JSON.parse(extInfoObj)
            } catch (e) {
                extInfoObj = null
            }
        }

        if (!extInfoObj || typeof extInfoObj !== "object") {
            return ""
        }

        var nestedCode = extInfoObj.domainCode || ""
        if (!nestedCode && extInfoObj.domain && typeof extInfoObj.domain === "object") {
            nestedCode = extInfoObj.domain.domainCode || ""
        }
        if (!nestedCode && extInfoObj.data && typeof extInfoObj.data === "object") {
            nestedCode = extInfoObj.data.domainCode || ""
        }

        return nestedCode ? String(nestedCode).trim() : ""
    }

    // 离线回退模式（消息数据由动态库提供，本地无缓存）
    function _loadLocalMessages(pageNo) {
        serverMessages = []
        serverTotalPages = 1
        serverLoading = false
    }

    function fetchMessages(pageNo) {
        _loadLocalMessages(pageNo)
    }

    // 将 createTime 转换为可读格式（支持时间戳毫秒数和字符串两种格式）
    function formatCreateTime(val) {
        if (!val) return ""
        var ts = parseInt(val)
        if (!isNaN(ts) && ts > 1000000000000) {
            // 毫秒时间戳
            var d = new Date(ts)
            var year  = d.getFullYear()
            var month = ("0" + (d.getMonth() + 1)).slice(-2)
            var day   = ("0" + d.getDate()).slice(-2)
            return year + "-" + month + "-" + day
        }
        // 字符串格式（如 "2023-01-01 00:00:00.000"），只取日期部分
        return String(val).substring(0, 10)
    }

    function fetchUnreadCount() {
        root.unreadCountFetched(0)
        _loadLocalMessages(1)
    }

    function markAllAsRead() {
        root.allMessagesMarkedRead()  // 通知 window 计数器清零
        _loadLocalMessages(currentPage)
    }

    function deleteMessage(messageCode) {
        // 删前先查出 isRead 状态，若未读则通知计数器减一
        for (var j = 0; j < serverMessages.length; j++) {
            if (serverMessages[j].messageCode === messageCode) {
                if (serverMessages[j].isRead === 0) root.unreadMessageMarkedRead()
                break
            }
        }
        _loadLocalMessages(currentPage)
    }

    function markMessageAsRead(messageCode) {
        root.unreadMessageMarkedRead()  // 通知 window 计数器减一（调用方已确认 isRead===0）
        var upd0 = []
        for (var rj = 0; rj < serverMessages.length; rj++) {
            var mc0 = serverMessages[rj]
            if (mc0.messageCode === messageCode) {
                var cp0 = {}; for (var rk in mc0) { if (mc0.hasOwnProperty(rk)) cp0[rk] = mc0[rk] }
                cp0.isRead = 1; upd0.push(cp0)
            } else { upd0.push(mc0) }
        }
        serverMessages = upd0
    }

    // 消息中心变为可见时：先获取总未读数，再加载列表（顺序执行避免信号混淆）
    onVisibleChanged: {
        if (visible) {
            currentFilter = "all"
            currentPage = 1
            fetchUnreadCount()
        }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: Theme.Colors.backgroundWhite
    }

    // Header with title
    Item {
        id: header
        width: parent.width
        height: 64
        anchors.top: parent.top
        anchors.left: parent.left

        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#e6e6e6"
        }

        // Title
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Messages")
            font.pixelSize: 24
            font.weight: Font.Medium
            color: "#030213"
        }
    }

    // Filter tabs and Mark all read button
    Item {
        id: filterBar
        width: parent.width
        height: 37
        anchors.top: header.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 32

        // Filter tabs
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // "全部" tab
            Rectangle {
                id: allTab
                property bool hovered: false
                width: 60
                height: 32
                radius: 4
                color: (root.currentFilter === "all" || hovered) ? Theme.Colors.secondary : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: qsTr("All")
                    font.pixelSize: 14
                    font.weight: (root.currentFilter === "all") ? Font.DemiBold : Font.Normal
                    color: (root.currentFilter === "all" || parent.hovered) ? Theme.Colors.primary : Theme.Colors.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: allTab.hovered = true
                    onExited: allTab.hovered = false
                    onClicked: {
                        root.currentFilter = "all"
                        root.currentPage = 1
                        root.fetchMessages(1)
                    }
                }
            }

            // Divider
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "/"
                font.pixelSize: 16
                color: "#e6e6e6"
            }

            // "未读" tab
            Rectangle {
                id: unreadTab
                property bool hovered: false
                width: 60
                height: 32
                radius: 4
                color: (root.currentFilter === "unread" || hovered) ? Theme.Colors.secondary : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Unread")
                    font.pixelSize: 14
                    font.weight: (root.currentFilter === "unread") ? Font.DemiBold : Font.Normal
                    color: (root.currentFilter === "unread" || unreadTab.hovered) ? Theme.Colors.primary : Theme.Colors.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: unreadTab.hovered = true
                    onExited: unreadTab.hovered = false
                    onClicked: {
                        root.currentFilter = "unread"
                        root.currentPage = 1
                        root.fetchMessages(1)
                    }
                }
            }
        }

        // "一键已读" button
        Rectangle {
            id: markAllButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 113
            height: 37
            radius: 10
            color: hovered ? Theme.Colors.secondary : "transparent"
            border.width: 1
            border.color: Theme.Colors.primary
            property bool hovered: false

            Row {
                anchors.centerIn: parent
                spacing: 8

                Image {
                    width: 16
                    height: 16
                    source: Qt.resolvedUrl("icons/icon-check-double.svg")
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("Mark All Read")
                    font.pixelSize: 14
                    color: Theme.Colors.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: markAllButton.hovered = true
                onExited: markAllButton.hovered = false
                onClicked: root.markAllAsRead()
            }
        }
    }

    // Message list
    ScrollView {
        id: messageListView
        anchors.top: filterBar.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: pagination.top
        anchors.bottomMargin: 16
        clip: true

        Column {
            width: messageListView.width - 16
            spacing: 12

            Repeater {
                model: root.serverMessages

                // Message item
                Rectangle {
                    id: messageItem
                    width: parent.width
                    height: 79
                    radius: 10
                    property bool hovered: false
                    property bool showTooltip: false
                    property var messageCenterRoot: root
                    property var messageData: modelData
                    color: hovered ? Theme.Colors.secondary : Theme.Colors.backgroundGray
                    border.width: 1
                    border.color: hovered ? Theme.Colors.primary : Theme.Colors.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 17
                        anchors.rightMargin: 17
                        anchors.topMargin: 17
                        anchors.bottomMargin: 17
                        spacing: 12

                        // Unread indicator (red dot)
                        Rectangle {
                            visible: messageItem.messageData.isRead === 0
                            width: 8
                            height: 8
                            radius: 4
                            color: "#d4183d"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Content area
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Date/time
                            Text {
                                text: root.formatCreateTime(messageItem.messageData.createTime)
                                font.pixelSize: 12
                                color: "#5a7c9b"
                                Layout.fillWidth: true
                            }

                            // Message content
                            Text {
                                id: messageText
                                text: messageItem.messageData.message || ""
                                font.pixelSize: 16
                                color: "#030213"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }

                        // Delete button
                        Rectangle {
                            id: deleteButton
                            width: 24
                            height: 24
                            radius: 12
                            color: deleteArea.containsMouse ? "#fdecee" : "transparent"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 18
                                color: deleteArea.containsMouse ? "#D4183D" : "#D4183D"
                            }

                            MouseArea {
                                id: deleteArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.deleteMessage(messageItem.messageData.messageCode)
                            }
                        }
                    }

                    Rectangle {
                        id: messageTooltip
                        visible: messageItem.showTooltip
                        width: messageItem.width
                        height: messageItem.height
                        color: "#1e5a8e"
                        radius: 10
                        z: 1000
                        x: 0
                        y: (index > 0) ? (-height - 12) : (messageItem.height + 12)
                        border.width: 1
                        border.color: "#0f4c81"

                        Text {
                            id: msgTooltipText
                            anchors.fill: parent
                            anchors.margins: 12
                            text: messageItem.messageData.message || ""
                            font.pixelSize: 13
                            color: "white"
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        // 上方覆盖时：箭头显示在底部居中
                        Canvas {
                            visible: index > 0
                            width: 10
                            height: 5
                            anchors.top: parent.bottom
                            x: Math.round((parent.width - width) / 2)
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

                        // 首条消息下方显示时：箭头显示在顶部居中
                        Canvas {
                            visible: index === 0
                            width: 10
                            height: 5
                            anchors.bottom: parent.top
                            x: Math.round((parent.width - width) / 2)
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = "#1e5a8e"
                                ctx.beginPath()
                                ctx.moveTo(0, 5)
                                ctx.lineTo(5, 0)
                                ctx.lineTo(10, 5)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }

                    // Click to mark as read / Show tooltip on hover
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 50  // Don't overlap delete button
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: {
                               messageItem.hovered = true
                               if (messageText.implicitWidth > messageText.width) messageItem.showTooltip = true
                        }
                        onExited: {
                               messageItem.hovered = false
                               messageItem.showTooltip = false
                        }
                        onClicked: {
                            if (messageItem.messageData.isRead === 0) {
                                messageItem.messageCenterRoot.markMessageAsRead(messageItem.messageData.messageCode)
                                var targetDomainCode = messageItem.messageCenterRoot.resolveMessageDomainCode(messageItem.messageData)
                                if (targetDomainCode) {
                                    messageItem.messageCenterRoot.domainMessageClicked(targetDomainCode)
                                } else {
                                    console.warn("[MessageCenter] drop domain navigation: missing domainCode", JSON.stringify(messageItem.messageData || {}))
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Item {
                visible: root.serverMessages.length === 0 && !root.serverLoading
                width: parent.width
                height: 200

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -70
                    spacing: 8
                    
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                        sourceSize: Qt.size(51, 50)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentFilter === "unread" ? "暂无未读消息" : "暂无消息"
                        font.pixelSize: 14
                        color: "#90A1B9"
                    }
                }
            }
        }
    }

    // Pagination
    Item {
        id: pagination
        width: parent.width
        height: root.serverTotalPages > 1 ? 65 : 0
        visible: root.serverTotalPages > 1
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        // Top border
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#e6e6e6"
        }

        Row {
            anchors.centerIn: parent
            spacing: 6
            visible: root.serverTotalPages > 1

            // Previous
            Text {
                text: "<"
                font.pixelSize: 14
                property bool hovered: false
                property bool pressed: false
                color: {
                    if (root.currentPage <= 1) return "#919eab"
                    if (pressed) return "white"
                    if (hovered) return "#1b5fa8"
                    return "#212b36"
                }
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 3
                    visible: root.currentPage > 1 && (parent.hovered || parent.pressed)
                    color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                    z: -1
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: root.currentPage > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onEntered: parent.hovered = true
                    onExited: { parent.hovered = false; parent.pressed = false }
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                    onClicked: {
                        var newPage = root.currentPage - 1
                        root.currentPage = newPage
                        root.fetchMessages(newPage)
                    }
                }
            }

            // Page numbers with ellipsis
            Repeater {
                model: root.getVisiblePages()
                Rectangle {
                    width: 22; height: 22; radius: 3
                    property int pageNum: modelData
                    property bool isEllipsis: pageNum === -1
                    property bool hovered: false
                    property bool pressed: false
                    property bool isCurrent: pageNum === root.currentPage
                    color: {
                        if (pressed && !isCurrent) return "#1b5fa8"
                        if (hovered && !isEllipsis) return "#e3f2fd"
                        return "white"
                    }
                    border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: isEllipsis ? "..." : pageNum
                        font.pixelSize: 12
                        color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !isEllipsis
                        cursorShape: !isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true
                        onEntered: parent.hovered = true
                        onExited: { parent.hovered = false; parent.pressed = false }
                        onPressed: if (!parent.isCurrent) parent.pressed = true
                        onReleased: parent.pressed = false
                        onClicked: {
                            if (!parent.isCurrent) {
                                root.currentPage = pageNum
                                root.fetchMessages(pageNum)
                            }
                        }
                    }
                }
            }

            // Next
            Text {
                text: ">"
                font.pixelSize: 14
                property bool hovered: false
                property bool pressed: false
                color: {
                    if (root.currentPage >= root.serverTotalPages) return "#919eab"
                    if (pressed) return "white"
                    if (hovered) return "#1b5fa8"
                    return "#212b36"
                }
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 3
                    visible: root.currentPage < root.serverTotalPages && (parent.hovered || parent.pressed)
                    color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                    z: -1
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: root.currentPage < root.serverTotalPages
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onEntered: parent.hovered = true
                    onExited: { parent.hovered = false; parent.pressed = false }
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                    onClicked: {
                        var newPage = root.currentPage + 1
                        root.currentPage = newPage
                        root.fetchMessages(newPage)
                    }
                }
            }
        }
    }

}
