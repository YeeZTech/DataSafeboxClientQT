import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

// 把加密好的 .sealed 文件点对点发给命令行客户端。
//
// 弹窗打开即向信令服务申请一个 6 位取件码并开始等待对端；用户把码告诉对方，
// 对方执行 `dv transfer recv <码>` 后开始点对点直传。传输过程中禁止关闭弹窗，
// 因为关闭意味着中止传输；取消改由进度卡片右上角的中止按钮发起。
BaseDialog {
    id: root
    dialogWidth: 448
    title: qsTr("File Transfer")

    closePolicy: root._active ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    showCloseButton: !root._active

    property string filePath: ""
    property string fileName: {
        if (!root.filePath)
            return "";
        var normalized = root.filePath.replace(/\\/g, "/");
        var idx = normalized.lastIndexOf("/");
        return idx >= 0 ? normalized.substring(idx + 1) : normalized;
    }

    property string _roomCode: ""
    property string _errorText: ""
    property bool _active: false
    property bool _done: false

    // 原始字节数，用于文件大小展示和速度/剩余时间的客户端侧估算（SDK 只给
    // processed/total，不给速度）。失败时保留最后一次进度，不清零。
    property real _processedBytes: 0
    property real _totalBytes: 0
    property real _speedBps: 0
    property real _lastProcessed: -1
    property real _lastTimestamp: 0

    readonly property int _progressPercent: root._totalBytes > 0 ? Math.round(root._processedBytes / root._totalBytes * 100) : 0

    // 待接收/传输中/传输完成/传输中断 四态；SDK 没有"对方拒绝"这个协议概念
    // （接收方是跑 CLI 命令，没有拒绝入口），所以失败一律归为"传输中断"。
    readonly property string _badgeState: {
        if (root._errorText !== "")
            return "interrupted";
        if (root._done)
            return "succeeded";
        if (root._processedBytes > 0)
            return "transferring";
        return "awaiting";
    }

    readonly property color _badgeColor: {
        switch (root._badgeState) {
        case "transferring":
            return "#1447e6";
        case "succeeded":
            return "#008236";
        case "interrupted":
            return "#c10007";
        default:
            return "#e5a609";
        }
    }

    readonly property color _badgeDotColor: root._badgeState === "succeeded" ? "#00c950" : root._badgeColor

    readonly property string _badgeLabel: {
        switch (root._badgeState) {
        case "transferring":
            return qsTr("Transferring");
        case "succeeded":
            return qsTr("Transfer Complete");
        case "interrupted":
            return qsTr("Transfer Interrupted");
        default:
            return qsTr("Awaiting Receipt");
        }
    }

    // 进度百分比文字始终在进度条中点；条从左往右填充，一旦过半就会盖住文字，
    // 此时需要换成白色才看得清。
    readonly property bool _progressTextOnFill: root._progressPercent >= 50

    readonly property string _remainingText: {
        if (root._done)
            return "00:00";
        if (root._badgeState !== "transferring" || root._speedBps <= 0)
            return "--";
        var seconds = Math.round((root._totalBytes - root._processedBytes) / root._speedBps);
        var m = Math.floor(seconds / 60);
        var s = seconds % 60;
        return (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s);
    }

    readonly property string _speedText: {
        if (root._badgeState !== "transferring" || root._speedBps <= 0)
            return "--";
        return (root._speedBps / (1024 * 1024)).toFixed(1) + " MB/s";
    }

    onOpened: {
        root._roomCode = "";
        root._errorText = "";
        root._processedBytes = 0;
        root._totalBytes = 0;
        root._speedBps = 0;
        root._lastProcessed = -1;
        root._lastTimestamp = 0;
        root._done = false;
        root._active = true;
        FileTransferBridge.sendFile(root.filePath);
    }

    onClosed: {
        // 关闭即中止：Cancel 对已完成的传输无副作用。
        if (root._active)
            FileTransferBridge.cancel();
        root._active = false;
    }

    function copyToClipboard(text) {
        codeClipboard.text = text;
        codeClipboard.selectAll();
        codeClipboard.copy();
    }

    Connections {
        target: FileTransferBridge

        function onRoomCodeReady(roomCode) {
            root._roomCode = roomCode;
        }

        function onTransferProgress(processedBytes, totalBytes) {
            var now = Date.now();
            if (root._lastTimestamp > 0 && processedBytes > root._lastProcessed) {
                var deltaSeconds = (now - root._lastTimestamp) / 1000;
                if (deltaSeconds > 0) {
                    var instantSpeed = (processedBytes - root._lastProcessed) / deltaSeconds;
                    root._speedBps = root._speedBps > 0 ? (root._speedBps * 0.7 + instantSpeed * 0.3) : instantSpeed;
                }
            }
            root._lastProcessed = processedBytes;
            root._lastTimestamp = now;
            root._processedBytes = processedBytes;
            root._totalBytes = totalBytes;
        }

        // 参数刻意不叫 filePath，避免遮蔽同名的 root.filePath。
        function onTransferSucceeded(sentPath, totalBytes) {
            root._active = false;
            root._done = true;
            root._totalBytes = totalBytes;
            root._processedBytes = totalBytes;
        }

        function onTransferFailed(message) {
            root._active = false;
            root._done = false;
            root._errorText = message;
        }
    }

    // Hidden TextEdit used as clipboard helper
    TextEdit {
        id: codeClipboard
        visible: false
        readOnly: false
    }

    Column {
        width: parent.width
        spacing: 16

        // ---- 取件码标签 + 状态徽标 ----
        Item {
            width: parent.width
            height: 20

            Text {
                id: pickupCodeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Pickup Code (valid for 1 hour)")
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textCaption
            }

            Row {
                anchors.left: pickupCodeLabel.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    visible: root._badgeState !== "interrupted"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: root._badgeDotColor
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root._badgeState === "interrupted" ? "X " : "") + root._badgeLabel
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: root._badgeColor
                }
            }
        }

        // ---- 取件码格子 ----
        Item {
            width: parent.width
            height: 48

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: 6

                    delegate: Item {
                        width: 50
                        height: 48

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            color: Theme.Colors.primary
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root._roomCode.length > index ? root._roomCode.charAt(index) : ""
                            font.pixelSize: 24
                            font.weight: Font.ExtraBold
                            color: "#1d1d1d"
                        }
                    }
                }
            }

            Image {
                id: copyCodeIcon
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 158
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: "qrc:/icons/icon-copy.svg"
                fillMode: Image.PreserveAspectFit
                opacity: copyCodeArea.containsMouse ? 0.7 : 1.0

                MouseArea {
                    id: copyCodeArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyToClipboard(root._roomCode)
                }
            }
        }

        // ---- 说明文案 ----
        Text {
            width: parent.width
            textFormat: Text.RichText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("The recipient needs to run the following command in the %1 to complete the file transfer.").arg("<span style='color:#0f4c81;font-weight:600;text-decoration:underline;'>" + qsTr("Security Domain Instance") + "</span>")
            font.pixelSize: Theme.Typography.small
            color: Theme.Colors.textCaption
        }

        // ---- 命令行 ----
        Rectangle {
            width: parent.width
            height: 28
            radius: 8
            color: "#38424f"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.RichText
                font.pixelSize: 12
                text: "<span style='color:#9da8b8;'>1&#160;&#160;&#160;</span><span style='color:#f5bd0c;'>dv</span><span style='color:#9da8b8;'>&#160;</span><span style='color:#00c950;'>transfer</span><span style='color:#9da8b8;'>&#160;recv " + root._roomCode + "</span>"
            }

            Image {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: "qrc:/icons/icon-copy-white.svg"
                fillMode: Image.PreserveAspectFit
                opacity: copyCmdArea.containsMouse ? 1.0 : 0.8

                MouseArea {
                    id: copyCmdArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyToClipboard("dv transfer recv " + root._roomCode)
                }
            }
        }

        // ---- 文件进度卡片 ----
        Rectangle {
            width: parent.width
            height: 82
            radius: 10
            color: "#ffffff"
            border.color: "#d9d9d9"
            border.width: 1

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.top: parent.top
                anchors.topMargin: 10
                height: 66

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: root.fileName
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: "#485468"
                    elide: Text.ElideMiddle
                    width: parent.width * 0.6
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: (root._processedBytes > 0 ? Theme.Utils.formatSize(root._processedBytes) : "--") + " / " + (root._totalBytes > 0 ? Theme.Utils.formatSize(root._totalBytes) : "--")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#485468"
                }

                Rectangle {
                    id: progressTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.top: parent.top
                    anchors.topMargin: 25
                    height: 9
                    radius: height / 2
                    color: "#d9d9d9"

                    Rectangle {
                        width: parent.width * (root._progressPercent / 100)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.Colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root._progressPercent + "%"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root._progressTextOnFill ? "#ffffff" : "#485468"
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: progressTrack.bottom
                    anchors.topMargin: 3
                    text: qsTr("Remaining %1").arg(root._remainingText)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#485468"
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: progressTrack.bottom
                    anchors.topMargin: 3
                    text: qsTr("Download Speed %1").arg(root._speedText)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#485468"
                }
            }

            // 中止入口：只在真的有传输可中止时露出（传输中）。
            Image {
                visible: root._badgeState === "transferring"
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.top: parent.top
                anchors.topMargin: 32
                width: 15
                height: 15
                source: "qrc:/icons/icon-transfer-cancel.svg"
                fillMode: Image.PreserveAspectFit
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FileTransferBridge.cancel()
                }
            }
        }

        Text {
            width: parent.width
            visible: root._errorText !== ""
            text: root._errorText
            font.pixelSize: Theme.Typography.caption
            color: "#dc2626"
            wrapMode: Text.WordWrap
        }
    }
}
