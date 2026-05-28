import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1 as Platform
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Item {
    id: root

    property string statusText: ""

    onVisibleChanged: {
        if (visible) {
            statusText = "";
            if (PathManager && PathManager.refreshCacheSize)
                PathManager.refreshCacheSize();
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14

        Text {
            text: qsTr("Settings")
            font.pixelSize: 24
            font.weight: Font.Bold
            color: "#303542"
        }

        Row {
            width: parent.width
            spacing: 10

            Text {
                text: qsTr("Default Cache Path:")
                font.pixelSize: 16
                color: "#7f8793"
            }

            Text {
                width: parent.width - 130
                text: PathManager && PathManager.cacheDir ? PathManager.cacheDir : ""
                font.pixelSize: 16
                color: "#687180"
                wrapMode: Text.WrapAnywhere
            }
        }

        Flow {
            width: parent.width
            spacing: 10

            Text {
                text: qsTr("Change Path")
                font.pixelSize: 16
                color: settingsChangePathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsChangePathMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                MouseArea {
                    id: settingsChangePathMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tempFolderDialog.open()
                }
            }

            Text {
                text: "|"
                font.pixelSize: 16
                color: "#c6ccd4"
            }

            Text {
                text: qsTr("Open Path")
                font.pixelSize: 16
                color: settingsOpenPathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsOpenPathMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                MouseArea {
                    id: settingsOpenPathMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (PathManager && PathManager.openTempDir) {
                            var opened = PathManager.openTempDir();
                            if (!opened) {
                                root.statusText = qsTr("Failed to open directory, please check if path is accessible");
                            }
                        }
                    }
                }
            }

            Text {
                text: "|"
                font.pixelSize: 16
                color: "#c6ccd4"
            }

            Text {
                text: qsTr("Clear Cache")
                font.pixelSize: 16
                color: settingsClearCacheMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsClearCacheMouse.containsMouse ? "#2A6A9A" : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                MouseArea {
                    id: settingsClearCacheMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (PathManager && PathManager.clearCache) {
                            var cleaned = PathManager.clearCache();
                            root.statusText = qsTr("Cache cleared:") + Theme.Utils.formatSize(cleaned);
                        }
                    }
                }
            }

            Text {
                text: "(" + qsTr("approx.") + " " + Theme.Utils.formatSize(PathManager && PathManager.cacheSizeBytes ? PathManager.cacheSizeBytes : 0) + ")"
                font.pixelSize: 16
                color: "#8f96a1"
            }
        }

        Text {
            text: root.statusText
            font.pixelSize: 14
            color: "#3b4ed6"
            visible: root.statusText.length > 0
        }
    }

    Platform.FolderDialog {
        id: tempFolderDialog
        title: qsTr("Select Cache Directory")
        onAccepted: {
            var selectedPath = "";
            if (tempFolderDialog.folder) {
                if (typeof tempFolderDialog.folder.toLocalFile === "function") {
                    selectedPath = tempFolderDialog.folder.toLocalFile();
                } else {
                    var rawUrl = tempFolderDialog.folder.toString();
                    if (rawUrl.indexOf("file:///") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(8));
                        if (Qt.platform.os === "windows" && selectedPath.length > 0 && selectedPath[0] === "/") {
                            selectedPath = selectedPath.substring(1);
                        }
                    } else if (rawUrl.indexOf("file://") === 0) {
                        selectedPath = decodeURIComponent(rawUrl.substring(7));
                    }
                }
            }
            if (selectedPath && PathManager && PathManager.setTempDir) {
                var ok = PathManager.setTempDir(selectedPath);
                root.statusText = ok ? qsTr("Cache directory updated, new tasks will use it immediately") : qsTr("Failed to set path, please check directory permissions");
            }
        }
    }
}
