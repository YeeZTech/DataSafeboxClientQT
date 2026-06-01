import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Components 1.0
import DataSafebox.Theme 1.0 as Theme

BaseDialog {
    id: root
    dialogWidth: 448

    // Flow phase: "prompt" | "downloading" | "installing" | "success" | "failure"
    property string phase: "prompt"
    property string latestVersion: ""
    property string errorText: ""
    // Animated progress for the brief, synthetic "installing" stage. The real file
    // replacement happens after the user restarts into the installer.
    property real installProgress: 0

    // Raised when the user taps "Contact Customer Service" on the failure screen.
    signal contactCustomerServiceRequested

    title: {
        switch (root.phase) {
        case "downloading":
        case "installing":
            return qsTr("Updating");
        case "success":
            return qsTr("Update Successful");
        case "failure":
            return qsTr("Update Failed");
        default:
            return qsTr("New Version Found") + " V" + root.latestVersion;
        }
    }

    // Format a byte count into a human-readable size string (1024-based).
    function _formatSize(bytes) {
        if (!bytes || bytes <= 0)
            return "0MB";
        var mb = bytes / 1048576;
        if (mb >= 1024)
            return (mb / 1024).toFixed(2) + "GB";
        return mb.toFixed(2) + "MB";
    }

    Connections {
        target: UpdateManager
        function onUpdateAvailable(version, desc, force) {
            root.latestVersion = version;
            root.errorText = "";
            root.phase = "prompt";
            root.open();
        }
        function onDownloadFinished() {
            if (root.opened && root.phase === "downloading") {
                root.phase = "installing";
                installAnim.restart();
            }
        }
        function onDownloadFailed(message) {
            if (root.opened && (root.phase === "downloading" || root.phase === "installing")) {
                root.errorText = message;
                root.phase = "failure";
            }
        }
    }

    // Brief synthetic "installing" progress shown before the success screen.
    NumberAnimation {
        id: installAnim
        target: root
        property: "installProgress"
        from: 0
        to: 1
        duration: 1200
        onFinished: root.phase = "success"
    }

    Column {
        width: parent.width
        spacing: 0

        // ---- prompt: new version found ----
        Column {
            width: parent.width
            spacing: 16
            visible: root.phase === "prompt"

            Text {
                text: qsTr("Current Version") + " V" + UpdateManager.currentVersion
                font.pixelSize: Theme.Typography.caption
                color: Theme.Colors.textCaption
            }

            // Release notes — hidden when the backend provides no description.
            Column {
                width: parent.width
                spacing: 8
                visible: UpdateManager.updateDescription !== ""

                Text {
                    text: qsTr("Release Notes")
                    font.pixelSize: Theme.Typography.body
                    font.weight: Font.DemiBold
                    color: Theme.Colors.textHeading
                }

                Text {
                    width: parent.width
                    text: UpdateManager.updateDescription
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textMenu
                    wrapMode: Text.WordWrap
                    lineHeight: 1.6
                }
            }

            Item {
                width: parent.width
                height: updateButton.height

                PrimaryButton {
                    id: updateButton
                    anchors.right: parent.right
                    text: qsTr("Update Now")
                    fontWeight: Font.Medium
                    onClicked: {
                        root.phase = "downloading";
                        UpdateManager.startDownload();
                    }
                }
            }
        }

        // ---- downloading ----
        Column {
            width: parent.width
            spacing: 12
            visible: root.phase === "downloading"

            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Downloading...")
                    font.pixelSize: Theme.Typography.caption
                    color: Theme.Colors.textCaption
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._formatSize(UpdateManager.clientSize * UpdateManager.downloadProgress) + "/" + root._formatSize(UpdateManager.clientSize)
                    font.pixelSize: Theme.Typography.caption
                    color: Theme.Colors.textCaption
                }
            }

            Item {
                width: parent.width
                height: 16

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: downloadPercent.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 10
                    radius: 4
                    color: Theme.Colors.backgroundGray

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, UpdateManager.downloadProgress))
                        color: Theme.Colors.primary
                    }
                }

                Text {
                    id: downloadPercent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(UpdateManager.downloadProgress * 100) + "%"
                    font.pixelSize: Theme.Typography.caption
                    color: Theme.Colors.textCaption
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    var line = qsTr("Download Speed:") + " " + UpdateManager.downloadSpeed;
                    if (UpdateManager.downloadEta !== "")
                        line += "    " + qsTr("Estimated Time Remaining:") + " " + UpdateManager.downloadEta;
                    return line;
                }
                font.pixelSize: Theme.Typography.caption
                color: Theme.Colors.textCaption
            }
        }

        // ---- installing ----
        Column {
            width: parent.width
            spacing: 12
            visible: root.phase === "installing"

            Text {
                text: qsTr("Installing...")
                font.pixelSize: Theme.Typography.caption
                color: Theme.Colors.textCaption
            }

            Item {
                width: parent.width
                height: 16

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: installPercent.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 10
                    radius: 4
                    color: Theme.Colors.backgroundGray

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * root.installProgress
                        color: Theme.Colors.primary
                    }
                }

                Text {
                    id: installPercent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.installProgress * 100) + "%"
                    font.pixelSize: Theme.Typography.caption
                    color: Theme.Colors.textCaption
                }
            }
        }

        // ---- success ----
        Column {
            width: parent.width
            spacing: 0
            visible: root.phase === "success"

            Item {
                width: parent.width
                height: 8
            }

            Rectangle {
                width: 64
                height: 64
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#DCFCE7"

                Image {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    source: "qrc:/icons/icon-check-success.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }

            Item {
                width: parent.width
                height: 16
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Update Successful")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            Item {
                width: parent.width
                height: 8
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Update downloaded successfully. Please restart the client to enjoy the new features.")
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textCaption
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 24
            }

            Row {
                anchors.right: parent.right
                spacing: 12

                SecondaryButton {
                    text: qsTr("Cancel")
                    onClicked: root.close()
                }

                PrimaryButton {
                    text: qsTr("Restart")
                    fontWeight: Font.Medium
                    onClicked: UpdateManager.installUpdate()
                }
            }
        }

        // ---- failure ----
        Column {
            width: parent.width
            spacing: 0
            visible: root.phase === "failure"

            Item {
                width: parent.width
                height: 8
            }

            Rectangle {
                width: 64
                height: 64
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#FFE2E2"

                Image {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    source: "qrc:/icons/icon-update-failed.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }

            Item {
                width: parent.width
                height: 16
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Update Failed")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            Item {
                width: parent.width
                height: 8
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    var tip = qsTr(". You can try updating the client again or contact customer service for help.");
                    if (root.errorText !== "")
                        return qsTr("Failure reason:") + root.errorText + tip;
                    return tip;
                }
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textCaption
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 24
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                SecondaryButton {
                    text: qsTr("Contact Customer Service")
                    onClicked: root.contactCustomerServiceRequested()
                }

                PrimaryButton {
                    text: qsTr("Retry")
                    fontWeight: Font.Medium
                    onClicked: {
                        root.errorText = "";
                        root.phase = "downloading";
                        UpdateManager.startDownload();
                    }
                }
            }
        }
    }
}
