import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

// 把加密好的 .sealed 文件点对点发给命令行客户端。
//
// 弹窗打开即向信令服务申请一个 6 位取件码并开始等待对端；用户把码告诉对方，
// 对方执行 `dv transfer recv <码>` 后开始点对点直传。传输过程中禁止关闭弹窗，
// 因为关闭意味着中止传输。
BaseDialog {
    id: root
    dialogWidth: 480
    title: qsTr("Send to Command Line Client")

    // 传输进行中不允许误关；用户要中止得走"取消传输"按钮。
    closePolicy: root._active ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    showCloseButton: !root._active
    // 关闭动作统一在 onClosed 里收尾（BaseDialog 的关闭按钮自己会调 close()）。

    property string filePath: ""
    property string fileName: {
        if (!root.filePath)
            return "";
        var normalized = root.filePath.replace(/\\/g, "/");
        var idx = normalized.lastIndexOf("/");
        return idx >= 0 ? normalized.substring(idx + 1) : normalized;
    }

    property string _roomCode: ""
    property string _stageText: ""
    property string _errorText: ""
    property int _progress: 0
    property bool _active: false
    property bool _done: false

    onOpened: {
        root._roomCode = "";
        root._stageText = "";
        root._errorText = "";
        root._progress = 0;
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

    Connections {
        target: FileTransferBridge

        function onRoomCodeReady(roomCode) {
            root._roomCode = roomCode;
        }

        function onStageChanged(stageText) {
            root._stageText = stageText;
        }

        function onTransferProgress(processedBytes, totalBytes) {
            if (totalBytes > 0)
                root._progress = Math.round(Math.max(0, Math.min(1, processedBytes / totalBytes)) * 100);
        }

        // 参数刻意不叫 filePath，避免遮蔽同名的 root.filePath。
        function onTransferSucceeded(sentPath, totalBytes) {
            root._active = false;
            root._done = true;
            root._progress = 100;
            root._stageText = qsTr("Transfer complete");
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

        Text {
            width: parent.width
            text: qsTr("File: %1").arg(root.fileName)
            font.pixelSize: Theme.Typography.body
            color: Theme.Colors.textHeading
            elide: Text.ElideMiddle
        }

        // ---- 取件码 ----
        Rectangle {
            width: parent.width
            height: 96
            radius: 8
            color: "#f1f5f9"
            border.color: Qt.rgba(0, 0, 0, 0.08)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Pickup Code")
                    font.pixelSize: Theme.Typography.caption
                    color: "#45556c"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root._roomCode !== "" ? root._roomCode : "······"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    font.letterSpacing: 6
                    font.family: "monospace"
                    color: root._roomCode !== "" ? Theme.Colors.textHeading : "#94a3b8"
                }
            }

            LinkText {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                visible: root._roomCode !== ""
                text: qsTr("Copy")
                onClicked: {
                    codeClipboard.text = root._roomCode;
                    codeClipboard.selectAll();
                    codeClipboard.copy();
                }
            }

        }

        Text {
            width: parent.width
            text: qsTr("On the target machine, run: dv transfer recv %1").arg(root._roomCode !== "" ? root._roomCode : "<code>")
            font.pixelSize: Theme.Typography.caption
            font.family: "monospace"
            color: "#45556c"
            wrapMode: Text.WrapAnywhere
        }

        Text {
            width: parent.width
            text: qsTr("The pickup code is valid for 1 hour and can only be used once. File contents are transferred peer-to-peer and never pass through the server.")
            font.pixelSize: Theme.Typography.caption
            color: "#64748b"
            wrapMode: Text.WordWrap
        }

        // ---- 进度 ----
        Column {
            width: parent.width
            spacing: 6
            visible: root._errorText === ""

            Text {
                text: root._done ? qsTr("Transfer complete") : root._stageText
                font.pixelSize: Theme.Typography.caption
                color: "#45556c"
                visible: text !== ""
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: "#e2e8f0"
                visible: root._progress > 0 || root._done

                Rectangle {
                    width: parent.width * (root._progress / 100)
                    height: parent.height
                    radius: parent.radius
                    color: root._done ? "#16a34a" : Theme.Colors.textHeading

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }
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

        Row {
            anchors.right: parent.right
            spacing: 8
            topPadding: 4

            SecondaryButton {
                visible: root._active
                text: qsTr("Cancel Transfer")
                onClicked: {
                    FileTransferBridge.cancel();
                    root._active = false;
                }
            }

            PrimaryButton {
                visible: !root._active
                text: qsTr("Close")
                onClicked: root.close()
            }
        }
    }
}
