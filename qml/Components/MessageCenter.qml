import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme

Item {
    id: root
    width: 992
    height: 734

    // Properties
    property string currentFilter: "all"  // "all" or "unread"
    property int currentPage: 1
    property int pageSize: AppConfig.messageCenterPageSize()

    // All messages from core (unfiltered, sorted newest-first)
    property var allMessages: []

    // Current page slice after filtering
    property var serverMessages: []
    property int serverTotalPages: 0
    property bool serverLoading: false

    signal unreadCountFetched(int count)
    signal unreadMessageMarkedRead
    signal allMessagesMarkedRead
    signal domainMessageClicked(string domainCode)

    signal backRequested

    function _applyFilterAndPaginate() {
        var filtered = [];
        for (var i = 0; i < allMessages.length; i++) {
            var m = allMessages[i];
            if (root.currentFilter === "unread") {
                if (m.isRead === 0)
                    filtered.push(m);
            } else {
                filtered.push(m);
            }
        }
        var total = Math.ceil(filtered.length / root.pageSize);
        if (total < 1)
            total = 1;
        root.serverTotalPages = total;
        if (root.currentPage > total)
            root.currentPage = total;
        var startIdx = (root.currentPage - 1) * root.pageSize;
        var endIdx = Math.min(startIdx + root.pageSize, filtered.length);
        var page = [];
        for (var j = startIdx; j < endIdx; j++) {
            page.push(filtered[j]);
        }
        root.serverMessages = page;
        var unreadCount = 0;
        for (var k = 0; k < allMessages.length; k++) {
            if (allMessages[k].isRead === 0)
                unreadCount++;
        }
        root.unreadCountFetched(unreadCount);
    }

    function fetchMessages(pageNo) {
        root.currentPage = pageNo;
        DsccBridge.loadMessageList();
    }

    // 将 createTime 转换为可读格式（支持时间戳毫秒数和字符串两种格式）
    function formatCreateTime(val) {
        if (!val)
            return "";
        var ts = parseInt(val);
        if (!isNaN(ts) && ts > 1000000000000) {
            var d = new Date(ts);
            var year = d.getFullYear();
            var month = ("0" + (d.getMonth() + 1)).slice(-2);
            var day = ("0" + d.getDate()).slice(-2);
            return year + "-" + month + "-" + day;
        }
        return String(val).substring(0, 10);
    }

    function fetchUnreadCount() {
        DsccBridge.loadMessageList();
    }

    onVisibleChanged: {
        if (visible) {
            currentFilter = "all";
            currentPage = 1;
            fetchUnreadCount();
        }
    }

    Connections {
        target: DsccBridge
        function onMessageListLoaded(messages) {
            root.allMessages = messages;
            root._applyFilterAndPaginate();
            root.serverLoading = false;
        }
        function onMessageRead(operation_id, message_code) {
            root.unreadMessageMarkedRead();
        }
        function onAllMessagesRead(operation_id) {
            root.allMessagesMarkedRead();
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

    // Filter tabs
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
                        root.currentFilter = "all";
                        root.currentPage = 1;
                        root._applyFilterAndPaginate();
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
                        root.currentFilter = "unread";
                        root.currentPage = 1;
                        root._applyFilterAndPaginate();
                    }
                }
            }
        }

        // "一键已读" button
        Rectangle {
            id: markAllButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 37
            radius: 10
            color: hovered ? Theme.Colors.secondary : "transparent"
            border.width: 1
            border.color: Theme.Colors.primary
            property bool hovered: false
            implicitWidth: markAllText.implicitWidth + 40  // Auto-size to content with padding

            Row {
                id: markAllContent
                anchors.centerIn: parent
                spacing: 8

                Image {
                    width: 16
                    height: 16
                    source: "qrc:/icons/icon-check-double.svg"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: markAllText
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
                onClicked: DsccBridge.readAllMessages()
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
                                ToolTip.visible: messageItem.hovered && implicitWidth > width
                                ToolTip.text: messageItem.messageData.message || ""
                                ToolTip.delay: 500
                            }
                        }
                    }

                    // Click to mark as read + hover state
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: messageItem.messageData.isRead === 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: messageItem.hovered = true
                        onExited: messageItem.hovered = false
                        onClicked: {
                            if (messageItem.messageData.isRead === 0) {
                                DsccBridge.readMessage(messageItem.messageData.messageCode);
                            }
                        }
                    }

                    // Delete button (visible on hover, above the main MouseArea)
                    Rectangle {
                        visible: messageItem.hovered
                        width: 24
                        height: 24
                        radius: 12
                        color: deleteArea.containsMouse ? "#fee2e2" : "transparent"
                        anchors.right: parent.right
                        anchors.rightMargin: 17
                        anchors.verticalCenter: parent.verticalCenter
                        z: 10

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 18
                            color: deleteArea.containsMouse ? "#dc2626" : "#90A1B9"
                        }

                        MouseArea {
                            id: deleteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                deleteConfirmDialog.targetMessageCode = messageItem.messageData.messageCode || "";
                                deleteConfirmDialog.open();
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
                        source: "qrc:/icons/icon-empty-state.svg"
                        sourceSize: Qt.size(51, 50)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentFilter === "unread" ? qsTr("No unread messages") : qsTr("No messages")
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

        PaginationControl {
            width: parent.width
            height: parent.height
            currentPage: root.currentPage
            totalPages: root.serverTotalPages
            onPageChanged: {
                root.currentPage = page;
                root._applyFilterAndPaginate();
            }
        }
    }

    // Delete confirmation dialog
    Popup {
        id: deleteConfirmDialog
        width: 360
        implicitHeight: deleteDialogContent.implicitHeight + 48
        height: implicitHeight
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (parent ? (parent.width - width) / 2 : 0)
        y: (parent ? (parent.height - height) / 2 : 0)

        property string targetMessageCode: ""

        background: null
        padding: 0

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.Colors.backgroundWhite
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1

            Column {
                id: deleteDialogContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.top: parent.top
                anchors.topMargin: 24
                spacing: 0

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Delete Message")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: "#0f172b"
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 12
                        color: deleteCloseArea.containsMouse ? "#f0f4fa" : "transparent"

                        MouseArea {
                            id: deleteCloseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: deleteConfirmDialog.close()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 18
                            color: deleteCloseArea.containsMouse ? "#0f4c81" : "#314158"
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 24
                }

                Text {
                    width: parent.width
                    text: qsTr("Are you sure you want to delete this message?")
                    font.pixelSize: 14
                    color: "#314158"
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: 28
                }

                Row {
                    anchors.right: parent.right
                    spacing: 16
                    height: 36

                    SecondaryButton {
                        text: qsTr("Cancel")
                        onClicked: deleteConfirmDialog.close()
                    }

                    DangerButton {
                        text: qsTr("Delete")
                        onClicked: {
                            DsccBridge.deleteMessage(deleteConfirmDialog.targetMessageCode);
                            deleteConfirmDialog.close();
                        }
                    }
                }
            }
        }
    }
}
