import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Components 1.0

Dialog {
    id: root
    modal: true
    closePolicy: (root.forceUpdate || UpdateManager.isDownloading || root.startedDownloadFromDialog) ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: 480

    property string versionStr: ""
    property bool forceUpdate: false
    property string fileSizeStr: ""
    property bool startedDownloadFromDialog: false

    signal immediateActionTriggered

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    background: Rectangle {
        color: "white"
        border.color: "#e2e8f0"
        border.width: 1
        radius: 12
        antialiasing: true
    }

    padding: 0

    Connections {
        target: UpdateManager
        function onUpdateAvailable(version, desc, force) {
            root.versionStr = version;
            root.forceUpdate = force;
            var bytes = UpdateManager.clientSize;
            if (bytes > 0) {
                root.fileSizeStr = (bytes / 1024 / 1024).toFixed(1) + "MB";
            } else {
                root.fileSizeStr = "";
            }
            root.open();
        }
        function onDownloadProgressChanged(progress) {
            if (root.startedDownloadFromDialog && progress >= 1.0) {
                root.startedDownloadFromDialog = false;
                root.close();
            }
        }
        function onDownloadFailed(message) {
            root.startedDownloadFromDialog = false;
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Header ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 16
            Layout.topMargin: 20
            Layout.bottomMargin: 20
            spacing: 0

            Text {
                text: qsTr("Update Available")
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "#0f172b"
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeMa.containsMouse && !root.forceUpdate ? "#f1f5f9" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\u00d7"
                    font.pixelSize: 20
                    color: root.forceUpdate ? "#d1d5db" : "#62748e"
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.forceUpdate && !UpdateManager.isDownloading
                    cursorShape: (!root.forceUpdate && !UpdateManager.isDownloading) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.close()
                }
            }
        }

        // ── Body ─────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 24
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: qsTr("Your current client version is ") + UpdateManager.currentVersion + qsTr(", which is not the latest. We recommend updating to the latest version ") + root.versionStr + qsTr(" for a better experience.")
                font.pixelSize: 14
                color: "#374151"
                wrapMode: Text.WordWrap
                lineHeight: 1.6
            }

            RowLayout {
                spacing: 4
                visible: root.fileSizeStr !== ""

                Text {
                    text: qsTr("Update Size:")
                    font.pixelSize: 13
                    color: "#6b7280"
                }
                Text {
                    text: root.fileSizeStr
                    font.pixelSize: 13
                    color: "#374151"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: UpdateManager.isDownloading || root.startedDownloadFromDialog

                Text {
                    text: qsTr("Downloading update package...")
                    font.pixelSize: 13
                    color: "#374151"
                }

                ProgressBar {
                    id: downloadProgressBar
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: UpdateManager.downloadProgress

                    background: Rectangle {
                        implicitHeight: 8
                        radius: height / 2
                        color: "#e5e7eb"
                    }

                    contentItem: Item {
                        implicitHeight: 8

                        Rectangle {
                            width: downloadProgressBar.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: "#22c55e"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: Math.round(UpdateManager.downloadProgress * 100) + "%"
                        font.pixelSize: 12
                        color: "#6b7280"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: UpdateManager.downloadSpeed
                        font.pixelSize: 12
                        color: "#6b7280"
                        visible: UpdateManager.downloadSpeed !== ""
                    }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#e5e7eb"
        }

        // ── Footer buttons ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            spacing: 12

            Item {
                Layout.fillWidth: true
            }

            // "以后再说"
            Rectangle {
                width: 116
                height: 38
                radius: 6
                color: "white"
                border.color: laterMa.containsMouse ? "#94a3b8" : "#d1d5db"
                border.width: 1
                visible: !root.forceUpdate

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u23F0"
                        font.pixelSize: 14
                        color: "#6b7280"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Later")
                        font.pixelSize: 14
                        color: "#374151"
                    }
                }

                MouseArea {
                    id: laterMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !UpdateManager.isDownloading
                    onClicked: root.close()
                }
            }

            // "立即更新"
            Rectangle {
                width: 100
                height: 38
                radius: 6
                color: btnMa.pressed ? Qt.darker("#0f4c81", 1.2) : (btnMa.containsMouse ? Qt.lighter("#0f4c81", 1.1) : "#0f4c81")
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: UpdateManager.isDownloading ? qsTr("Downloading...") : (UpdateManager.downloadProgress >= 1.0 ? qsTr("Install Now") : qsTr("Update Now"))
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "white"
                }

                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !UpdateManager.isDownloading
                    cursorShape: UpdateManager.isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        root.immediateActionTriggered();
                        if (UpdateManager.downloadProgress >= 1.0) {
                            root.close();
                            UpdateManager.installUpdate();
                        } else {
                            root.startedDownloadFromDialog = true;
                            UpdateManager.startDownload();
                        }
                    }
                }
            }
        }
    }
}
