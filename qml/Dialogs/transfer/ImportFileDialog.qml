import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    title: qsTr("Import File")

    property string instanceName: ""
    property string selectedFile: ""
    property string domainPrivateKey: ""  // Private key of the security domain
    property string instanceBasePath: ""  // Destination directory for decrypted files

    signal importConfirmed(string filePath)
    signal importStarted(string filePath)
    signal importFailed(string filePath, string reason)
    signal importSuccess(string filePath)

    function openForInstance(targetInstance, privateKey, basePath) {
        instanceName = targetInstance || "";
        domainPrivateKey = privateKey || "";
        instanceBasePath = basePath || "";
        selectedFile = "";
        open();
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select file to import")
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var url = selectedFile.toString();
            if (url.startsWith("file:///")) {
                root.selectedFile = decodeURIComponent(url.substring(8));
            } else if (url.startsWith("file://")) {
                root.selectedFile = decodeURIComponent(url.substring(7));
            } else {
                root.selectedFile = decodeURIComponent(url);
            }
        }
    }

    Column {
        id: mainLayout
        width: parent.width
        spacing: 0

        // Margin after header
        Item {
            width: parent.width
            height: 16
        }

        // Content Area - File Selection
        Column {
            width: parent.width
            spacing: 8

            SelectableText {
                width: parent.width
                text: qsTr("Select file:")
                font.pixelSize: Theme.Typography.body
                font.weight: Font.Medium
                color: Theme.Colors.textLabel
            }

            Row {
                width: parent.width
                spacing: 8
                height: 36

                // Input field
                Rectangle {
                    id: fileInputRect
                    width: parent.width - browseButton.width - 8
                    height: 36
                    radius: 8
                    color: fileInputArea.containsMouse ? "#e9eef6" : Theme.Colors.inputBackground
                    border.color: Theme.Colors.borderField
                    border.width: 1

                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        text: root.selectedFile || qsTr("No file selected")
                        font.pixelSize: Theme.Typography.body
                        color: root.selectedFile ? Theme.Colors.textHeading : (fileInputArea.containsMouse ? Theme.Colors.primary : Theme.Colors.textSecondary)
                        elide: Text.ElideMiddle
                    }

                    MouseArea {
                        id: fileInputArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }
                }

                // Browse button
                Rectangle {
                    id: browseButton
                    width: 62
                    height: 36
                    radius: 8
                    color: browseArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                    border.color: Theme.Colors.primary
                    border.width: 1

                    MouseArea {
                        id: browseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Browse")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }
                }
            }
        }

        // Margin before buttons
        Item {
            width: parent.width
            height: 24
        }

        // Bottom Buttons
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.centerIn: parent
                spacing: 8

                // Cancel button
                Rectangle {
                    width: 128
                    height: 36
                    radius: 8
                    color: {
                        if (cancelArea.pressed)
                            return "#bedbff";
                        if (cancelArea.containsMouse)
                            return "#e8f8ff";
                        return "white";
                    }
                    border.width: 1
                    border.color: {
                        if (cancelArea.pressed)
                            return "#add3e6";
                        if (cancelArea.containsMouse)
                            return "#79aecd";
                        return Theme.Colors.borderField;
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: Theme.Colors.textLabel
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                // Import button
                Rectangle {
                    id: importButton
                    width: 128
                    height: 36
                    radius: 8
                    color: (importArea.containsMouse && root.selectedFile.length > 0) ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                    opacity: root.selectedFile.length > 0 ? 1.0 : 0.5

                    MouseArea {
                        id: importArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.selectedFile.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.selectedFile.length > 0) {
                                progressDialog.progressTitle = qsTr("Importing...");
                                progressDialog.progress = 0;
                                progressDialog.open();
                                root.importStarted(root.selectedFile);
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Import")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: Theme.Colors.primaryText
                    }
                }
            }
        }
    }

    // Progress dialog for decryption
    Popup {
        id: progressDialog
        width: 300
        height: 150
        modal: true
        closePolicy: Popup.NoAutoClose
        x: (root.width - width) / 2
        y: (root.height - height) / 2

        property int progress: 0
        property string progressTitle: qsTr("Importing...")

        Timer {
            id: progressPollTimer
            interval: 200
            running: progressDialog.visible
            repeat: true
            onTriggered: {
                if (progressDialog.progress < 100) {
                    progressDialog.progress = Math.min(100, progressDialog.progress + 20);
                } else {
                    progressPollTimer.stop();
                    progressDialog.close();
                    successDialog.message = qsTr("Import successful");
                    successDialog.open();
                }
            }
        }

        onOpened: {
            progress = 0;
            progressPollTimer.start();
        }

        onClosed: {
            progressPollTimer.stop();
            progress = 0;
        }

        background: Rectangle {
            radius: 10
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            SelectableText {
                width: parent.width
                text: progressDialog.progressTitle
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
                horizontalAlignment: Text.AlignHCenter
            }

            ProgressBar {
                id: progressBar
                width: Math.min(parent.width, 320)
                anchors.horizontalCenter: parent.horizontalCenter
                from: 0
                to: 100
                value: progressDialog.progress
            }

            SelectableText {
                width: parent.width
                text: progressDialog.progress + "%"
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textCaption
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Success dialog
    Popup {
        id: successDialog
        width: 400
        height: successDialogContent.implicitHeight + 40  // 40 = margins (20 * 2)
        modal: true
        x: (root.width - width) / 2
        y: (root.height - height) / 2

        property string message: ""

        background: Rectangle {
            radius: 10
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1
        }

        Column {
            id: successDialogContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            SelectableText {
                width: parent.width
                text: qsTr("Import Successful")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            SelectableText {
                id: successMessageText
                width: parent.width
                text: successDialog.message
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textLabel
                wrapMode: TextEdit.Wrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 60
                    height: 36
                    radius: 8
                    property bool hovered: false
                    color: hovered ? Qt.darker(Theme.Colors.primary, 1.3) : Theme.Colors.primary
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("OK")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: {
                            successDialog.close();
                            root.importSuccess(root.selectedFile);
                            root.close();
                        }
                    }
                }
            }
        }
    }

    // Error dialog
    Popup {
        id: errorDialog
        width: 400
        height: 150
        modal: true
        x: (root.width - width) / 2
        y: (root.height - height) / 2

        property string text: ""

        background: Rectangle {
            radius: 10
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            SelectableText {
                width: parent.width
                text: qsTr("Error")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }

            SelectableText {
                width: parent.width
                text: errorDialog.text
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textLabel
                wrapMode: TextEdit.Wrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 60
                    height: 36
                    radius: 8
                    color: Theme.Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("OK")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            errorDialog.close();
                        }
                    }
                }
            }
        }
    }
}
