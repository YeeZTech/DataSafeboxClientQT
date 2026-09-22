import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 500
    title: root.status === "待审核" ? qsTr("App Whitelist Application") : qsTr("App Whitelist Details")

    // ── data properties ──────────────────────────────────────────
    property string instanceCode: ""            // 实例编号
    property string applyCode: ""               // 申请编号
    property string fileCode: ""                // 文件编号（单条记录审批）
    property string fileHash: ""                // 文件哈希（用于生成授权签名）
    property string status: ""                  // 状态
    property string creator: ""                 // 创建方
    property string instanceName: ""            // 安全域实例名称
    property string appliedTime: ""             // 申请时间
    property var expireAt: undefined            // 授权到期时间（epoch 毫秒，0 表示永久）
    property string duration: ""                // 实例申请时长
    property string cost: ""                    // 实例费用
    property string appName: ""                 // 应用名称 label
    // 细粒度（带命令行）白名单才有：被授权的整条命令行与匹配模式。空串表示这是
    // 一条只按可执行文件路径授权的旧式申请。
    property string commandLine: ""
    property string matchMode: ""               // "exact" | "prefix"
    property var processes: []                  // [{path, hash}] 进程路径/Hash 表
    property int selectedProcessIndex: 0
    readonly property int processCount: (root.processes && root.processes.length) ? root.processes.length : 0
    property bool showActionButtons: false      // 传入方控制是否允许审批
    property bool shouldShowActionButtons: showActionButtons && (status === "待审核")
    property bool loading: false               // 文件列表加载中

    // ── signals ──────────────────────────────────────────────────
    signal approveClicked
    signal rejectClicked

    readonly property var statusStyle: Theme.Colors.getStatusColor(status)

    // 整单里的主程序行。命令行那条被排到了列表最前（它才是审批要判断的东西），
    // 但"应用名称"和审批锚点 fileCode 要的是主程序，不是命令行，也不是某个 ldd 依赖。
    function masterProcessIndex() {
        if (!root.processes)
            return 0;
        for (var i = 0; i < root.processes.length; i++) {
            if (root.processes[i] && root.processes[i].isMaster)
                return i;
        }
        return 0;
    }

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
        // 命令行那一行不是文件，它的"文件名"是整条命令行；拿它当应用名会把标题
        // 区塞满，而命令行自有专门的展示区。
        if (!selected.isCmdline) {
            root.appName = selected.fileName || root.appName;
        }
    }

    onProcessesChanged: {
        selectedProcessIndex = masterProcessIndex();
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
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                    }
                    Text {
                        width: parent.width
                        text: root.applyCode || "-"
                        font.pixelSize: Theme.Typography.h3
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
                        font.pixelSize: Theme.Typography.body
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
                            font.pixelSize: Theme.Typography.body
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
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                    }
                    Text {
                        width: parent.width
                        text: root.creator || "-"
                        font.pixelSize: Theme.Typography.h3
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
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                    }
                    Text {
                        text: root.instanceName || "-"
                        font.pixelSize: Theme.Typography.h3
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
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                    }
                    SelectableText {
                        text: root.appliedTime || "-"
                        font.pixelSize: Theme.Typography.h3
                        color: "#000000"
                    }
                }

                Column {
                    width: (parent.width - 16) / 2
                    spacing: 4

                    SelectableText {
                        text: qsTr("Application Name")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                    }

                    Text {
                        width: parent.width
                        text: root.appName || "-"
                        font.pixelSize: Theme.Typography.h3
                        color: "#000000"
                        elide: Text.ElideRight
                    }
                }
            }

            // 授权的命令行。只在细粒度申请里出现。
            //
            // 这是本次审批真正要判断的东西：按可执行文件路径授权对解释器来说不成
            // 其为身份——批了 /usr/bin/python3，就等于批了它能跑的任何脚本。批准
            // 这一行等于对整条命令行签名，之后只有以这条命令行启动的进程才获得
            // 豁免。因此它必须完整显示、可换行、不省略：省略号后面藏着什么都不
            // 知道就签字，等于没审。
            Column {
                width: parent.width
                spacing: 4
                visible: root.commandLine !== ""

                SelectableText {
                    text: qsTr("Authorized command line")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                Rectangle {
                    width: parent.width
                    height: commandLineText.implicitHeight + 20
                    radius: 6
                    color: "#F5F7FA"
                    border.width: 1
                    border.color: "#E3E8EF"

                    SelectableText {
                        id: commandLineText
                        x: 10
                        y: 10
                        width: parent.width - 20
                        text: root.commandLine
                        font.pixelSize: Theme.Typography.body
                        font.family: "monospace"
                        color: "#000000"
                        wrapMode: Text.WrapAnywhere
                    }
                }

                SelectableText {
                    width: parent.width
                    text: root.matchMode === "prefix" ? qsTr("Prefix match: the process may append further arguments.") : qsTr("Exact match: the command line must match argument for argument.")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                    wrapMode: Text.WordWrap
                }

                SelectableText {
                    width: parent.width
                    text: qsTr("Arguments that name a file are pinned by content hash, so replacing that file revokes the grant. A process whose environment carries LD_PRELOAD, PYTHONPATH or similar injection variables is never exempted, whatever the command line.")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                    wrapMode: Text.WordWrap
                }
            }

            // Row 4: 申请授权有效期至
            Row {
                width: parent.width
                spacing: 16

                Column {
                    width: (parent.width - 16) / 2
                    spacing: 4

                    SelectableText {
                        text: qsTr("Authorized Until")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                        width: parent.width
                    }

                    SelectableText {
                        text: Theme.Utils.formatExpiry(root.expireAt)
                        font.pixelSize: Theme.Typography.h3
                        color: "#000000"
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
            // 表里不止依赖库：主程序、命令行、被内容锁定的参数文件都在其中，整单
            // 一起批准，所以按"申请文件"称呼它，与 `dv audit whitelist-detail` 一致。
            text: qsTr("Application Files")
            font.pixelSize: Theme.Typography.body
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
                            text: qsTr("File Name")
                            font.pixelSize: Theme.Typography.body
                            color: Theme.Colors.textCaption
                        }
                    }

                    Item {
                        width: (parent.width - 32) * 0.5
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Hash Value")
                            font.pixelSize: Theme.Typography.body
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
                            font.pixelSize: Theme.Typography.body
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
                                        // 命令行那一行不是文件，标出来免得审核人
                                        // 以为自己在批一个叫这名字的可执行文件；
                                        // 主程序也标出来，否则它混在十几条 ldd 依赖
                                        // 里根本认不出来。
                                        text: modelData.isCmdline ? (qsTr("Command line") + ": " + modelData.cmdline) : modelData.isMaster ? (qsTr("Main program") + ": " + (modelData.fileName || "-")) : (modelData.fileName || root.appName || "-")
                                        font.pixelSize: Theme.Typography.body
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
                                        font.pixelSize: Theme.Typography.body
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
                                                color: Theme.Colors.tooltipBackground
                                                radius: 4

                                                Text {
                                                    id: hashTooltipText
                                                    anchors.centerIn: parent
                                                    width: Math.max(0, parent.width - 16)
                                                    text: modelData.fileHash || ""
                                                    font.pixelSize: Theme.Typography.caption
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
                                                        ctx.fillStyle = Theme.Colors.tooltipBackground;
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

                SecondaryButton {
                    text: qsTr("Reject")
                    accent: true
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
