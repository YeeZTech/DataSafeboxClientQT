import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform 1.1 as Platform
import "." as Theme

Popup {
    id: root
    width: 448
    // Auto height based on content + margins (24 top + 16 bottom = 40)
    height: contentColumn.implicitHeight + 40 + (fileErrorText && fileErrorText.visible ? 8 : 0)
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)

    property var selectedFilePaths: []
    property string fileDisplayText: ""
    property string reasonText: ""
    property string allowedDirectory: ""
    property string _allowedCanonical: ""
    property string fileError: ""
    readonly property bool canSubmit: selectedFilePaths.length > 0

    signal confirmClicked(var filePaths, string reasonText)
    signal cancelClicked()

    onAllowedDirectoryChanged: {
        _allowedCanonical = canonicalPath(allowedDirectory)
        updateFileDialogFolder()
        fileError = ""
    }

    function resetForm() {
        selectedFilePaths = []
        fileDisplayText = ""
        reasonText = ""
        fileError = ""
    }

    background: Rectangle {
        id: bgRect
        color: "white"
        radius: 10
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
    }

    contentItem: Item {
        id: contentContainer
        anchors.fill: parent

        Column {
            id: contentColumn
            width: parent.width - 48
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 0

            // 标题行
            Item {
                width: parent.width
                height: 18

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "导出文件"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0F172B"
                }

                Rectangle {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 12
                    color: headerCloseArea.containsMouse ? "#f0f4fa" : "transparent"

                    MouseArea {
                        id: headerCloseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.close()
                            root.cancelClicked()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 18
                        color: headerCloseArea.containsMouse ? "#0f4c81" : "#94A3B8"
                    }
                }
            }

            // 标题与内容之间的间距（向下整体移动 16px，原 16px → 32px）
            Item { width: parent.width; height: 16 }

            // 内容区
            Column {
                width: parent.width
                spacing: 16

                // 选择文件
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        spacing: 4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 14

                        Text {
                            text: "*"
                            color: "#FB2C36"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        SelectableText {
                            text: "选择文件："
                            color: "#314158"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        height: 36

                        Rectangle {
                            id: fileField
                            width: parent.width - browseButton.width - 8
                            height: 36
                            radius: 8
                            color: fileFieldArea.containsMouse ? "#e9eef6" : Theme.Colors.inputBackground
                            border.color: "#CAD5E2"
                            border.width: 1

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fileDisplayText.length > 0 ? root.fileDisplayText : "请选择需要导出的文件"
                                color: root.fileDisplayText.length > 0 ? "#0F172B" : (fileFieldArea.containsMouse ? "#0F4C81" : "#5A7C9B")
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                width: parent.width - 24
                            }

                            MouseArea {
                                id: fileFieldArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: fileDialog.open()
                            }
                        }

                        Rectangle {
                            id: browseButton
                            width: 86
                            height: 36
                            radius: 8
                            color: browseArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                            border.color: Theme.Colors.primary
                            border.width: 1

                            Image {
                                id: browseIcon
                                source: Qt.resolvedUrl("icons/icon-export-upload.svg")
                                width: 16
                                height: 16
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.left: browseIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "浏览"
                                color: Theme.Colors.primaryText
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: browseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: fileDialog.open()
                            }
                        }
                    }
                }

                Text {
                    id: fileErrorText
                    width: parent.width
                    text: root.fileError
                    color: "#FB2C36"
                    font.pixelSize: 12
                    visible: root.fileError && root.fileError.length > 0
                }

                // 导出原因
                Column {
                    width: parent.width
                    spacing: 8

                    SelectableText {
                        text: "导出原因："
                        color: "#314158"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        width: parent.width
                        height: 96
                        radius: 8
                        color: reasonArea.activeFocus ? Theme.Colors.backgroundWhite : (reasonHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite)
                        border.color: "#cad5e2"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: reasonHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        TextArea {
                            id: reasonArea
                            anchors.fill: parent
                            wrapMode: TextEdit.Wrap
                            placeholderText: "您可以在此填写导出原因，原因可能会被安全域创建者看到，也可能会作为原因报告留存。"
                            text: root.reasonText
                            font.pixelSize: 14
                            color: "#0F172B"
                            selectByMouse: true
                            selectionColor: "#d4e4f1"
                            selectedTextColor: "#0f172b"
                            onTextChanged: root.reasonText = text
                            padding: 0
                            topPadding: 8
                            bottomPadding: 8
                            leftPadding: 12
                            rightPadding: 12
                            background: null
                        }

                        InputContextMenu {
                            anchors.fill: parent
                            target: reasonArea
                        }
                    }
                }
            }

            // 文字与按钮之间的间距（与设计稿一致为 16px，额外向下移动按钮 8px）
            Item { width: parent.width; height: 16 }

            // 确定按钮
            Rectangle {
                width: 128
                height: 36
                radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                color: (confirmArea.containsMouse && root.canSubmit) ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                opacity: root.canSubmit ? 1 : 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "确定"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.Colors.primaryText
                }

                MouseArea {
                    id: confirmArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!root.canSubmit)
                            return
                        root.confirmClicked(root.selectedFilePaths.slice(0), root.reasonText)
                        root.close()
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "选择导出文件"
        fileMode: FileDialog.OpenFiles
        Component.onCompleted: updateFileDialogFolder()
        onAccepted: {
            if (fileDialog.selectedFiles && fileDialog.selectedFiles.length > 0) {
                var validPaths = []
                for (var i = 0; i < fileDialog.selectedFiles.length; i++) {
                    var url = fileDialog.selectedFiles[i].toString()
                    var normalized = normalizeFileUrl(url)
                    if (!isPathAllowed(normalized)) {
                        root.fileError = root.allowedDirectory && root.allowedDirectory.length > 0 ?
                                         "只能选择路径 " + root.allowedDirectory + " 下的文件" :
                                         "无法选择所选文件"
                        root.selectedFilePaths = []
                        root.fileDisplayText = ""
                        return
                    }
                    validPaths.push(normalized)
                }
                root.fileError = ""
                root.selectedFilePaths = validPaths
                root.fileDisplayText = validPaths.length === 1
                        ? extractFileName(validPaths[0])
                        : (validPaths.length + " 个文件")
            }
        }
    }

    function extractFileName(path) {
        if (!path)
            return ""
        var separator = path.indexOf("\\") !== -1 ? "\\" : "/"
        var parts = path.split(separator)
        return parts.length > 0 ? parts[parts.length - 1] : path
    }

    function normalizeFileUrl(url) {
        if (!url)
            return ""
        var str = url.toString()
        if (str.startsWith("file:///")) {
            var decoded = decodeURIComponent(str.substring(8))
            if (Qt.platform.os === "windows") {
                return decoded.replace(/\//g, "\\")
            }
            return decoded.startsWith("/") ? decoded : "/" + decoded
        } else if (str.startsWith("file://")) {
            var decoded = decodeURIComponent(str.substring(7))
            if (Qt.platform.os === "windows") {
                return decoded.replace(/\//g, "\\")
            }
            return decoded.startsWith("/") ? decoded : "/" + decoded
        }
        return decodeURIComponent(str)
    }

    function canonicalPath(path) {
        if (!path)
            return ""
        var normalized = path.toString().replace(/\\/g, "/")
        if (Qt.platform.os === "windows")
            normalized = normalized.toLowerCase()
        if (normalized.length > 0 && !normalized.endsWith("/"))
            normalized += "/"
        return normalized
    }

    function isPathAllowed(path) {
        if (!_allowedCanonical || _allowedCanonical.length === 0)
            return true
        var selectedCanonical = canonicalPath(path)
        return selectedCanonical.indexOf(_allowedCanonical) === 0
    }

    function pathToUrl(path) {
        if (!path || path.length === 0)
            return Platform.StandardPaths.standardLocations(Platform.StandardPaths.HomeLocation)[0]
        var normalized = path.replace(/\\/g, "/")
        if (Qt.platform.os === "windows") {
            return "file:///" + normalized.replace(/ /g, "%20")
        }
        if (!normalized.startsWith("/"))
            normalized = "/" + normalized
        return "file://" + normalized.replace(/ /g, "%20")
    }

    function updateFileDialogFolder() {
        if (!fileDialog)
            return
        fileDialog.currentFolder = (allowedDirectory && allowedDirectory.length > 0) ?
            pathToUrl(allowedDirectory) :
            Platform.StandardPaths.standardLocations(Platform.StandardPaths.HomeLocation)[0]
    }
}
