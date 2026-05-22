import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1
import "." as Theme

Popup {
    id: root

    signal encryptionStateChanged(bool encrypting)

    width: 500
    height: Math.min(contentColumn.implicitHeight + 48 + 48 + 36, 560)
    modal: true
    closePolicy: root._encrypting ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    background: null
    padding: 0

    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    // Properties (backward compatible)
    property string selectedFilePath: ""
    property string selectedOutputPath: ""
    property string domainName: ""
    property string domainPubKey: ""

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
    property int _encryptProgress: 0
    property bool _encryptProgressDismissed: false
    property string _resultMessage: ""
    property string _resultType: "" // "success" | "error"

    // Count helpers
    readonly property int _pendingCount: {
        var c = 0
        for (var i = 0; i < pathListModel.count; i++) {
            var s = pathListModel.get(i).status
            if (s === "pending" || s === "failed") c++
        }
        return c
    }
    readonly property int _encryptedCount: {
        var c = 0
        for (var i = 0; i < pathListModel.count; i++) {
            if (pathListModel.get(i).status === "encrypted") c++
        }
        return c
    }

    onOpened: {
        selectedFilePath = ""
        selectedOutputPath = ""
        _encryptQueue = []
        _encryptTotal = 0
        _encryptDone = 0
        _encryptFailed = 0
        _encryptProgress = 0
        _encrypting = false
        _encryptProgressDismissed = true
        _resultMessage = ""
        _resultType = ""
        _currentOperationId = -1
        _currentSourceFile = ""
        _currentTargetFile = ""
        _currentModelIndex = -1
        pathListModel.clear()
        encryptionStateChanged(false)
    }

    // ---- Helper functions ----
    function getFileName(filePath) {
        if (!filePath) return ""
        var parts = filePath.split(/[/\\]/)
        return parts[parts.length - 1]
    }

    // 检查路径是否为目录（空实现，返回 false）
    function _isDirectory(path) {
        return false
    }

    // 递归列出目录下所有文件（空实现，返回空数组）
    function _listFilesRecursive(dirPath) {
        return []
    }

    function getFileDir(filePath) {
        if (!filePath) return ""
        var parts = filePath.replace(/\\/g, "/").split("/")
        parts.pop()
        return parts.join("/")
    }

    function urlToLocalPath(fileUrl) {
        if (typeof fileUrl.toLocalFile === "function") {
            return fileUrl.toLocalFile()
        }
        var urlString = fileUrl.toString()
        if (urlString.startsWith("file:///")) {
            var path = urlString.substring(8)
            if (Qt.platform.os === "windows" && path.length > 0 && path[0] === '/') {
                path = path.substring(1)
            }
            return path
        } else if (urlString.startsWith("file://")) {
            return urlString.substring(7)
        } else if (urlString.startsWith("file:/")) {
            var p2 = urlString.substring(6)
            if (Qt.platform.os === "windows" && p2.length > 0 && p2[0] === '/') {
                p2 = p2.substring(1)
            }
            return p2
        }
        return urlString
    }

    // Find path in model, returns index or -1
    function _findPathInModel(p) {
        for (var i = 0; i < pathListModel.count; i++) {
            if (pathListModel.get(i).path === p) return i
        }
        return -1
    }

    // Update model item status by model index
    // For folder items: if all expanded files are done, mark folder as encrypted
    function _markModelItemStatus(modelIdx, status) {
        if (modelIdx < 0 || modelIdx >= pathListModel.count) return
        // For folder items, track via _folderFileMap
        var item = pathListModel.get(modelIdx)
        if (item.isDir) {
            // folder: update internal tracking and set status when all files done
            if (!root._folderDoneMap) root._folderDoneMap = {}
            var key = modelIdx.toString()
            if (!root._folderDoneMap[key]) root._folderDoneMap[key] = { total: 0, done: 0, failed: 0 }
            root._folderDoneMap[key].done++
            if (status === "failed") root._folderDoneMap[key].failed++
            if (root._folderDoneMap[key].done >= root._folderDoneMap[key].total) {
                pathListModel.setProperty(modelIdx, "status",
                    root._folderDoneMap[key].failed > 0 ? "failed" : "encrypted")
            }
        } else {
            pathListModel.setProperty(modelIdx, "status", status)
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
        if (root._encrypting) return
        root._encryptProgressDismissed = true
        root._resultMessage = ""
        var duplicates = []
        for (var i = 0; i < paths.length; i++) {
            var p = paths[i]
            var existingIdx = _findPathInModel(p)
            if (existingIdx >= 0) {
                var existingStatus = pathListModel.get(existingIdx).status
                if (existingStatus === "encrypted") {
                    duplicates.push(getFileName(p) + qsTr(" (encrypted)"))
                } else {
                    duplicates.push(getFileName(p) + qsTr(" (already in list)"))
                }
                continue
            }
            pathListModel.append({
                "path": p,
                "name": getFileName(p),
                "isDir": _isDirectory(p),
                "status": "pending"  // pending | encrypted | failed
            })
        }
        // Backward compat
        if (pathListModel.count > 0) {
            root.selectedFilePath = pathListModel.get(0).path
        }
        // Show duplicate warning
        if (duplicates.length > 0) {
            duplicateDialog.text = duplicates.join("\n")
            duplicateDialog.open()
        }
    }

    function removePath(index) {
        if (root._encrypting) return
        root._encryptProgressDismissed = true
        root._resultMessage = ""
        if (index < 0 || index >= pathListModel.count) return
        pathListModel.remove(index)
        root.selectedFilePath = pathListModel.count > 0 ? pathListModel.get(0).path : ""
    }

    function _formatEncryptFailure(notification, fallback) {
        if (typeof DsccBridge !== "undefined" && DsccBridge.notificationMessage) {
            var message = DsccBridge.notificationMessage(notification, fallback)
            if (message) return message
        }
        return fallback
    }

    function _operationMatches(operationId, sourceFile, targetFile) {
        if (root._currentSourceFile !== sourceFile || root._currentTargetFile !== targetFile) {
            return false
        }
        return root._currentOperationId < 0 || root._currentOperationId === operationId
    }

    function _finishEncryptionQueue() {
        root._encrypting = false
        root.encryptionStateChanged(false)
        root._currentOperationId = -1
        root._currentSourceFile = ""
        root._currentTargetFile = ""
        root._currentModelIndex = -1
        root._encryptProgress = 100
        root._encryptProgressDismissed = false

        if (root._encryptFailed === 0) {
            root._resultMessage = ""
            root._resultType = "success"
        } else if (root._encryptFailed < root._encryptTotal) {
            root._resultMessage = qsTr("Partially completed: %1 succeeded, %2 failed")
                .arg(root._encryptTotal - root._encryptFailed)
                .arg(root._encryptFailed)
            root._resultType = "warning"
        } else {
            root._resultMessage = ""
            root._resultType = "error"
        }
    }

    function _beginNextEncryption() {
        if (root._encryptQueue.length === 0) {
            root._finishEncryptionQueue()
            return
        }

        var queue = root._encryptQueue
        var next = queue.shift()
        root._encryptQueue = queue

        var targetFile = DsccBridge.encryptedTargetFilePath(next.file, root.selectedOutputPath)
        if (!targetFile) {
            root._markModelItemStatus(next.modelIndex, "failed")
            root._encryptDone++
            root._encryptFailed++
            root._resultMessage = qsTr("Failed to generate encrypted file output path")
            root._resultType = "error"
            root._beginNextEncryption()
            return
        }

        root._currentOperationId = -1
        root._currentSourceFile = next.file
        root._currentTargetFile = targetFile
        root._currentModelIndex = next.modelIndex
        root._encryptProgress = Math.round((root._encryptDone / Math.max(1, root._encryptTotal)) * 100)

        DsccBridge.encryptFile(next.file, targetFile, root._currentPubKey)
    }

    function _completeCurrentEncryption(status, message) {
        root._markModelItemStatus(root._currentModelIndex, status)
        root._encryptDone++
        if (status !== "encrypted") {
            root._encryptFailed++
            root._resultMessage = message || qsTr("Encryption failed")
            root._resultType = "error"
        }

        root._currentOperationId = -1
        root._currentSourceFile = ""
        root._currentTargetFile = ""
        root._currentModelIndex = -1
        root._beginNextEncryption()
    }

    function _startEncryptionWithBridge() {
        if (root._encrypting) return

        for (var r = 0; r < pathListModel.count; r++) {
            if (pathListModel.get(r).status === "failed") {
                pathListModel.setProperty(r, "status", "pending")
            }
        }

        var pubKey = root.domainPubKey || ""
        if (!pubKey) {
            root._resultMessage = qsTr("Security domain public key not found")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }

        var queue = []
        for (var i = 0; i < pathListModel.count; i++) {
            var item = pathListModel.get(i)
            if (item.status !== "pending") continue
            if (item.isDir) {
                pathListModel.setProperty(i, "status", "failed")
                continue
            }
            queue.push({ file: item.path, modelIndex: i })
        }

        if (queue.length === 0) {
            root._resultMessage = qsTr("No files to encrypt")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }

        root._currentPubKey = pubKey
        root._encryptQueue = queue
        root._encryptTotal = queue.length
        root._encryptDone = 0
        root._encryptFailed = 0
        root._encryptProgress = 0
        root._encrypting = true
        root.encryptionStateChanged(true)
        root._encryptProgressDismissed = false
        root._resultMessage = ""
        root._resultType = ""
        root._currentOperationId = -1
        root._currentSourceFile = ""
        root._currentTargetFile = ""
        root._currentModelIndex = -1

        root._beginNextEncryption()
    }

    function startEncryption() {
        root._startEncryptionWithBridge()
        return
        // Reset failed items to pending for re-encryption
        for (var r = 0; r < pathListModel.count; r++) {
            if (pathListModel.get(r).status === "failed") {
                pathListModel.setProperty(r, "status", "pending")
            }
        }
        // Collect only pending items
        var pendingItems = []
        for (var i = 0; i < pathListModel.count; i++) {
            var item = pathListModel.get(i)
            if (item.status === "pending") {
                pendingItems.push({ path: item.path, isDir: item.isDir, modelIndex: i })
            }
        }
        if (pendingItems.length === 0) {
            root._resultMessage = qsTr("No files to encrypt")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }

        // Resolve pubKey
        var pubKey = root.domainPubKey || ""
        if (!pubKey || pubKey === "") {
            // empty stub: show error when public key unavailable
            root._resultMessage = qsTr("Security domain public key not found")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }
        if (!pubKey || pubKey === "") {
            root._resultMessage = qsTr("Security domain public key not found")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }

        // Build file queue: expand folders, preserve per-item output path
        var queue = []
        root._folderDoneMap = {}
        for (var j = 0; j < pendingItems.length; j++) {
            var pi = pendingItems[j]
            if (pi.isDir) {
                var files = _listFilesRecursive(pi.path)
                if (files.length === 0) {
                    pathListModel.setProperty(pi.modelIndex, "status", "failed")
                    continue
                }
                var normalizedSource = pi.path.replace(/\\/g, "/").replace(/\/+$/, "")
                var normalizedCustom = root.selectedOutputPath ? root.selectedOutputPath.replace(/\\/g, "/").replace(/\/+$/, "") : ""
                var folderName = getFileName(normalizedSource)
                var folderBaseOutput = ""
                if (normalizedCustom && normalizedCustom !== normalizedSource) {
                    folderBaseOutput = normalizedCustom + "/" + folderName
                } else {
                    var folderParent = getFileDir(normalizedSource)
                    folderBaseOutput = folderParent + "/" + folderName + "_encrypted"
                }
                root._folderDoneMap[pi.modelIndex.toString()] = { total: files.length, done: 0, failed: 0 }
                for (var k = 0; k < files.length; k++) {
                    var fileFullPath = files[k].replace(/\\/g, "/")
                    var relativePath = fileFullPath.substring(normalizedSource.length + 1)
                    var relativeDir = getFileDir(relativePath)
                    var fileOutput = relativeDir ? (folderBaseOutput + "/" + relativeDir) : folderBaseOutput
                    queue.push({ file: files[k], output: fileOutput, modelIndex: pi.modelIndex })
                }
            } else {
                var fileOut = root.selectedOutputPath || getFileDir(pi.path)
                queue.push({ file: pi.path, output: fileOut, modelIndex: pi.modelIndex })
            }
        }

        if (queue.length === 0) {
            root._resultMessage = qsTr("No encryptable files found")
            root._resultType = "error"
            root._encryptProgressDismissed = false
            return
        }

        root._currentPubKey = pubKey
        root._encryptTotal = queue.length
        root._encryptDone = 0
        root._encryptFailed = 0
        root._encryptProgress = 0
        root._encrypting = true
        root._encryptProgressDismissed = false
        root._resultMessage = ""
        root._resultType = ""

        var first = queue.shift()
        root._encryptQueue = queue
        root._currentModelIndex = first.modelIndex
        // 空实现：模拟加密完成
        root._encrypting = false
        root._encryptDone = root._encryptTotal
        root._encryptProgress = 100
        root._encryptProgressDismissed = false
        root._resultMessage = qsTr("Function disabled")
        root._resultType = "error"
    }

    // ---- Dialogs ----

    FileDialog {
        id: fileDialog
        title: qsTr("Select File")
        fileMode: FileDialog.OpenFile

        onAccepted: {
            var paths = []
            if (fileDialog.files && fileDialog.files.length > 0) {
                for (var i = 0; i < fileDialog.files.length; i++) {
                    paths.push(root.urlToLocalPath(fileDialog.files[i]))
                }
            } else if (fileDialog.file) {
                paths.push(root.urlToLocalPath(fileDialog.file))
            }
            root.addPaths(paths)
        }
    }

    FolderDialog {
        id: folderSelectDialog
        title: qsTr("Select Folder")

        onAccepted: {
            var folderPath = root.urlToLocalPath(folderSelectDialog.folder)
            if (folderPath) root.addPaths([folderPath])
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Select Output Path")

        onAccepted: {
            root.selectedOutputPath = root.urlToLocalPath(folderDialog.folder)
        }
    }

    ListModel {
        id: pathListModel
    }

    Connections {
        target: DsccBridge

        function onEncryptFileStarted(operationId, sourceFile, targetFile) {
            if (root._currentSourceFile === sourceFile && root._currentTargetFile === targetFile) {
                root._currentOperationId = operationId
            }
        }

        function onEncryptFileProgress(operationId, sourceFile, targetFile, processedBytes, totalBytes) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile)) return

            var currentRatio = totalBytes > 0 ? (processedBytes / totalBytes) : 0
            currentRatio = Math.max(0, Math.min(1, currentRatio))
            var overallRatio = (root._encryptDone + currentRatio) / Math.max(1, root._encryptTotal)
            root._encryptProgress = Math.round(Math.max(0, Math.min(1, overallRatio)) * 100)
        }

        function onEncryptFileSucceeded(operationId, sourceFile, targetFile) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile)) return
            root._completeCurrentEncryption("encrypted", "")
        }

        function onEncryptFileFailed(operationId, sourceFile, targetFile, notification) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile)) return
            root._completeCurrentEncryption(
                "failed",
                root._formatEncryptFailure(notification, qsTr("Encryption failed")))
        }

        function onEncryptFileCanceled(operationId, sourceFile, targetFile) {
            if (!root._encrypting || !root._operationMatches(operationId, sourceFile, targetFile)) return
            root._completeCurrentEncryption("failed", qsTr("Encryption cancelled"))
        }
    }

    // ---- Main content ----
    Rectangle {
        id: mainRect
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: "white"
        border.width: 1

        Item {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            anchors.bottomMargin: 24

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 16

                // Header
                Item {
                    width: parent.width
                    height: 18

                    SelectableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Encrypt Files to This Security Domain")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: "#0f172b"
                    }

                    Rectangle {
                        width: 24; height: 24
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            enabled: !root._encrypting
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: { root.close(); root.cancelClicked() }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 20
                            color: "#314158"
                            opacity: 0.7
                        }
                    }
                }

                // ---- Unified file/folder selector box ----
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        spacing: 4
                        SelectableText {
                            text: qsTr("Files to Encrypt")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#314158"
                        }
                        SelectableText {
                            text: "*"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.requiredMarker
                        }
                    }

                    // File selector box
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: addFileBtnArea.containsMouse ? "#e8f8ff" : Theme.Colors.backgroundWhite
                        border.color: addFileBtnArea.containsMouse ? "#79aecd" : "#94a3b8"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Image {
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-directory.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Item {
                                width: parent.width - 16 - 12
                                height: parent.height
                                clip: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.selectedFilePath ? root.selectedFilePath : qsTr("Please select files to encrypt")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: root.selectedFilePath ? "#0f172b" : "#94a3b8"
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        MouseArea {
                            id: addFileBtnArea
                            anchors.fill: parent
                            enabled: !root._encrypting
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: fileDialog.open()
                        }
                    }
                }

                // Output path section
                Column {
                    width: parent.width
                    spacing: 8

                    SelectableText {
                        text: qsTr("Output Path for Encrypted Files")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#314158"
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: outputBtnArea.containsMouse ? "#e8f8ff" : Theme.Colors.backgroundWhite
                        border.color: outputBtnArea.containsMouse ? "#79aecd" : "#94a3b8"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.left: parent.left
                            anchors.right: outputClearBtn.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Image {
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-directory.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Item {
                                width: parent.width - 16 - 12
                                height: parent.height
                                clip: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.selectedOutputPath
                                          ? root.selectedOutputPath
                                          : (root.selectedFilePath ? root.getFileDir(root.selectedFilePath) : qsTr("Select output path"))
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: (root.selectedOutputPath || root.selectedFilePath) ? "#0f172b" : "#94a3b8"
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        // Clear output path button
                        Rectangle {
                            id: outputClearBtn
                            width: root.selectedOutputPath ? 20 : 0
                            height: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 10
                            visible: root.selectedOutputPath !== ""
                            color: outputClearArea.containsMouse ? "#fee2e2" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 12
                                color: outputClearArea.containsMouse ? "#ef4444" : "#94a3b8"
                            }

                            MouseArea {
                                id: outputClearArea
                                anchors.fill: parent
                                enabled: !root._encrypting
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: root.selectedOutputPath = ""
                            }
                        }

                        MouseArea {
                            id: outputBtnArea
                            anchors.left: parent.left
                            anchors.right: outputClearBtn.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            enabled: !root._encrypting
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: folderDialog.open()
                        }
                    }
                }

                // ---- Inline progress bar ----
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root._encrypting || ((root._encryptProgress > 0 || root._resultMessage !== "") && !root._encryptProgressDismissed)

                    Row {
                        width: parent.width
                        Text {
                            text: root._encrypting
                                ? (root._encryptTotal > 1
                                    ? qsTr("Encrypting (") + (root._encryptDone + 1) + "/" + root._encryptTotal + ")"
                                    : qsTr("Encrypting..."))
                                : (root._resultType === "error" ? qsTr("Encryption failed")
                                    : root._resultType === "warning" ? qsTr("Partially completed") : qsTr("Encryption completed"))
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root._encrypting ? "#314158"
                                : (root._resultType === "error" ? "#ef4444"
                                    : root._resultType === "warning" ? "#f59e0b" : "#22c55e")
                        }
                        Item { width: parent.width - parent.children[0].width - parent.children[2].width; height: 1 }
                        Text {
                            text: root._encrypting ? root._encryptProgress + "%" : ""
                            font.pixelSize: 12
                            color: "#62748e"
                        }
                    }

                    ProgressBar {
                        id: inlineProgressBar
                        width: parent.width
                        from: 0; to: 100
                        value: root._encryptProgress

                        background: Rectangle {
                            implicitWidth: inlineProgressBar.width
                            implicitHeight: 6
                            radius: 3
                            color: "#e2e8f0"
                        }

                        contentItem: Item {
                            implicitWidth: inlineProgressBar.width
                            implicitHeight: 6

                            Rectangle {
                                width: inlineProgressBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: root._resultType === "error" ? "#ef4444"
                                    : root._resultType === "warning" ? "#f59e0b" : "#22c55e"
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.25) }
                                        GradientStop { position: 0.5; color: "transparent" }
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
                        font.pixelSize: 12
                        color: root._resultType === "error" ? "#ef4444" : "#314158"
                        wrapMode: Text.WrapAnywhere
                    }

                }

            }

            // Footer buttons
            Row {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 61; height: 36; radius: 8
                    color: {
                        if (cancelArea.pressed) return "#bedbff"
                        if (cancelArea.containsMouse) return "#e8f8ff"
                        return "white"
                    }
                    border.width: 1
                    border.color: {
                        if (cancelArea.pressed) return "#add3e6"
                        if (cancelArea.containsMouse) return "#79aecd"
                        return "#cad5e2"
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#314158"
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        enabled: !root._encrypting
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: { root.close(); root.cancelClicked() }
                    }
                }

                Rectangle {
                    width: encryptBtnText.implicitWidth + 24
                    height: 36; radius: 8
                    color: {
                        if (root._pendingCount === 0) return "#0f4c81"
                        if (encryptArea.pressed) return "#0f4c81"
                        if (encryptArea.containsMouse) return Qt.lighter("#0f4c81", 1.15)
                        return "#0f4c81"
                    }
                    opacity: root._pendingCount > 0 && !root._encrypting ? 1.0 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: encryptBtnText
                        anchors.centerIn: parent
                        text: qsTr("Encrypt Files")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        id: encryptArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root._pendingCount > 0 && !root._encrypting
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.startEncryption()
                    }
                }
            }
        }
    }

    // ---- Duplicate warning dialog ----
    Popup {
        id: duplicateDialog
        width: 380; height: duplicateContent.implicitHeight + 40
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
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
            }

            SelectableText {
                width: parent.width
                text: duplicateDialog.text
                font.pixelSize: 13
                color: "#314158"
                wrapMode: TextEdit.Wrap
            }

            Row {
                anchors.right: parent.right

                Rectangle {
                    width: 60; height: 32; radius: 8
                    color: Theme.Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Got it")
                        font.pixelSize: 13
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
                color: "#1e5a8e"
                radius: 4

                Text {
                    id: ftText
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 16)
                    text: root._tooltipText
                    font.pixelSize: 13
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

    // Signals
    signal cancelClicked()
    signal encryptClicked()
}
