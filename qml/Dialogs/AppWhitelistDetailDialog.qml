import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: {
        var preferredWidth = 510;
        var maxWidth = parentWidth * 0.85;
        var minWidth = 400;
        return Math.max(minWidth, Math.min(preferredWidth, maxWidth));
    }
    title: root.status === "待审核" ? qsTr("App Whitelist Application") : qsTr("App Whitelist Details")

    property real parentWidth: parent ? parent.width : 800
    property real parentHeight: parent ? parent.height : 600

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
    signal approveClicked
    signal rejectClicked

    // ── parent resize ─────────────────────────────────────────────
    Connections {
        target: root.parent
        function onWidthChanged() {
            root.parentWidth = root.parent.width;
        }
        function onHeightChanged() {
            root.parentHeight = root.parent.height;
        }
    }

    readonly property var statusStyle: Theme.Colors.getStatusColor(status)

    function syncSelectedProcess() {
        if (!root.processes || root.processes.length === 0) {
            root.fileCode = "";
            root.fileHash = "";
            return;
        }
        if (root.selectedProcessIndex < 0 || root.selectedProcessIndex >= root.processes.length) {
            root.selectedProcessIndex = 0;
        }
        var selected = root.processes[root.selectedProcessIndex] || {};
        root.fileCode = selected.fileCode || "";
        root.fileHash = selected.fileHash || "";
        root.appName = selected.fileName || root.appName;
    }

    onProcessesChanged: {
        if (selectedProcessIndex >= processCount) {
            selectedProcessIndex = 0;
        }
        syncSelectedProcess();
    }

    onSelectedProcessIndexChanged: syncSelectedProcess()
    onOpened: syncSelectedProcess()
    onClosed: {
        loading = false;
    }

    // Hidden TextEdit used as clipboard helper
    TextEdit {
        id: clipboardHelper
        visible: false
        readOnly: false
    }

    Column {
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 12
        }

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
                        color: Theme.Colors.textCaption
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
                        color: Theme.Colors.textCaption
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
                            text: Theme.Colors.translateStatus(root.status) || "-"
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
                        color: Theme.Colors.textCaption
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
                        color: Theme.Colors.textCaption
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
                        color: Theme.Colors.textCaption
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
                        color: Theme.Colors.textCaption
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

        Item {
            width: parent.width
            height: 12
        }
        Item {
            width: parent.width
            height: 4
        }

        SelectableText {
            text: qsTr("App Whitelist Dependency Files")
            font.pixelSize: 14
            color: Theme.Colors.textCaption
        }

        Item {
            width: parent.width
            height: 8
        }

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
            border.color: Theme.Colors.borderSeparator
            border.width: 1
            clip: false

            // Table header
            Rectangle {
                id: tableHeader
                width: parent.width
                height: 40
                color: Theme.Colors.backgroundSidebar
                radius: 8

                // Round only top corners via bottom cover
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 8
                    color: Theme.Colors.backgroundSidebar
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
                            color: Theme.Colors.textCaption
                        }
                    }

                    Item {
                        width: (parent.width - 32) * 0.5
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Hash Value")
                            font.pixelSize: 14
                            color: Theme.Colors.textCaption
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
                            palette.dark: Theme.Colors.textCounter
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
                            color: Theme.Colors.textCounter
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
                                            var p = hashHoverArea.mapToItem(root.contentItem, mouseX, mouseY);
                                            return p.x;
                                        }
                                        property real mappedMouseY: {
                                            var p = hashHoverArea.mapToItem(root.contentItem, mouseX, mouseY);
                                            return p.y;
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
                                                        var ctx = getContext("2d");
                                                        ctx.reset();
                                                        ctx.fillStyle = "#1e5a8e";
                                                        ctx.beginPath();
                                                        ctx.moveTo(0, 0);
                                                        ctx.lineTo(5, 5);
                                                        ctx.lineTo(10, 0);
                                                        ctx.closePath();
                                                        ctx.fill();
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
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.reset();
                                                if (copyHashBtn.copied) {
                                                    // Draw checkmark
                                                    ctx.strokeStyle = "#2e7d32";
                                                    ctx.lineWidth = 2;
                                                    ctx.lineCap = "round";
                                                    ctx.lineJoin = "round";
                                                    ctx.beginPath();
                                                    ctx.moveTo(3, 7);
                                                    ctx.lineTo(6, 10);
                                                    ctx.lineTo(11, 4);
                                                    ctx.stroke();
                                                } else {
                                                    // Draw copy icon (two overlapping squares)
                                                    ctx.strokeStyle = copyHashArea.containsMouse ? "#0d5a95" : "#1b5fa8";
                                                    ctx.lineWidth = 1.5;
                                                    ctx.lineCap = "round";
                                                    ctx.lineJoin = "round";

                                                    // Back square
                                                    ctx.strokeRect(3.5, 1.5, 7, 7);
                                                    // Front square
                                                    ctx.fillStyle = "white";
                                                    ctx.fillRect(4.5, 4.5, 7, 7);
                                                    ctx.strokeRect(4.5, 4.5, 7, 7);
                                                }
                                            }

                                            Connections {
                                                target: copyHashBtn
                                                function onCopiedChanged() {
                                                    copyIcon.requestPaint();
                                                }
                                            }

                                            Connections {
                                                target: copyHashArea
                                                function onContainsMouseChanged() {
                                                    copyIcon.requestPaint();
                                                }
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
                                                    clipboardHelper.text = modelData.fileHash;
                                                    clipboardHelper.selectAll();
                                                    clipboardHelper.copy();
                                                    copyHashBtn.copied = true;
                                                    copyResetTimer.restart();
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
        Item {
            width: parent.width
            height: shouldShowActionButtons ? 12 : 0
            visible: shouldShowActionButtons
        }

        Item {
            width: parent.width
            height: 36
            visible: shouldShowActionButtons

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                DangerButton {
                    text: qsTr("Reject")
                    onClicked: {
                        root.rejectClicked();
                        root.close();
                    }
                }

                PrimaryButton {
                    text: qsTr("Approve")
                    onClicked: {
                        root.approveClicked();
                        root.close();
                    }
                }
            }
        }
    }
}
