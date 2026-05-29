import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Components 1.0
import DataSafebox.Theme 1.0 as Theme

BaseDialog {
    id: root
    dialogWidth: 480
    title: qsTr("Update Available")
    showCloseButton: !root.forceUpdate && !UpdateManager.isDownloading
    closePolicy: (root.forceUpdate || UpdateManager.isDownloading || root.startedDownloadFromDialog) ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    property string versionStr: ""
    property bool forceUpdate: false
    property string fileSizeStr: ""
    property bool startedDownloadFromDialog: false

    signal immediateActionTriggered

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

    Column {
        width: parent.width
        spacing: 12

        Text {
            width: parent.width
            text: qsTr("Your current client version is ") + UpdateManager.currentVersion + qsTr(", which is not the latest. We recommend updating to the latest version ") + root.versionStr + qsTr(" for a better experience.")
            font.pixelSize: Theme.Typography.body
            color: "#374151"
            wrapMode: Text.WordWrap
            lineHeight: 1.6
        }

        Row {
            spacing: 4
            visible: root.fileSizeStr !== ""

            Text {
                text: qsTr("Update Size:")
                font.pixelSize: Theme.Typography.caption
                color: "#6b7280"
            }
            Text {
                text: root.fileSizeStr
                font.pixelSize: Theme.Typography.caption
                color: "#374151"
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: UpdateManager.isDownloading || root.startedDownloadFromDialog

            Text {
                text: qsTr("Downloading update package...")
                font.pixelSize: Theme.Typography.caption
                color: "#374151"
            }

            ProgressBar {
                id: downloadProgressBar
                width: parent.width
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

            Item {
                width: parent.width
                height: percentText.implicitHeight

                Text {
                    id: percentText
                    anchors.left: parent.left
                    text: Math.round(UpdateManager.downloadProgress * 100) + "%"
                    font.pixelSize: Theme.Typography.small
                    color: "#6b7280"
                }

                Text {
                    anchors.right: parent.right
                    text: UpdateManager.downloadSpeed
                    font.pixelSize: Theme.Typography.small
                    color: "#6b7280"
                    visible: UpdateManager.downloadSpeed !== ""
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#e5e7eb"
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            SecondaryButton {
                text: qsTr("Later")
                visible: !root.forceUpdate
                enabled: !UpdateManager.isDownloading
                onClicked: root.close()
            }

            PrimaryButton {
                text: UpdateManager.isDownloading ? qsTr("Downloading...") : (UpdateManager.downloadProgress >= 1.0 ? qsTr("Install Now") : qsTr("Update Now"))
                enabled: !UpdateManager.isDownloading
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
