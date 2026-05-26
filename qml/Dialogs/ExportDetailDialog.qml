import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root
    width: 510
    height: mainColumn.implicitHeight + 36  // 24px top + 12px bottom
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent ? (parent.width - width) / 2 : 0)
    y: (parent ? (parent.height - height) / 2 : 0)
    
    // Properties for export detail data
    property string exportId: ""
    property string fileCode: ""   // fileCode of the single file in this export apply
    property string fileHash: ""   // file hash used by approveApply for export approve
    property string applicant: ""
    readonly property int fileCount: (files && files.length) ? files.length : 0
    property var fileSize: 0  // raw bytes value
    property string status: "待审核"  // "待审核", "已授权", "已拒绝"
    property string applyTime: ""
    property string instanceName: ""
    property var files: []  // Array of file names
    property string reason: ""
    property bool isCreator: false
    property bool allowApproveReject: true  // If true, show approve/reject buttons for pending status (from SecurityDomainDetail)
                                           // If false, always show close button (from SecurityInstanceDetail)
    readonly property int fileListRowHeight: 20
    readonly property int fileListRowSpacing: 8
    readonly property int fileListVerticalPadding: 26  // 13px top/bottom margins inside ScrollView
    readonly property int fileListMaxHeight: 158
    readonly property int reasonSectionTopSpacing: 20
    readonly property int reasonMaxVisibleLines: 3
    readonly property int reasonTextFontPixelSize: 16
    readonly property int baseDialogHeight: 380  // Optimized to reduce bottom padding

    FontMetrics {
        id: reasonFontMetrics
        font.pixelSize: reasonTextFontPixelSize
    }

    readonly property real reasonMaxContentHeight: reasonFontMetrics.height * reasonMaxVisibleLines
    
    // Signals
    signal approveClicked()
    signal rejectClicked()
    signal cancelClicked()
    
    readonly property var statusStyle: Theme.Colors.getStatusColor(status)

    function formatApplyTimeToMinute(raw) {
        var s = (raw || "").toString().trim()
        if (!s) return ""

        // Match: yyyy-MM-dd HH:mm[:ss]
        var m = s.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})(?::\d{2})?$/)
        if (m) return m[1] + " " + m[2]

        // Match ISO: yyyy-MM-ddTHH:mm[:ss][.sss][Z|+08:00]
        var iso = s.match(/^(\d{4}-\d{2}-\d{2})[T\s](\d{2}:\d{2})(?::\d{2})?/)
        if (iso) return iso[1] + " " + iso[2]

        return s
    }

    function formatFileSizeLowercase(bytesValue) {
        var s = (Theme.Utils.formatSize(bytesValue) || "").toString().trim()
        // Normalize units to lowercase, including single-byte unit "B" -> "b"
        return s.replace(/\b([KMGT]?B)\b/g, function(unit) {
            return unit.toLowerCase()
        })
    }
    
    function calculateFileListHeight() {
        var count = root.files ? root.files.length : 0
        if (count < 1)
            count = 1  // keep a minimal footprint even when there are no files

        var contentHeight = (count * fileListRowHeight) + ((count - 1) * fileListRowSpacing)
        var totalHeight = contentHeight + fileListVerticalPadding
        return Math.min(fileListMaxHeight, totalHeight)
    }

    function calculateReasonSectionHeight() {
        // If no reason, return 0 to hide the entire section
        if (!root.reason || root.reason.length === 0) {
            return 0
        }
        
        if (!reasonColumn || !reasonBox || !reasonLabel) {
            return 0
        }
        var labelHeight = reasonLabel.implicitHeight || 0
        var boxHeight = Math.max(48, Math.min(reasonMaxContentHeight + 24, reasonText.implicitHeight + 24))
        var spacing = reasonColumn.spacing || 0
        return reasonSectionTopSpacing + labelHeight + spacing + boxHeight
    }
    
    // Remove default Popup background and border
    background: null
    padding: 0
    
    // Main dialog container
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.Colors.backgroundWhite
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
        
        Column {
            id: mainColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 0
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("File Export Details")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0f172b"
                    font.letterSpacing: -0.44
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
                        onClicked: {
                            root.close()
                            root.cancelClicked()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 18
                        color: closeArea.containsMouse ? "#0f4c81" : "#314158"
                    }
                }
            }
            
            // Spacing between title and content
            Item {
                width: parent.width
                height: 28
            }
            Column {
                width: parent.width
                spacing: 16
                Row {
                    width: parent.width
                    spacing: 16
                    
                    // Application Number column
                    Column {
                        width: (parent.width - 16) / 2  // 2 columns with 16px gap
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("Application No.")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        
                        Text {
                            width: parent.width
                            text: root.exportId
                            font.pixelSize: 16
                            color: "#000000"
                            font.letterSpacing: -0.31
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                        }
                    }
                    
                    // Status column
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("Status")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        Rectangle {
                            width: exportStatusText.implicitWidth + 18
                            height: 26
                            radius: 8
                            color: statusStyle.bg
                            border.color: statusStyle.border
                            border.width: 1
                            
                            SelectableText {
                                id: exportStatusText
                                anchors.centerIn: parent
                                text: window.translateStatus(root.status)
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: statusStyle.text
                            }
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 16
                    
                    // Applicant column
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("Applicant")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        
                        Text {
                            width: parent.width
                            text: root.applicant
                            font.pixelSize: 16
                            color: "#000000"
                            font.letterSpacing: -0.31
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                        }
                    }
                    
                    // Application Time column
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("Application Time")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        
                        SelectableText {
                            text: root.formatApplyTimeToMinute(root.applyTime)
                            font.pixelSize: 16
                            color: "#000000"
                            font.letterSpacing: -0.31
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 16
                    
                    // File Count column
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("File Count")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        
                        SelectableText {
                            text: root.fileCount.toString()
                            font.pixelSize: 16
                            color: "#000000"
                            font.letterSpacing: -0.31
                        }
                    }
                    
                    // File Size column
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 4
                        
                        SelectableText {
                            text: qsTr("File Size")
                            font.pixelSize: 14
                            color: "#62748e"
                            font.letterSpacing: -0.15
                        }
                        
                        SelectableText {
                            text: root.formatFileSizeLowercase(root.fileSize)
                            font.pixelSize: 16
                            color: "#000000"
                            font.letterSpacing: -0.31
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8
                    
                    SelectableText {
                        text: qsTr("Files Requested for Export")
                        font.pixelSize: 14
                        color: "#62748e"
                        font.letterSpacing: -0.15
                    }
                    
                    // File list container - dynamic height up to 158px based on file count
                    Rectangle {
                        width: parent.width
                        height: calculateFileListHeight()
                        radius: 8
                        color: "transparent"
                        border.color: "#cad5e2"
                        border.width: 1
                        
                        // Scrollable file list
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 13
                            clip: true
                            
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            
                            Column {
                                width: parent.parent.width - 26  // Account for margins (13px * 2)
                                spacing: 8
                                
                                Repeater {
                                    model: root.files
                                    
                                    delegate: Row {
                                        width: parent.width
                                        height: 20
                                        spacing: 8  // gap between icon and text
                                        Image {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "icons/icon-file-generic.svg"
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                        }
                                        
                                        Text {
                                            width: parent.width - 16 - 8  // subtract icon width and spacing
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (typeof modelData === "string") ? modelData
                                                  : (modelData.fileName || modelData.filePath || modelData.name || "")
                                            font.pixelSize: 14
                                            color: "#000000"
                                            font.letterSpacing: -0.15
                                            elide: Text.ElideMiddle
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Item {
                width: parent.width
                height: reasonSectionTopSpacing
                visible: root.reason && root.reason.length > 0
            }

            // Export reason section
            Column {
                id: reasonColumn
                width: parent.width
                spacing: 8
                visible: root.reason && root.reason.length > 0

                SelectableText {
                    id: reasonLabel
                    text: qsTr("Export Reason")
                    font.pixelSize: 14
                    color: "#62748e"
                    font.letterSpacing: -0.15
                }

                Rectangle {
                    id: reasonBox
                    width: parent.width
                    radius: 8
                    color: "transparent"
                    border.color: "#cad5e2"
                    border.width: 1
                    height: Math.max(48, Math.min(reasonMaxContentHeight + 24, reasonText.implicitHeight + 24))

                    Flickable {
                        id: reasonFlickable
                        anchors.fill: parent
                        anchors.margins: 13
                        clip: true
                        contentWidth: reasonText.width
                        contentHeight: reasonText.contentHeight
                        interactive: reasonText.contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            id: reasonScrollBar
                            policy: ScrollBar.AsNeeded
                            implicitWidth: 6
                        }
                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }

                        SelectableText {
                            id: reasonText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.rightMargin: reasonScrollBar.visible ? reasonScrollBar.width : 0
                            text: root.reason && root.reason.length > 0 ? root.reason : ""
                            font.pixelSize: reasonTextFontPixelSize
                            color: "#000000"
                            wrapMode: TextEdit.Wrap
                        }
                    }
                }
            }
            
            // Spacer between reason section and buttons
            Item {
                width: parent.width
                height: 20
                visible: root.allowApproveReject && root.isCreator && root.status === "待审核"
            }
            Item {
                width: parent.width
                height: 36
                visible: root.allowApproveReject && root.isCreator && root.status === "待审核"

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Reject button - 拒绝 left, 同意 right (Figma order)
                    Rectangle {
                        width: 62
                        height: 36
                        radius: 8
                        property bool hovered: false
                        property bool pressed: false
                        color: pressed ? "#ffe9e9" : (hovered ? "#fff5f5" : Theme.Colors.backgroundWhite)
                        border.color: pressed ? "#ff6b6b" : (hovered ? "#ff9090" : "#ffa2a2")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SelectableText {
                            anchors.centerIn: parent
                            text: qsTr("Reject")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: parent.pressed ? "#9f0006" : (parent.hovered ? "#c50009" : "#e7000b")
                            font.letterSpacing: -0.15
                        }

                        MouseArea {
                            id: rejectArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onPressed: parent.pressed = true
                            onReleased: parent.pressed = false
                            onCanceled: parent.pressed = false
                            onClicked: {
                                root.rejectClicked()
                                root.close()
                            }
                        }
                    }
                    Rectangle {
                        width: 60
                        height: 36
                        radius: 8
                        color: {
                            if (approveArea.pressed) return "#0a3d6b"
                            if (approveArea.containsMouse) return "#0d5a95"
                            return "#0f4c81"
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        visible: root.allowApproveReject && root.isCreator && root.status === "待审核"

                        SelectableText {
                            anchors.centerIn: parent
                            text: qsTr("Approve")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "white"
                            font.letterSpacing: -0.15
                        }

                        MouseArea {
                            id: approveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.approveClicked()
                                root.close()
                            }
                        }
                    }
                }
            }

            Item { width: parent.width; height: 12 }
        }
    }

}
