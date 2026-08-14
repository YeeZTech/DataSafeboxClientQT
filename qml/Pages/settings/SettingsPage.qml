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
        spacing: 20

        Text {
            text: qsTr("Settings")
            font.pixelSize: Theme.Typography.h1
            font.weight: Font.Bold
            color: "#303542"
        }

        // ── Language ──────────────────────────────────────────────
        // Hidden when the build hard-codes the UI language (qmake USE_LANG).
        Column {
            width: parent.width
            spacing: 14
            visible: !LanguageManager.languageLocked

            Text {
                text: qsTr("Language")
                font.pixelSize: Theme.Typography.h2
                font.weight: Font.DemiBold
                color: Theme.Colors.textTitle
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Interface Language:")
                    font.pixelSize: Theme.Typography.h3
                    color: "#7f8793"
                }

                // Segmented switch. Language names stay in their own language,
                // so they are deliberately not wrapped in qsTr().
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: languageOptions.width + 6
                    height: 36
                    radius: 8
                    color: Theme.Colors.buttonSecondaryBg
                    border.width: 1
                    border.color: Theme.Colors.border

                    Row {
                        id: languageOptions
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                {
                                    "code": "zh_cn",
                                    "label": "简体中文"
                                },
                                {
                                    "code": "en",
                                    "label": "English"
                                }
                            ]

                            Rectangle {
                                id: languageOption

                                readonly property bool selected: LanguageManager.currentLanguage === modelData.code

                                width: languageOptionLabel.implicitWidth + 28
                                height: 28
                                radius: 6
                                color: languageOption.selected ? "#ffffff" : languageOptionMouse.containsMouse ? Theme.Colors.buttonSecondaryHover : "transparent"
                                border.width: languageOption.selected ? 1 : 0
                                border.color: Theme.Colors.borderField

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    id: languageOptionLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.Typography.body
                                    font.weight: languageOption.selected ? Font.DemiBold : Font.Normal
                                    color: languageOption.selected ? Theme.Colors.primary : Theme.Colors.textCaption
                                }

                                MouseArea {
                                    id: languageOptionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: languageOption.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: LanguageManager.switchLanguage(modelData.code)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Cache path ────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 14

            Text {
                text: qsTr("Storage Path")
                font.pixelSize: Theme.Typography.h2
                font.weight: Font.DemiBold
                color: Theme.Colors.textTitle
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: qsTr("Default Cache Path:")
                    font.pixelSize: Theme.Typography.h3
                    color: "#7f8793"
                }

                Text {
                    width: parent.width - 130
                    text: PathManager && PathManager.cacheDir ? PathManager.cacheDir : ""
                    font.pixelSize: Theme.Typography.h3
                    color: "#687180"
                    wrapMode: Text.WrapAnywhere
                }
            }

            Flow {
                width: parent.width
                spacing: 10

                Text {
                    text: qsTr("Change Path")
                    font.pixelSize: Theme.Typography.h3
                    color: settingsChangePathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsChangePathMouse.containsMouse ? Theme.Colors.linkHover : Theme.Colors.primary
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
                    font.pixelSize: Theme.Typography.h3
                    color: "#c6ccd4"
                }

                Text {
                    text: qsTr("Open Path")
                    font.pixelSize: Theme.Typography.h3
                    color: settingsOpenPathMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsOpenPathMouse.containsMouse ? Theme.Colors.linkHover : Theme.Colors.primary
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
                    font.pixelSize: Theme.Typography.h3
                    color: "#c6ccd4"
                }

                Text {
                    text: qsTr("Clear Cache")
                    font.pixelSize: Theme.Typography.h3
                    color: settingsClearCacheMouse.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : settingsClearCacheMouse.containsMouse ? Theme.Colors.linkHover : Theme.Colors.primary
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
                    font.pixelSize: Theme.Typography.h3
                    color: "#8f96a1"
                }
            }
        }

        Text {
            text: root.statusText
            font.pixelSize: Theme.Typography.body
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
