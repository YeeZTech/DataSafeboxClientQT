import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "." as Theme

Dialog {
    id: root
    modal: true
    focus: true
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0
    
    width: 448
    height: bgRect.height
    
    background: Rectangle {
        id: bgRect
        color: "white"
        radius: 10
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
        height: mainLayout.height + 48 // 24 top + 24 bottom padding
    }

    property string instanceName: ""
    property string selectedFile: ""
    property string domainPrivateKey: ""  // Private key of the security domain
    property string instanceBasePath: ""  // Destination directory for decrypted files

    signal importConfirmed(string filePath)
    signal importStarted(string filePath)
    signal importFailed(string filePath, string reason)
    signal importSuccess(string filePath)

    function openForInstance(targetInstance, privateKey, basePath) {
        instanceName = targetInstance || ""
        domainPrivateKey = privateKey || ""
        instanceBasePath = basePath || ""
        selectedFile = ""
        open()
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select file to import")
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var url = selectedFile.toString()
            if (url.startsWith("file:///")) {
                root.selectedFile = decodeURIComponent(url.substring(8))
            } else if (url.startsWith("file://")) {
                root.selectedFile = decodeURIComponent(url.substring(7))
            } else {
                root.selectedFile = decodeURIComponent(url)
            }
        }
    }

    contentItem: Item {
        anchors.fill: parent
        
        Column {
            id: mainLayout
            anchors.centerIn: parent
            width: parent.width - 50 // 25 left + 25 right padding
            spacing: 0
            
            // Header with Title and Close button
            Item {
                width: parent.width
                height: 24
                
                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Import File")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0f172b"
                }

                Rectangle {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 12
                    color: closeArea.containsMouse ? "#f0f4fa" : "transparent"

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 1.5
                        rotation: 45
                        color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 1.5
                        rotation: -45
                        color: closeArea.containsMouse ? "#0f4c81" : "#0f172b"
                    }
                }
            }

            // Margin after header
            Item { width: parent.width; height: 16 }

            // Content Area - File Selection
            Column {
                width: parent.width
                spacing: 8

                SelectableText {
                    width: parent.width
                    text: qsTr("Select file:")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "#314158"
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
                        border.color: "#cad5e2"
                        border.width: 1

                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24
                            text: root.selectedFile || qsTr("No file selected")
                            font.pixelSize: 14
                            color: root.selectedFile ? "#0f172b" : (fileInputArea.containsMouse ? "#0f4c81" : "#5a7c9b")
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
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.primaryText
                        }
                    }
                }
            }

            // Margin before buttons
            Item { width: parent.width; height: 24 }

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
                            if (cancelArea.pressed) return "#bedbff"
                            if (cancelArea.containsMouse) return "#e8f8ff"
                            return "white"
                        }
                        border.width: 1
                        border.color: {
                            if (cancelArea.pressed) return "#add3e6"
                            if (cancelArea.containsMouse) return "#79aecd"
                            return "#cad5e2"
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#314158"
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
                                    progressDialog.progressTitle = qsTr("Importing...")
                                    progressDialog.progress = 0
                                    progressDialog.open()
                                    root.importStarted(root.selectedFile)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Import")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.primaryText
                        }
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
                    progressDialog.progress = Math.min(100, progressDialog.progress + 20)
                } else {
                    progressPollTimer.stop()
                    progressDialog.close()
                    successDialog.message = qsTr("Import successful")
                    successDialog.open()
                }
            }
        }
        
        onOpened: {
            progress = 0
            progressPollTimer.start()
        }
        
        onClosed: {
            progressPollTimer.stop()
            progress = 0
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
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
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
                font.pixelSize: 14
                color: "#62748e"
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
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
            }
            
            SelectableText {
                id: successMessageText
                width: parent.width
                text: successDialog.message
                font.pixelSize: 14
                color: "#314158"
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
                    color: hovered ? Qt.darker("#0f4c81", 1.3) : "#0f4c81"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("OK")
                        font.pixelSize: 14
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
                            successDialog.close()
                            root.importSuccess(root.selectedFile)
                            root.close()
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
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#0f172b"
            }
            
            SelectableText {
                width: parent.width
                text: errorDialog.text
                font.pixelSize: 14
                color: "#314158"
                wrapMode: TextEdit.Wrap
            }
            
            Row {
                anchors.right: parent.right
                spacing: 8
                
                Rectangle {
                    width: 60
                    height: 36
                    radius: 8
                    color: "#0f4c81"
                    
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("OK")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            errorDialog.close()
                        }
                    }
                }
            }
        }
    }
}
