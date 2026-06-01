import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Components 1.0
import DataSafebox.Theme 1.0 as Theme

BaseDialog {
    id: root
    dialogWidth: 400
    title: qsTr("New Version Found") + " V" + root.latestVersion

    property string latestVersion: ""

    Connections {
        target: UpdateManager
        function onUpdateAvailable(version, desc, force) {
            root.latestVersion = version;
            root.open();
        }
    }

    Column {
        width: parent.width
        spacing: 16

        // Current (installed) version.
        Text {
            text: qsTr("Current Version") + " V" + UpdateManager.currentVersion
            font.pixelSize: Theme.Typography.caption
            color: Theme.Colors.textCaption
        }

        // Release notes — driven by the backend description; hidden when none is provided.
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

        // Footer action. The download/install behaviour is wired up in a later step.
        Item {
            width: parent.width
            height: updateButton.height

            // TODO: wire the download/install flow on click (deferred for now).
            PrimaryButton {
                id: updateButton
                anchors.right: parent.right
                text: qsTr("Update Now")
                fontWeight: Font.Medium
            }
        }
    }
}
