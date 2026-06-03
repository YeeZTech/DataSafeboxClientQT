import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 500
    showCloseButton: true
    title: qsTr("Security Domain Instantiation")

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    Column {
        width: parent.width
        spacing: 0

        ScrollView {
            // Extend into BaseDialog's 24px right content margin so the vertical
            // scrollbar hugs the dialog's right edge instead of overlapping content.
            width: parent.width + 24
            height: Math.min(bodyCol.implicitHeight + 32, 520)
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            clip: true

            Column {
                id: bodyCol
                width: root.dialogWidth - 48
                x: 0
                y: 0
                spacing: 16

                Rectangle {
                    width: parent.width
                    height: bannerRow.implicitHeight + 16
                    radius: 6
                    color: "#f0f6ff"
                    border.color: "#cce0f5"
                    border.width: 1

                    Row {
                        id: bannerRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "›"
                            font.pixelSize: Theme.Typography.body
                            color: "#3b7ec8"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width - 28
                            text: qsTr("Instantiation is available in the Linux CLI client.")
                            font.pixelSize: Theme.Typography.caption
                            color: "#1e4d8c"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    text: qsTr("1. Install the CLI client")
                    font.pixelSize: Theme.Typography.caption
                    font.weight: Font.Medium
                    color: Theme.Colors.textTitle
                }

                Rectangle {
                    width: parent.width
                    height: codeText1.implicitHeight + 24
                    radius: 6
                    color: "#1e2d3d"

                    Text {
                        id: codeText1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        text: qsTr("# Add APT source") + "\necho 'deb [trusted=yes] https://repo.yeez.tech stable main' | sudo tee /etc/apt/sources.list.d/yeez-tech.list >/dev/null\n\n" + qsTr("# Update package index") + "\nsudo apt update\n\n" + qsTr("# Install client") + "\nsudo apt install -y datasafebox-cmd-cli"
                        font.family: "Consolas, Courier New, monospace"
                        font.pixelSize: Theme.Typography.small
                        color: "#e8edf3"
                        wrapMode: Text.WrapAnywhere
                        lineHeight: 1.6
                    }
                }

                Text {
                    text: qsTr("2. Security domain usage workflow")
                    font.pixelSize: Theme.Typography.caption
                    font.weight: Font.Medium
                    color: Theme.Colors.textTitle
                }

                Rectangle {
                    width: parent.width
                    height: codeText2.implicitHeight + 24
                    radius: 6
                    color: "#1e2d3d"

                    Text {
                        id: codeText2
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        text: qsTr("# Step 1: Login") + "\ndv auth login\n\n" + qsTr("# Step 2: List visible security domains") + "\ndv domain list\n\n" + qsTr("# Step 3: Apply for instance creation") + "\ndv instance create \"trade-domain-001\" -n \"instance-wangfang-01\" --disk \"/data/safebox\"\n\n" + qsTr("# Step 4: Start authorized instance") + "\ndv instance start instance-wangfang-01 --force"
                        font.family: "Consolas, Courier New, monospace"
                        font.pixelSize: Theme.Typography.small
                        color: "#e8edf3"
                        wrapMode: Text.WrapAnywhere
                        lineHeight: 1.6
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.Colors.borderSeparator
        }

        Item {
            width: parent.width
            height: 56

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 12

                SecondaryButton {
                    text: qsTr("View full documentation")
                    onClicked: Qt.openUrlExternally("https://help.yeez.tech/docs/dsbox-cli-userguide")
                }
            }
        }
    }
}
