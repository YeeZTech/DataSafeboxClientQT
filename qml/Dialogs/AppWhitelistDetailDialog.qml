import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root

    property real parentWidth: parent ? parent.width : 800
    property real parentHeight: parent ? parent.height : 600

    width: {
        var preferredWidth = 510
        var maxWidth = parentWidth * 0.85
        var minWidth = 400
        return Math.max(minWidth, Math.min(preferredWidth, maxWidth))
    }
    height: mainColumn.implicitHeight + 40

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: Math.max(0, (parentWidth - width) / 2)
    y: Math.max(0, (parentHeight - height) / 2)

    // ── data properties ──────────────────────────────────────────
    property string instanceCode: ""            // 实例编号
    property string applyCode: ""               // 申请编号
    property string fileCode: ""                // 文件编号（单条记录审批）
    property string fileHash: ""                // 文件哈希（用于生成授权签名）
    property string status: ""                  // 状态
    property string creator: ""                 // 创建方
    property string instanceName: ""            // 安全域实例名称
    property string appliedTime: ""             // 申请时间
    property string duration: ""                // 实例申请时长
    property string cost: ""                    // 实例费用
    property string appName: ""                 // 应用名称 label
    property var processes: []                  // [{path, hash}] 进程路径/Hash 表
    property int selectedProcessIndex: 0
    readonly property int processCount: (root.processes && root.processes.length) ? root.processes.length : 0
    property bool showActionButtons: false      // 传入方控制是否允许审批
    property bool shouldShowActionButtons: showActionButtons && (status === "待审核")
    property bool loading: false               // 文件列表加载中

    // ── signals ──────────────────────────────────────────────────
    signal approveClicked()
    signal rejectClicked()

    // ── parent resize ─────────────────────────────────────────────
    Connections {
        target: root.parent
        function onWidthChanged() { root.parentWidth = root.parent.width }
        function onHeightChanged() { root.parentHeight = root.parent.height }
    }

    readonly property var statusStyle: Theme.Colors.getStatusColor(status)

    function syncSelectedProcess() {
        if (!root.processes || root.processes.length === 0) {
            root.fileCode = ""
            root.fileHash = ""
            return
        }

        if (root.selectedProcessIndex < 0 || root.selectedProcessIndex >= root.processes.length) {
            root.selectedProcessIndex = 0
        }

        var selected = root.processes[root.selectedProcessIndex] || {}
        root.fileCode = selected.fileCode || ""
        root.fileHash = selected.fileHash || ""
        root.appName = selected.fileName || root.appName
    }

    onProcessesChanged: {
        if (selectedProcessIndex >= processCount) {
            selectedProcessIndex = 0
        }
        syncSelectedProcess()
    }

    onSelectedProcessIndexChanged: syncSelectedProcess()
    onOpened: syncSelectedProcess()
    onClosed: { loading = false }

    // Hidden TextEdit used as clipboard helper
    TextEdit {
        id: clipboardHelper
        visible: false
        readOnly: false
    }

    background: null
    padding: 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
        layer.enabled: true
        layer.effect: null

        Column {
            id: mainColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 0

            // ── Title row ──────────────────────────────────────────
            Item {
                width: parent.width
                height: 18

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.status === "待审核" ? qsTr("App Whitelist Application") : qsTr("App Whitelist Details")
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
                    color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 18
                        color: closeArea.containsMouse ? "#0f4c81" : "#314158"
                    }
                }
            }

            Item { width: parent.width; height: 12 }

            // ── Fields area ────────────────────────────────────────
            Column {
                id: fieldsArea
                width: parent.width
                spacing: 12

                // Row 1: 申请编号 | 状态
                Row {
                    width: parent.width
                    spacing: 16

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Application No.")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        Text {
                            width: parent.width
                            text: root.applyCode || "-"
                            font.pixelSize: 16
                            color: "#000000"
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                        }
                    }

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Status")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        // Status badge
                        Rectangle {
                            width: statusBadgeText.implicitWidth + 18
                            height: 26
                            radius: 8
                            color: root.statusStyle.bg
                            border.color: root.statusStyle.border
                            border.width: 1

                            Text {
                                id: statusBadgeText
                                anchors.centerIn: parent
                                text: window.translateStatus(root.status) || "-"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: root.statusStyle.text
                            }
                        }
                    }
                }

                // Row 2: 申请方 | 安全域实例名称
                Row {
                    width: parent.width
                    spacing: 16

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Applicant")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        Text {
                            width: parent.width
                            text: root.creator || "-"
                            font.pixelSize: 16
                            color: "#000000"
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                        }
                    }

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Security Domain Instance Name")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        Text {
                            text: root.instanceName || "-"
                            font.pixelSize: 16
                            color: "#000000"
                            elide: Text.ElideMiddle
                            width: parent.width
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 16

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Application Time")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        SelectableText {
                            text: root.appliedTime || "-"
                            font.pixelSize: 16
                            color: "#000000"
                        }
                    }

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4

                        SelectableText {
                            text: qsTr("Application Name")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        Text {
                            width: parent.width
                            text: root.appName || "-"
                            font.pixelSize: 16
                            color: "#000000"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item { width: parent.width; height: 12 }
            Item { width: parent.width; height: 4 }

            SelectableText {
                text: qsTr("App Whitelist Dependency Files")
                font.pixelSize: 14
                color: "#62748e"
            }

            Item { width: parent.width; height: 8 }

            // ── Processes table ─────────────────────────────────────
            Rectangle {
                id: processesTable
                width: parent.width
                property int rowHeight: 36
                property int maxVisibleRows: 5
                readonly property int dataRowCount: (root.processes && root.processes.length > 0) ? root.processes.length : 1
                readonly property int visibleRows: Math.min(maxVisibleRows, dataRowCount)
                implicitHeight: tableHeader.height + (rowHeight * visibleRows)
                height: implicitHeight
                radius: 8
                color: "white"
                border.color: "#e2e8f0"
                border.width: 1
                clip: false

                // Table header
                Rectangle {
                    id: tableHeader
                    width: parent.width
                    height: 40
                    color: "#f5f8fb"
                    radius: 8

                    // Round only top corners via bottom cover
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 8
                        color: "#f5f8fb"
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.1)
                    }

                    Row {
                        anchors.fill: parent

                        Item {
                            width: (parent.width - 32) * 0.5
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Executable File Name")
                                font.pixelSize: 14
                                color: "#62748e"
                            }
                        }

                        Item {
                            width: (parent.width - 32) * 0.5
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Hash Value")
                                font.pixelSize: 14
                                color: "#62748e"
                            }
                        }

                        Item {
                            width: 32
                            height: parent.height
                        }
                    }
                }

                // Table body (scroll when rows > maxVisibleRows)
                Flickable {
                    id: tableBodyFlick
                    anchors.top: tableHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: tableBodyColumn.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Column {
                        id: tableBodyColumn
                        width: tableBodyFlick.width
                        spacing: 0

                        // Loading state
                        Item {
                            width: parent.width
                            height: 40
                            visible: root.loading

                            BusyIndicator {
                                anchors.centerIn: parent
                                running: root.loading
                                width: 24
                                height: 24
                                palette.dark: "#90a1b9"
                            }
                        }

                        // Empty state (no processes)
                        Item {
                            width: parent.width
                            height: 40
                            visible: !root.loading && (!root.processes || root.processes.length === 0)

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("No data")
                                font.pixelSize: 14
                                color: "#90a1b9"
                            }
                        }

                        // Process rows
                        Repeater {
                            model: root.loading ? [] : (root.processes || [])

                            Rectangle {
                                width: processesTable.width
                                height: processesTable.rowHeight
                                color: processRowArea.containsMouse ? "#f2f7fd" : "transparent"

                                HoverHandler {
                                    id: processRowArea
                                    acceptedDevices: PointerDevice.Mouse
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: Qt.rgba(0, 0, 0, 0.1)
                                }

                                Row {
                                    anchors.fill: parent

                                    // File name column
                                    Item {
                                        width: (parent.width - 32) * 0.5
                                        height: parent.height

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.fileName || root.appName || "-"
                                            font.pixelSize: 14
                                            color: "#000000"
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    // Hash value column
                                    Item {
                                        width: (parent.width - 32) * 0.5
                                        height: parent.height

                                        Text {
                                            id: hashDisplayText
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.fileHash || "-"
                                            font.pixelSize: 14
                                            color: "#000000"
                                            elide: Text.ElideMiddle
                                        }

                                        MouseArea {
                                            id: hashHoverArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            cursorShape: Qt.ArrowCursor

                                            // 将鼠标坐标映射到 root.contentItem
                                            property real mappedMouseX: {
                                                var p = hashHoverArea.mapToItem(root.contentItem, mouseX, mouseY)
                                                return p.x
                                            }
                                            property real mappedMouseY: {
                                                var p = hashHoverArea.mapToItem(root.contentItem, mouseX, mouseY)
                                                return p.y
                                            }
                                        }

                                        Popup {
                                            id: hashTooltip
                                            parent: root.contentItem
                                            modal: false
                                            focus: false
                                            closePolicy: Popup.NoAutoClose
                                            padding: 0
                                            visible: hashHoverArea.containsMouse && (modelData.fileHash || "").length > 0
                                            z: 99999

                                            readonly property real bubbleWidth: Math.min(hashTooltipText.implicitWidth + 16, root.width - 24)
                                            // 固定在鼠标上方 14px
                                            readonly property real aboveMouseY: hashHoverArea.mappedMouseY - hashTooltipBubble.height - 14
                                            // 气泡左边对齐鼠标中心，夹紧到对话框内
                                            readonly property real clampedX: Math.max(8, Math.min(root.width - bubbleWidth - 8, hashHoverArea.mappedMouseX - bubbleWidth / 2))
                                            // 三角指向鼠标 x
                                            readonly property real arrowOffsetX: Math.max(6, Math.min(bubbleWidth - 16, hashHoverArea.mappedMouseX - clampedX - 5))

                                            x: clampedX
                                            y: aboveMouseY

                                            background: Item {
                                                Rectangle {
                                                    id: hashTooltipBubble
                                                    width: hashTooltip.bubbleWidth
                                                    height: Math.max(28, hashTooltipText.implicitHeight + 10)
                                                    color: "#1e5a8e"
                                                    radius: 4

                                                    Text {
                                                        id: hashTooltipText
                                                        anchors.centerIn: parent
                                                        width: Math.max(0, parent.width - 16)
                                                        text: modelData.fileHash || ""
                                                        font.pixelSize: 13
                                                        color: "white"
                                                        wrapMode: Text.WrapAnywhere
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }

                                                    Canvas {
                                                        width: 10
                                                        height: 5
                                                        anchors.top: parent.bottom
                                                        x: hashTooltip.arrowOffsetX
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

                                    // Copy icon column (rightmost)
                                    Item {
                                        width: 32
                                        height: parent.height

                                        // Copy hash icon button
                                        Item {
                                            id: copyHashBtn
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            visible: (modelData.fileHash || "").length > 0

                                            property bool copied: false

                                            // Copy icon using Canvas
                                            Canvas {
                                                id: copyIcon
                                                anchors.centerIn: parent
                                                width: 14
                                                height: 14
                                                opacity: copyHashBtn.copied ? 1 : (copyHashArea.containsMouse ? 0.8 : 0.6)
                                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    
                                                    if (copyHashBtn.copied) {
                                                        // Draw checkmark
                                                        ctx.strokeStyle = "#2e7d32"
                                                        ctx.lineWidth = 2
                                                        ctx.lineCap = "round"
                                                        ctx.lineJoin = "round"
                                                        ctx.beginPath()
                                                        ctx.moveTo(3, 7)
                                                        ctx.lineTo(6, 10)
                                                        ctx.lineTo(11, 4)
                                                        ctx.stroke()
                                                    } else {
                                                        // Draw copy icon (two overlapping squares)
                                                        ctx.strokeStyle = copyHashArea.containsMouse ? "#0d5a95" : "#1b5fa8"
                                                        ctx.lineWidth = 1.5
                                                        ctx.lineCap = "round"
                                                        ctx.lineJoin = "round"
                                                        
                                                        // Back square
                                                        ctx.strokeRect(3.5, 1.5, 7, 7)
                                                        // Front square
                                                        ctx.fillStyle = "white"
                                                        ctx.fillRect(4.5, 4.5, 7, 7)
                                                        ctx.strokeRect(4.5, 4.5, 7, 7)
                                                    }
                                                }

                                                Connections {
                                                    target: copyHashBtn
                                                    function onCopiedChanged() { copyIcon.requestPaint() }
                                                }

                                                Connections {
                                                    target: copyHashArea
                                                    function onContainsMouseChanged() { copyIcon.requestPaint() }
                                                }
                                            }

                                            Timer {
                                                id: copyResetTimer
                                                interval: 1500
                                                onTriggered: copyHashBtn.copied = false
                                            }

                                            MouseArea {
                                                id: copyHashArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.fileHash) {
                                                        clipboardHelper.text = modelData.fileHash
                                                        clipboardHelper.selectAll()
                                                        clipboardHelper.copy()
                                                        copyHashBtn.copied = true
                                                        copyResetTimer.restart()
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

            // ── Action buttons (only for 待审核) ────────────────────
            Item { width: parent.width; height: shouldShowActionButtons ? 12 : 0; visible: shouldShowActionButtons }

            Item {
                width: parent.width
                height: 36
                visible: shouldShowActionButtons

                // Reject button
                Rectangle {
                    id: rejectBtn
                    anchors.right: approveBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    height: 36
                    radius: 8
                    property bool hovered: false
                    property bool pressed: false
                    color: pressed ? "#ffe9e9" : (hovered ? "#fff5f5" : "white")
                    border.color: pressed ? "#ff6b6b" : (hovered ? "#ff9090" : "#ffa2a2")
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Reject")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: rejectBtn.pressed ? "#9f0006" : (rejectBtn.hovered ? "#c50009" : "#e7000b")
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: rejectBtn.hovered = true
                        onExited: rejectBtn.hovered = false
                        onPressed: rejectBtn.pressed = true
                        onReleased: rejectBtn.pressed = false
                        onCanceled: rejectBtn.pressed = false
                        onClicked: {
                            root.rejectClicked()
                            root.close()
                        }
                    }
                }

                // Approve button
                Rectangle {
                    id: approveBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 36
                    radius: 8
                    color: approveBtnArea.pressed ? "#0a3d6b" : (approveBtnArea.containsMouse ? "#0d5a95" : "#0f4c81")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    visible: shouldShowActionButtons

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Approve")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        id: approveBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.approveClicked()
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
