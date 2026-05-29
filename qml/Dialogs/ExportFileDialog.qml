import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform 1.1 as Platform
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    title: qsTr("Export Files")
    onCloseRequested: cancelClicked()

    property var selectedFilePaths: []
    property string fileDisplayText: ""
    property string reasonText: ""
    property string allowedDirectory: ""
    property string _allowedCanonical: ""
    property string fileError: ""
    readonly property bool canSubmit: selectedFilePaths.length > 0

    signal confirmClicked(var filePaths, string reasonText)
    signal cancelClicked

    onAllowedDirectoryChanged: {
        _allowedCanonical = canonicalPath(allowedDirectory);
        updateFileDialogFolder();
        fileError = "";
    }

    function resetForm() {
        selectedFilePaths = [];
        fileDisplayText = "";
        reasonText = "";
        fileError = "";
    }

    Column {
        id: contentColumn
        width: parent.width
        spacing: 0

        // 标题与内容之间的间距
        Item {
            width: parent.width
            height: 16
        }

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
                        text: qsTr("Select files:")
                        color: Theme.Colors.textLabel
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
                        border.color: Theme.Colors.borderField
                        border.width: 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fileDisplayText.length > 0 ? root.fileDisplayText : qsTr("Please select files to export")
                            color: root.fileDisplayText.length > 0 ? Theme.Colors.textHeading : (fileFieldArea.containsMouse ? Theme.Colors.primary : "#5A7C9B")
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
                            source: "qrc:/icons/icon-export-upload.svg"
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
                            text: qsTr("Browse")
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
                    text: qsTr("Export Reason:")
                    color: Theme.Colors.textLabel
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: parent.width
                    height: 96
                    radius: 8
                    color: reasonArea.activeFocus ? Theme.Colors.backgroundWhite : (reasonHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite)
                    border.color: Theme.Colors.borderField
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

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
                        placeholderText: qsTr("Enter export reason. Visible to the security domain creator and retained as audit record.")
                        text: root.reasonText
                        font.pixelSize: 14
                        color: Theme.Colors.textHeading
                        selectByMouse: true
                        selectionColor: "#d4e4f1"
                        selectedTextColor: Theme.Colors.textHeading
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

        // 文字与按钮之间的间距
        Item {
            width: parent.width
            height: 16
        }

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
                text: qsTr("Submit")
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
                        return;
                    root.confirmClicked(root.selectedFilePaths.slice(0), root.reasonText);
                    root.close();
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select export file")
        fileMode: FileDialog.OpenFiles
        Component.onCompleted: updateFileDialogFolder()
        onAccepted: {
            if (fileDialog.selectedFiles && fileDialog.selectedFiles.length > 0) {
                var validPaths = [];
                for (var i = 0; i < fileDialog.selectedFiles.length; i++) {
                    var url = fileDialog.selectedFiles[i].toString();
                    var normalized = normalizeFileUrl(url);
                    if (!isPathAllowed(normalized)) {
                        root.fileError = root.allowedDirectory && root.allowedDirectory.length > 0 ? "Files can only be selected from " + root.allowedDirectory + qsTr(" directory") : qsTr("Cannot select the specified file");
                        root.selectedFilePaths = [];
                        root.fileDisplayText = "";
                        return;
                    }
                    validPaths.push(normalized);
                }
                root.fileError = "";
                root.selectedFilePaths = validPaths;
                root.fileDisplayText = validPaths.length === 1 ? extractFileName(validPaths[0]) : (validPaths.length + qsTr(" files"));
            }
        }
    }

    function extractFileName(path) {
        if (!path)
            return "";
        var separator = path.indexOf("\\") !== -1 ? "\\" : "/";
        var parts = path.split(separator);
        return parts.length > 0 ? parts[parts.length - 1] : path;
    }

    function normalizeFileUrl(url) {
        if (!url)
            return "";
        var str = url.toString();
        if (str.startsWith("file:///")) {
            var decoded = decodeURIComponent(str.substring(8));
            if (Qt.platform.os === "windows") {
                return decoded.replace(/\//g, "\\");
            }
            return decoded.startsWith("/") ? decoded : "/" + decoded;
        } else if (str.startsWith("file://")) {
            var decoded = decodeURIComponent(str.substring(7));
            if (Qt.platform.os === "windows") {
                return decoded.replace(/\//g, "\\");
            }
            return decoded.startsWith("/") ? decoded : "/" + decoded;
        }
        return decodeURIComponent(str);
    }

    function canonicalPath(path) {
        if (!path)
            return "";
        var normalized = path.toString().replace(/\\/g, "/");
        if (Qt.platform.os === "windows")
            normalized = normalized.toLowerCase();
        if (normalized.length > 0 && !normalized.endsWith("/"))
            normalized += "/";
        return normalized;
    }

    function isPathAllowed(path) {
        if (!_allowedCanonical || _allowedCanonical.length === 0)
            return true;
        var selectedCanonical = canonicalPath(path);
        return selectedCanonical.indexOf(_allowedCanonical) === 0;
    }

    function pathToUrl(path) {
        if (!path || path.length === 0)
            return Platform.StandardPaths.standardLocations(Platform.StandardPaths.HomeLocation)[0];
        var normalized = path.replace(/\\/g, "/");
        if (Qt.platform.os === "windows") {
            return "file:///" + normalized.replace(/ /g, "%20");
        }
        if (!normalized.startsWith("/"))
            normalized = "/" + normalized;
        return "file://" + normalized.replace(/ /g, "%20");
    }

    function updateFileDialogFolder() {
        if (!fileDialog)
            return;
        fileDialog.currentFolder = (allowedDirectory && allowedDirectory.length > 0) ? pathToUrl(allowedDirectory) : Platform.StandardPaths.standardLocations(Platform.StandardPaths.HomeLocation)[0];
    }
}
