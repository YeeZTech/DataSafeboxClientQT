import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import "FileUtils.js" as FileUtils

BaseDialog {
    id: root
    dialogWidth: 500
    title: qsTr("Encrypt Files to This Security Domain")
    closePolicy: root._encrypting ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    showCloseButton: !root._encrypting
    onCloseRequested: cancelClicked()

    signal encryptionStateChanged(bool encrypting)

    // Result popups are exposed so the host page can include them in its scoped
    // dim backdrop (they open after this dialog closes; see instantiation below).
    property alias successPopup: encryptSuccessPopup
    property alias failurePopup: encryptFailurePopup

    // Properties (backward compatible)
    property string selectedFilePath: ""
    property string selectedOutputPath: ""
    property string domainName: ""
    property string domainPubKey: ""
    // 安全域已停用（已关闭/创建失败）：弹窗正常打开，但"加密文件"按钮置灰并提示 (PRD 3.3)
    property bool domainInactive: false

    // Encryption queue state
    property var _encryptQueue: []       // [{file, modelIndex}]
    property int _encryptTotal: 0
    property int _encryptDone: 0
    property int _encryptFailed: 0
    property string _currentPubKey: ""
    property int _currentOperationId: -1
    property string _currentSourceFile: ""
    property string _currentTargetFile: ""
    property int _currentModelIndex: -1  // model index of item being encrypted
    property bool _encrypting: false
    property bool _retrying: false
    property int _encryptProgress: 0
    property bool _encryptProgressDismissed: false
    property string _resultMessage: ""
    property string _resultType: "" // "success" | "error"
    property string _lastErrorMessage: ""
    property string _encryptOutputDir: ""

    // Count helpers
    readonly property int _pendingCount: {
        var c = 0;
        for (var i = 0; i < pathListModel.count; i++) {
            var s = pathListModel.get(i).status;
            if (s === "pending" || s === "failed")
                c++;
        }
        return c;
    }
    readonly property int _encryptedCount: {
        var c = 0;
        for (var i = 0; i < pathListModel.count; i++) {
            if (pathListModel.get(i).status === "encrypted")
                c++;
        }
        return c;
    }

    onOpened: {
        if (_retrying) {
            _retrying = false;
            Qt.callLater(startEncryption);
            return;
        }
        selectedFilePath = "";
        selectedOutputPath = "";
        _encryptQueue = [];
        _encryptTotal = 0;
        _encryptDone = 0;
        _encryptFailed = 0;
        _encryptProgress = 0;
        _encrypting = false;
        _encryptProgressDismissed = true;
        _resultMessage = "";
        _resultType = "";
        _currentOperationId = -1;
        _currentSourceFile = "";
        _currentTargetFile = "";
        _currentModelIndex = -1;
        pathListModel.clear();
        encryptionStateChanged(false);
    }

    // ---- Helper functions ----

    // Find path in model, returns index or -1
    function _findPathInModel(p) {
        for (var i = 0; i < pathListModel.count; i++) {
            if (pathListModel.get(i).path === p)
                return i;
        }
        return -1;
    }

    // Update model item status by model index
    // For folder items: if all expanded files are done, mark folder as encrypted
    function _markModelItemStatus(modelIdx, status) {
        if (modelIdx < 0 || modelIdx >= pathListModel.count)
            return;
        // For folder items, track via _folderFileMap
        var item = pathListModel.get(modelIdx);
        if (item.isDir) {
            // folder: update internal tracking and set status when all files done
            if (!root._folderDoneMap)
                root._folderDoneMap = {};
            var key = modelIdx.toString();
            if (!root._folderDoneMap[key])
                root._folderDoneMap[key] = {
                    total: 0,
                    done: 0,
                    failed: 0
                };
            root._folderDoneMap[key].done++;
            if (status === "failed")
                root._folderDoneMap[key].failed++;
            if (root._folderDoneMap[key].done >= root._folderDoneMap[key].total) {
                pathListModel.setProperty(modelIdx, "status", root._folderDoneMap[key].failed > 0 ? "failed" : "encrypted");
            }
        } else {
            pathListModel.setProperty(modelIdx, "status", status);
        }
    }
    property var _folderDoneMap: ({})

    // Tooltip hover tracking
    property bool _tooltipVisible: false
    property string _tooltipText: ""
    property real _tooltipMouseX: 0
    property real _tooltipMouseY: 0
    property real _tooltipBoxX: 0
    property real _tooltipBoxW: 0

    function addPaths(paths) {
        if (root._encrypting)
            return;
        root._encryptProgressDismissed = true;
        root._resultMessage = "";
        var duplicates = [];
        for (var i = 0; i < paths.length; i++) {
            var p = paths[i];
            var existingIdx = _findPathInModel(p);
            if (existingIdx >= 0) {
                var existingStatus = pathListModel.get(existingIdx).status;
                if (existingStatus === "encrypted") {
                    duplicates.push(FileUtils.getFileName(p) + qsTr(" (encrypted)"));
                } else {
                    duplicates.push(FileUtils.getFileName(p) + qsTr(" (already in list)"));
                }
                continue;
            }
            pathListModel.append({
                "path": p,
                "name": FileUtils.getFileName(p),
                "isDir": FileUtils.isDirectory(p),
                "status": "pending"  // pending | encrypted | failed
            });
        }
        // Backward compat
        if (pathListModel.count > 0) {
            root.selectedFilePath = pathListModel.get(pathListModel.count - 1).path;
        }
        // Show duplicate warning
        if (duplicates.length > 0) {
            duplicateDialog.text = duplicates.join("\n");
            duplicateDialog.open();
        }
    }

    function removePath(index) {
        if (root._encrypting)
            return;
        root._encryptProgressDismissed = true;
        root._resultMessage = "";
        if (index < 0 || index >= pathListModel.count)
            return;
        pathListModel.remove(index);
        root.selectedFilePath = pathListModel.count > 0 ? pathListModel.get(0).path : "";
    }

    function _operationMatches(operationId, sourceFile, targetFile) {
        if (root._currentSourceFile !== sourceFile || root._currentTargetFile !== targetFile) {
            return false;
        }
        return root._currentOperationId < 0 || root._currentOperationId === operationId;
    }

    function _finishEncryptionQueue() {
        root._encrypting = false;
        root.encryptionStateChanged(false);
        root._currentOperationId = -1;
        root._currentSourceFile = "";
        root._currentTargetFile = "";
        root._currentModelIndex = -1;
        root._encryptProgress = 100;
        root._encryptProgressDismissed = false;
        // Determine output directory
        var outDir = root.selectedOutputPath;
        if (!outDir && root.selectedFilePath)
            outDir = FileUtils.getFileDir(root.selectedFilePath);
        root._encryptOutputDir = outDir || "";
        if (root._encryptFailed === 0) {
            root._resultMessage = "";
            root._resultType = "success";
            root.close();
            encryptSuccessPopup.open();
        } else if (root._encryptFailed < root._encryptTotal) {
            root._resultMessage = qsTr("Partially completed: %1 succeeded, %2 failed").arg(root._encryptTotal - root._encryptFailed).arg(root._encryptFailed);
            root._resultType = "warning";
            root.close();
            encryptFailurePopup.errorText = root._lastErrorMessage || root._resultMessage;
            encryptFailurePopup.open();
        } else {
            root._resultMessage = "";
            root._resultType = "error";
            root.close();
            encryptFailurePopup.errorText = root._lastErrorMessage || qsTr("Encryption failed");
            encryptFailurePopup.open();
        }
    }

    function _beginNextEncryption() {
        if (root._encryptQueue.length === 0) {
            root._finishEncryptionQueue();
            return;
        }
        var queue = root._encryptQueue;
        var next = queue.shift();
        root._encryptQueue = queue;
        var targetFile = DsccBridge.encryptedTargetFilePath(next.file, root.selectedOutputPath);
        if (!targetFile) {
            root._markModelItemStatus(next.modelIndex, "failed");
            root._encryptDone++;
            root._encryptFailed++;
            root._resultMessage = qsTr("Failed to generate encrypted file save path");
            root._resultType = "error";
            root._beginNextEncryption();
            return;
        }
        root._currentOperationId = -1;
        root._currentSourceFile = next.file;
        root._currentTargetFile = targetFile;
        root._currentModelIndex = next.modelIndex;
        root._encryptProgress = Math.round((root._encryptDone / Math.max(1, root._encryptTotal)) * 100);
        DsccBridge.encryptFile(next.file, targetFile, root._currentPubKey);
    }

    function _completeCurrentEncryption(status, message) {
        root._markModelItemStatus(root._currentModelIndex, status);
        root._encryptDone++;
        if (status !== "encrypted") {
            root._encryptFailed++;
            root._resultMessage = message || qsTr("Encryption failed");
            root._lastErrorMessage = root._resultMessage;
            root._resultType = "error";
        }
        root._currentOperationId = -1;
        root._currentSourceFile = "";
        root._currentTargetFile = "";
        root._currentModelIndex = -1;
        root._beginNextEncryption();
    }

    function _startEncryptionWithBridge() {
        if (root._encrypting)
            return;
        for (var r = 0; r < pathListModel.count; r++) {
            if (pathListModel.get(r).status === "failed") {
                pathListModel.setProperty(r, "status", "pending");
            }
        }
        var pubKey = root.domainPubKey || "";
        if (!pubKey) {
            root._resultMessage = qsTr("Security domain public key not found");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }
        var queue = [];
        for (var i = 0; i < pathListModel.count; i++) {
            var item = pathListModel.get(i);
            if (item.status !== "pending")
                continue;
            if (item.isDir) {
                pathListModel.setProperty(i, "status", "failed");
                continue;
            }
            queue.push({
                file: item.path,
                modelIndex: i
            });
        }
        if (queue.length === 0) {
            root._resultMessage = qsTr("No files to encrypt");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }
        root._currentPubKey = pubKey;
        root._encryptQueue = queue;
        root._encryptTotal = queue.length;
        root._encryptDone = 0;
        root._encryptFailed = 0;
        root._encryptProgress = 0;
        root._encrypting = true;
        root.encryptionStateChanged(true);
        root._encryptProgressDismissed = false;
        root._resultMessage = "";
        root._resultType = "";
        root._currentOperationId = -1;
        root._currentSourceFile = "";
        root._currentTargetFile = "";
        root._currentModelIndex = -1;
        root._beginNextEncryption();
    }

    function startEncryption() {
        root._startEncryptionWithBridge();
        return;
        // Reset failed items to pending for re-encryption
        for (var r = 0; r < pathListModel.count; r++) {
            if (pathListModel.get(r).status === "failed") {
                pathListModel.setProperty(r, "status", "pending");
            }
        }
        // Collect only pending items
        var pendingItems = [];
        for (var i = 0; i < pathListModel.count; i++) {
            var item = pathListModel.get(i);
            if (item.status === "pending") {
                pendingItems.push({
                    path: item.path,
                    isDir: item.isDir,
                    modelIndex: i
                });
            }
        }
        if (pendingItems.length === 0) {
            root._resultMessage = qsTr("No files to encrypt");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }

        // Resolve pubKey
        var pubKey = root.domainPubKey || "";
        if (!pubKey || pubKey === "") {
            // empty stub: show error when public key unavailable
            root._resultMessage = qsTr("Security domain public key not found");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }
        if (!pubKey || pubKey === "") {
            root._resultMessage = qsTr("Security domain public key not found");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }

        // Build file queue: expand folders, preserve per-item output path
        var queue = [];
        root._folderDoneMap = {};
        for (var j = 0; j < pendingItems.length; j++) {
            var pi = pendingItems[j];
            if (pi.isDir) {
                var files = FileUtils.listFilesRecursive(pi.path);
                if (files.length === 0) {
                    pathListModel.setProperty(pi.modelIndex, "status", "failed");
                    continue;
                }
                var normalizedSource = pi.path.replace(/\\/g, "/").replace(/\/+$/, "");
                var normalizedCustom = root.selectedOutputPath ? root.selectedOutputPath.replace(/\\/g, "/").replace(/\/+$/, "") : "";
                var folderName = FileUtils.getFileName(normalizedSource);
                var folderBaseOutput = "";
                if (normalizedCustom && normalizedCustom !== normalizedSource) {
                    folderBaseOutput = normalizedCustom + "/" + folderName;
                } else {
                    var folderParent = FileUtils.getFileDir(normalizedSource);
                    folderBaseOutput = folderParent + "/" + folderName + "_encrypted";
                }
                root._folderDoneMap[pi.modelIndex.toString()] = {
                    total: files.length,
                    done: 0,
                    failed: 0
                };
                for (var k = 0; k < files.length; k++) {
                    var fileFullPath = files[k].replace(/\\/g, "/");
                    var relativePath = fileFullPath.substring(normalizedSource.length + 1);
                    var relativeDir = FileUtils.getFileDir(relativePath);
                    var fileOutput = relativeDir ? (folderBaseOutput + "/" + relativeDir) : folderBaseOutput;
                    queue.push({
                        file: files[k],
                        output: fileOutput,
                        modelIndex: pi.modelIndex
                    });
                }
            } else {
                var fileOut = root.selectedOutputPath || FileUtils.getFileDir(pi.path);
                queue.push({
                    file: pi.path,
                    output: fileOut,
                    modelIndex: pi.modelIndex
                });
            }
        }
        if (queue.length === 0) {
            root._resultMessage = qsTr("No encryptable files found");
            root._resultType = "error";
            root._encryptProgressDismissed = false;
            return;
        }
        root._currentPubKey = pubKey;
        root._encryptTotal = queue.length;
        root._encryptDone = 0;
        root._encryptFailed = 0;
        root._encryptProgress = 0;
        root._encrypting = true;
        root._encryptProgressDismissed = false;
        root._resultMessage = "";
        root._resultType = "";
        var first = queue.shift();
        root._encryptQueue = queue;
        root._currentModelIndex = first.modelIndex;
        // 空实现：模拟加密完成
        root._encrypting = false;
        root._encryptDone = root._encryptTotal;
        root._encryptProgress = 100;
        root._encryptProgressDismissed = false;
        root._resultMessage = qsTr("Function disabled");
        root._resultType = "error";
    }

    // ---- Dialogs ----

    FileDialog {
        id: fileDialog
        title: qsTr("Select File")
        fileMode: FileDialog.OpenFile

        onAccepted: {
            var paths = [];
            if (fileDialog.files && fileDialog.files.length > 0) {
                for (var i = 0; i < fileDialog.files.length; i++) {
                    paths.push(FileUtils.urlToLocalPath(fileDialog.files[i], Qt.platform.os));
                }
            } else if (fileDialog.file) {
                paths.push(FileUtils.urlToLocalPath(fileDialog.file, Qt.platform.os));
            }
            root.addPaths(paths);
        }
    }

    FolderDialog {
        id: folderSelectDialog
        title: qsTr("Select Folder")

        onAccepted: {
            var folderPath = FileUtils.urlToLocalPath(folderSelectDialog.folder, Qt.platform.os);
            if (folderPath)
                root.addPaths([folderPath]);
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Select Save Path")

        onAccepted: {
            root.selectedOutputPath = FileUtils.urlToLocalPath(folderDialog.folder, Qt.platform.os);
        }
    }

    ListModel {
        id: pathListModel
    }

    Connections {
        target: DsccBridge

        function onEncryptFileStarted(operationId, sourceFile, targetFile) {
            if (root._currentSourceFile === sourceFile && root._currentTargetFile === targetFile) {
                root._currentOperationId = operationId;
            }
        }

        function onEncryptFileProgress(operationId, sourceFile, targetFile, processedBytes, totalBytes) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile))
                return;
            var currentRatio = totalBytes > 0 ? (processedBytes / totalBytes) : 0;
            currentRatio = Math.max(0, Math.min(1, currentRatio));
            var overallRatio = (root._encryptDone + currentRatio) / Math.max(1, root._encryptTotal);
            root._encryptProgress = Math.round(Math.max(0, Math.min(1, overallRatio)) * 100);
        }

        function onEncryptFileSucceeded(operationId, sourceFile, targetFile) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile))
                return;
            root._completeCurrentEncryption("encrypted", "");
        }

        function onEncryptFileFailed(operationId, sourceFile, targetFile, notification) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile))
                return;
            root._completeCurrentEncryption("failed", FileUtils.formatEncryptFailure(notification, qsTr("Encryption failed"), function (n, fallback) {
                if (typeof DsccBridge !== "undefined" && DsccBridge.notificationMessage)
                    return DsccBridge.notificationMessage(n, fallback);
                return fallback;
            }));
        }

        function onEncryptFileCanceled(operationId, sourceFile, targetFile) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile))
                return;
            root._completeCurrentEncryption("failed", qsTr("Encryption cancelled"));
        }
    }

    // ---- Main content ----
    Column {
        id: contentColumn
        width: parent.width
        spacing: 16

        EncryptFileSelector {
            label: qsTr("Files to Encrypt")
            required: true
            displayText: root.selectedFilePath
            placeholder: qsTr("Please select files to encrypt")
            hasValue: root.selectedFilePath !== ""
            selectorEnabled: !root._encrypting
            onSelectClicked: fileDialog.open()
        }

        EncryptFileSelector {
            label: qsTr("Save Path for Encrypted Files")
            displayText: root.selectedOutputPath ? root.selectedOutputPath : (root.selectedFilePath ? FileUtils.getFileDir(root.selectedFilePath) : "")
            placeholder: qsTr("Select save path")
            hasValue: root.selectedOutputPath !== "" || root.selectedFilePath !== ""
            selectorEnabled: !root._encrypting
            showClearButton: root.selectedOutputPath !== ""
            onSelectClicked: folderDialog.open()
            onClearClicked: root.selectedOutputPath = ""
        }

        // ---- Inline progress bar ----
        Column {
            width: parent.width
            spacing: 6
            visible: root._encrypting || ((root._encryptProgress > 0 || root._resultMessage !== "") && !root._encryptProgressDismissed)

            Row {
                width: parent.width
                Text {
                    text: root._encrypting ? (root._encryptTotal > 1 ? qsTr("Encrypting (") + (root._encryptDone + 1) + "/" + root._encryptTotal + ")" : qsTr("Encrypting...")) : (root._resultType === "error" ? qsTr("Encryption failed") : root._resultType === "warning" ? qsTr("Partially completed") : qsTr("Encryption completed"))
                    font.pixelSize: Theme.Typography.small
                    font.weight: Font.Medium
                    color: root._encrypting ? Theme.Colors.textLabel : (root._resultType === "error" ? "#ef4444" : root._resultType === "warning" ? "#f59e0b" : "#22c55e")
                }
                Item {
                    width: parent.width - parent.children[0].width - parent.children[2].width
                    height: 1
                }
                Text {
                    text: root._encrypting ? root._encryptProgress + "%" : ""
                    font.pixelSize: Theme.Typography.small
                    color: Theme.Colors.textCaption
                }
            }

            ProgressBar {
                id: inlineProgressBar
                width: parent.width
                from: 0
                to: 100
                value: root._encryptProgress

                background: Rectangle {
                    implicitWidth: inlineProgressBar.width
                    implicitHeight: 6
                    radius: 3
                    color: Theme.Colors.borderSeparator
                }

                contentItem: Item {
                    implicitWidth: inlineProgressBar.width
                    implicitHeight: 6

                    Rectangle {
                        width: inlineProgressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: root._resultType === "error" ? "#ef4444" : root._resultType === "warning" ? "#f59e0b" : "#22c55e"
                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                }
                                GradientStop {
                                    position: 0.5
                                    color: "transparent"
                                }
                            }
                        }
                    }
                }
            }

            // Result message
            Text {
                width: parent.width
                visible: !root._encrypting && root._resultMessage !== ""
                text: root._resultMessage
                font.pixelSize: Theme.Typography.small
                color: root._resultType === "error" ? "#ef4444" : Theme.Colors.textLabel
                wrapMode: Text.WrapAnywhere
            }
        }

        // Footer buttons
        Row {
            anchors.right: parent.right
            spacing: 8

            SecondaryButton {
                text: qsTr("Cancel")
                enabled: !root._encrypting
                accent: true
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }

            PrimaryButton {
                text: qsTr("Encrypt Files")
                inactive: root.domainInactive
                disabledTooltipText: qsTr("Security domain is deactivated, this operation is not supported")
                // Stay enabled (Item-level) while inactive so the hover tooltip works; `inactive` handles the grayed look.
                enabled: root.domainInactive || (root._pendingCount > 0 && !root._encrypting)
                onClicked: root.startEncryption()
            }
        }
    }

    // ---- Duplicate warning dialog ----
    Popup {
        id: duplicateDialog
        width: 380
        height: duplicateContent.implicitHeight + 40
        modal: true
        x: (parent ? (parent.width - width) / 2 : 0)
        y: (parent ? (parent.height - height) / 2 : 0)

        property string text: ""

        background: Rectangle {
            radius: 10
            color: Theme.Colors.backgroundWhite
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1
        }

        Column {
            id: duplicateContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            SelectableText {
                width: parent.width
                text: qsTr("The following files are already in the list")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            SelectableText {
                width: parent.width
                text: duplicateDialog.text
                font.pixelSize: Theme.Typography.caption
                color: Theme.Colors.textLabel
                wrapMode: TextEdit.Wrap
            }

            Row {
                anchors.right: parent.right

                Rectangle {
                    width: 60
                    height: 32
                    radius: 8
                    color: Theme.Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Got it")
                        font.pixelSize: Theme.Typography.caption
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: duplicateDialog.close()
                    }
                }
            }
        }
    }

    // ---- Floating path tooltip (hash-style, above mouse) ----
    Popup {
        id: floatingTooltip
        parent: root.contentItem
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 0
        visible: root._tooltipVisible
        z: 99999

        readonly property real bubbleWidth: root._tooltipBoxW
        readonly property real aboveMouseY: root._tooltipMouseY - ftBubble.height - 14
        readonly property real arrowOffsetX: Math.max(6, Math.min(bubbleWidth - 16, root._tooltipMouseX - root._tooltipBoxX - 5))

        x: root._tooltipBoxX
        y: aboveMouseY

        background: Item {
            Rectangle {
                id: ftBubble
                width: floatingTooltip.bubbleWidth
                height: Math.max(28, ftText.implicitHeight + 10)
                color: Theme.Colors.tooltipBackground
                radius: 4

                Text {
                    id: ftText
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 16)
                    text: root._tooltipText
                    font.pixelSize: Theme.Typography.caption
                    color: "white"
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignHCenter
                }

                Canvas {
                    width: 10
                    height: 5
                    anchors.top: parent.bottom
                    x: floatingTooltip.arrowOffsetX
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

    EncryptSuccessPopup {
        id: encryptSuccessPopup
        parent: root.parent  // host page → page-scoped dim via the page's backdrop
        dim: false
        encryptOutputDir: root._encryptOutputDir
    }

    EncryptFailurePopup {
        id: encryptFailurePopup
        parent: root.parent  // host page → page-scoped dim via the page's backdrop
        dim: false

        onRetryRequested: {
            root._retrying = true;
            root.open();
        }

        onContactSupportRequested: root.contactSupportRequested()
    }
    // Signals
    signal cancelClicked
    signal encryptClicked
    signal contactSupportRequested
}
