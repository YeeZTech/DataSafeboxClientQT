import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "." as Theme

Rectangle {
    id: root
    color: Theme.Colors.backgroundWhite

    property string domainName: ""
    property string domainPubKey: ""
    property string instanceName: ""  // 实例名称
    property string instanceDuration: ""  // 实例时长（月）
    property string selectedDiskDisplay: ""  // Display name for the selected disk
    property string selectedDisk: ""  // Path of the selected disk
    property int selectedDiskSizeMB: 0  // Size of the selected disk in MB
    property string lastProcessFolder: ""  // 记录上次选择的进程路径

    // Form validation
    property bool isValid: instanceName.trim() !== "" && instanceDuration.trim() !== "" && selectedDisk !== ""

    signal canceled
    signal submitted(string name, int duration, string diskPartition, int diskSizeMB, var processes)

    ListModel {
        id: processListModel
    }

    function resetForm() {
        instanceName = "";
        instanceDuration = "";
        selectedDiskDisplay = "";
        selectedDisk = "";
        selectedDiskSizeMB = 0;
        processListModel.clear();
        if (instanceNameInput) {
            instanceNameInput.text = "";
        }
        if (instanceDurationInput) {
            instanceDurationInput.text = "";
        }
        if (diskCombo) {
            diskCombo.currentIndex = -1;
        }
    }

    function resetDiskSelection() {
        selectedDiskDisplay = "";
        selectedDisk = "";
        selectedDiskSizeMB = 0;
        if (diskCombo) {
            diskCombo.currentIndex = -1;
        }
    }

    function getProcessList() {
        var arr = [];
        for (var i = 0; i < processListModel.count; i++) {
            var it = processListModel.get(i);
            arr.push({
                name: it.name,
                path: it.path
            });
        }
        return arr;
    }

    onVisibleChanged: {
        if (visible) {
            resetForm();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            width: parent.width
            height: 80
            border.color: Theme.Colors.borderSlate
            border.width: 1

            SelectableText {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Create Security Domain Instance")
                font.pixelSize: 24
                font.weight: Font.Medium
                color: "#1d293d"
            }
        }

        // Content area
        ScrollView {
            width: parent.width
            height: parent.height - 160  // Header + Footer
            contentWidth: Math.max(contentColumn.width + contentColumn.anchors.leftMargin * 2, width)
            contentHeight: contentColumn.height
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }

            Column {
                id: contentColumn
                width: 832
                anchors.top: parent.top
                anchors.topMargin: 32  // 与 design system 主列 32px 边距一致
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24  // 垂直节奏 24px

                Row {
                    spacing: 24
                    height: 34
                    width: parent.width

                    Item {
                        width: 176
                        height: 34

                        SelectableText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 0
                            text: qsTr("Security Domain:")
                            font.pixelSize: 16
                            color: "#314158"
                        }
                    }

                    Item {
                        width: 448
                        height: 34

                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.domainName
                            font.pixelSize: 16
                            color: "#0f172b"
                        }
                    }
                }
                Row {
                    spacing: 24
                    height: 44
                    width: parent.width

                    Item {
                        width: 176
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter

                        SelectableText {
                            id: instanceNameLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Name:")
                            font.pixelSize: 16
                            color: "#314158"
                        }

                        Text {
                            anchors.right: instanceNameLabel.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "*"
                            font.pixelSize: 16
                            color: "#fb2c36"
                        }
                    }

                    Rectangle {
                        width: 448
                        height: 44
                        radius: 8
                        color: {
                            if (instanceNameInput.activeFocus)
                                return Theme.Colors.backgroundWhite;
                            if (instanceNameInput.text.length > 0)
                                return Theme.Colors.backgroundWhite;
                            return instanceNameMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite;
                        }
                        border.color: "#79aecd"
                        border.width: 1.3
                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }

                        TextInput {
                            id: instanceNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            color: "#0f172b"
                            selectByMouse: true
                            selectionColor: "#d4e4f1"
                            selectedTextColor: "#0f172b"

                            onTextChanged: {
                                root.instanceName = text;
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: qsTr("Please enter an instance name")
                                font.pixelSize: 14
                                color: "#5a7c9b"
                                visible: !instanceNameInput.text && !instanceNameInput.activeFocus
                            }
                        }

                        InputContextMenu {
                            anchors.fill: parent
                            target: instanceNameInput
                        }

                        MouseArea {
                            id: instanceNameMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            cursorShape: Qt.IBeamCursor
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: 44

                    // Label container
                    Item {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 176
                        height: 34

                        SelectableText {
                            id: instanceDurationLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Duration:")
                            font.pixelSize: 16
                            color: "#314158"
                        }

                        Text {
                            anchors.right: instanceDurationLabel.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "*"
                            font.pixelSize: 16
                            color: "#fb2c36"
                        }
                    }

                    // Input and unit container
                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: 200
                        anchors.top: parent.top
                        width: 448
                        height: 44

                        // Input field
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: {
                                if (instanceDurationInput.activeFocus)
                                    return Theme.Colors.backgroundWhite;
                                if (instanceDurationInput.text.length > 0)
                                    return Theme.Colors.backgroundWhite;
                                return instanceDurationMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite;
                            }
                            border.color: "#79aecd"
                            border.width: 1.3
                            Behavior on color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }

                            TextInput {
                                id: instanceDurationInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 48  // Space for "月" text
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 14
                                color: "#0f172b"
                                selectByMouse: true
                                selectionColor: "#d4e4f1"
                                selectedTextColor: "#0f172b"
                                validator: IntValidator {
                                    bottom: 1
                                    top: 999
                                }

                                onTextChanged: {
                                    root.instanceDuration = text;
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Please enter the instance duration")
                                    font.pixelSize: 14
                                    color: "#5a7c9b"
                                    visible: !instanceDurationInput.text && !instanceDurationInput.activeFocus
                                }
                            }

                            InputContextMenu {
                                anchors.fill: parent
                                anchors.rightMargin: 48
                                target: instanceDurationInput
                            }

                            MouseArea {
                                id: instanceDurationMouseArea
                                anchors.fill: parent
                                anchors.rightMargin: 48
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                            }

                            // Unit "月" text - positioned at right side
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("months")
                                font.pixelSize: 16
                                color: "#62748e"
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 44

                    // Label container - absolute positioned
                    Item {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 176
                        height: 34

                        SelectableText {
                            id: diskLabelText
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Disk Partition:")
                            font.pixelSize: 16
                            color: "#314158"
                        }

                        Text {
                            id: asteriskText
                            anchors.right: diskLabelText.left
                            anchors.rightMargin: 6  // Same spacing as "安全域名称" and "实例费用支付方" fields
                            anchors.verticalCenter: parent.verticalCenter
                            text: "*"
                            font.pixelSize: 16
                            color: "#fb2c36"
                        }
                    }

                    // Input and button container - absolute positioned
                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: 200
                        anchors.top: parent.top
                        width: 448
                        height: 44

                        // Input field
                        Rectangle {
                            id: diskInput
                            anchors.fill: parent
                            radius: 8
                            border.color: "#79aecd"
                            border.width: 1.3
                            color: diskInputArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                            Behavior on color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    id: diskText
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 96
                                    text: root.selectedDiskDisplay || qsTr("Please select a disk partition")
                                    font.pixelSize: 14
                                    color: root.selectedDiskDisplay ? "#0f172b" : "#5a7c9b"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: diskInputArea
                                anchors.fill: parent
                                anchors.rightMargin: 96  // Don't trigger on button area
                                hoverEnabled: true
                                onClicked: {
                                    diskCombo.popup.open();
                                }
                            }
                        }

                        // Select Disk button - overlays on top of input (absolute positioned inside)
                        Rectangle {
                            z: 2  // Ensure button is above input field
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            width: 80
                            height: 36
                            radius: 8

                            color: selectDiskArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.2) : Theme.Colors.primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Select Disk")
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "white"
                            }

                            MouseArea {
                                id: selectDiskArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    diskCombo.popup.open();
                                }
                            }
                        }

                        // Hidden ComboBox for dropdown functionality
                        ComboBox {
                            id: diskCombo
                            anchors.fill: parent
                            visible: false
                            currentIndex: -1  // No default selection

                            model: [qsTr("Local Disk (C:)"), qsTr("Local Disk (D:)")]

                            // Custom delegate for each option
                            delegate: ItemDelegate {
                                width: diskCombo.width
                                height: 44  // Increased height to prevent text movement on hover
                                hoverEnabled: false  // Disable default hover effect

                                scale: itemMouseArea.containsMouse ? 1.03 : 1.0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                contentItem: Text {
                                    text: modelData
                                    font.pixelSize: 14  // Same font size as placeholder "请选择磁盘分区"
                                    color: parent.highlighted ? Theme.Colors.primaryText : Theme.Colors.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 12
                                }

                                background: Rectangle {
                                    radius: 4  // Rounded corners for each item
                                    color: parent.highlighted ? Theme.Colors.primary : "transparent"

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            diskCombo.currentIndex = index;
                                            root.selectedDiskDisplay = modelData;
                                            diskCombo.popup.close();
                                        }
                                    }
                                }
                            }

                            // Custom popup with rounded corners and no borders
                            popup: Popup {
                                y: diskCombo.height
                                width: diskCombo.width
                                implicitHeight: Math.min(contentItem.contentHeight + 8, 220)  // Max 220px height (5 items)
                                padding: 4  // Increased padding for better spacing

                                // Remove any default styling
                                margins: 0
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                background: Rectangle {
                                    radius: 8  // Rounded corners for popup
                                    color: Theme.Colors.backgroundWhite
                                    border.width: 1.3
                                    border.color: "#79aecd"  // Same as input field border
                                    // Remove any default effects
                                    layer.enabled: false
                                }

                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    height: Math.min(contentHeight, 212)  // Max height for scrolling
                                    model: diskCombo.popup.visible ? diskCombo.delegateModel : null
                                    currentIndex: diskCombo.highlightedIndex
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 0  // Small spacing between items to prevent overlap

                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                        width: 8
                                        contentItem: Rectangle {
                                            implicitWidth: 6
                                            radius: 3
                                            color: parent.pressed ? "#5a7c9b" : (parent.hovered ? "#79aecd" : "#cad5e2")
                                            opacity: parent.active ? 1.0 : 0.6
                                        }
                                    }
                                }
                            }

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    var displayName = model[currentIndex];
                                    root.selectedDiskDisplay = displayName;
                                    root.selectedDisk = displayName.indexOf("D") >= 0 ? "D:/" : "C:/";
                                    root.selectedDiskSizeMB = 500 * 1024;
                                } else {
                                    root.selectedDiskDisplay = "";
                                    root.selectedDisk = "";
                                    root.selectedDiskSizeMB = 0;
                                }
                            }
                        }
                    }
                }

                // Process Whitelist Group
                Column {
                    width: parent.width
                    spacing: 12

                    // Title Row
                    Row {
                        spacing: 24
                        width: parent.width
                        height: 36

                        // Label Area
                        Item {
                            width: 176
                            height: parent.height

                            SelectableText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("App Whitelist:")
                                font.pixelSize: 16
                                color: "#314158"
                            }
                        }

                        // Add Button Area
                        Item {
                            width: parent.width - 176 - 24
                            height: parent.height

                            Rectangle {
                                id: addProcessBtn
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: addProcessText.contentWidth + 32
                                height: 36
                                radius: 8
                                color: {
                                    if (addProcessArea.pressed)
                                        return Qt.darker("#0f4c81", 1.2);  // 点击时颜色加深
                                    if (addProcessArea.containsMouse)
                                        return Qt.lighter("#0f4c81", 1.15);  // 悬停时颜色变浅
                                    return "#0f4c81";  // 正常状态主题色
                                }
                                border.color: addProcessBtn.color
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    id: addProcessText
                                    anchors.centerIn: parent
                                    text: qsTr("Add")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "white"
                                }

                                MouseArea {
                                    id: addProcessArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // 设置默认目录：优先上次目录
                                        if (root.lastProcessFolder && root.lastProcessFolder.length > 0) {
                                            processFileDialog.folder = root.lastProcessFolder;
                                        }
                                        processFileDialog.open();
                                    }
                                }
                            }
                        }
                    }

                    // Process List Table (One big container)
                    Rectangle {
                        visible: processListModel.count > 0
                        // Align Left Border with "实"(Shi) of "实例磁盘分区：" (approx 176 - 116 = 60px from left)
                        x: 60
                        width: 588  // 648 - 60
                        height: processRows.height + 2  // border width adjustment
                        radius: 8
                        color: "transparent"
                        border.color: "#cad5e2"
                        border.width: 1

                        // We use a Column inside
                        Column {
                            id: processRows
                            width: parent.width

                            Repeater {
                                model: processListModel
                                delegate: Item {
                                    width: 588
                                    height: 44

                                    // Separator line between rows (except top)
                                    Rectangle {
                                        visible: index > 0
                                        width: parent.width
                                        height: 1
                                        color: "#e2e8f0"
                                        anchors.top: parent.top
                                    }

                                    Row {
                                        width: parent.width
                                        height: parent.height - (index > 0 ? 1 : 0) // adjust for separator
                                        y: index > 0 ? 1 : 0

                                        // Process Name (Left - Aligns with Labels)
                                        // Width adjusted: 176 - 60 = 116
                                        Item {
                                            width: 116
                                            height: parent.height

                                            SelectableText {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.name || ""
                                                font.pixelSize: 14
                                                color: "#0f172b"
                                                horizontalAlignment: Text.AlignRight
                                                // Ensure text respects the width and aligns right
                                                width: parent.width
                                                clip: true
                                            }
                                        }

                                        // Spacer (Matches Gap)
                                        Item {
                                            width: 24
                                            height: parent.height
                                        }

                                        // Process Path (Right - Aligns with Inputs area)
                                        Item {
                                            width: 448
                                            height: parent.height

                                            // Make this a RowLayout to handle text and button
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                SelectableText {
                                                    text: model.path || ""
                                                    font.pixelSize: 14
                                                    color: "#64748b"
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    clip: true

                                                    // Tooltip for full path
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.NoButton // Pass through clicks to SelectableText
                                                        cursorShape: Qt.IBeamCursor // Match text cursor

                                                        ToolTip.delay: 500
                                                        ToolTip.visible: containsMouse
                                                        ToolTip.text: model.path || ""
                                                    }
                                                }

                                                // X Button
                                                Rectangle {
                                                    Layout.preferredWidth: 24
                                                    Layout.preferredHeight: 24
                                                    radius: 12
                                                    color: removeArea.containsMouse ? "#fee2e2" : "transparent"
                                                    Layout.alignment: Qt.AlignVCenter

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: removeArea.containsMouse ? "#ef4444" : "#94a3b8"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Medium
                                                        y: -1
                                                    }

                                                    MouseArea {
                                                        id: removeArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: processListModel.remove(index)
                                                    }
                                                }
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
                    height: 80
                }
            }
        }

        // Footer with Submit button
        Rectangle {
            width: parent.width
            height: 80
            border.color: Theme.Colors.borderSlate
            border.width: 1
            color: Theme.Colors.backgroundWhite

            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 44
                radius: 8

                color: {
                    if (!root.isValid)
                        return Theme.Colors.buttonDisabled;
                    if (submitArea.pressed)
                        return Qt.lighter(Theme.Colors.primary, 1.3);  // Lighter when pressed
                    if (submitArea.containsMouse)
                        return Qt.lighter(Theme.Colors.primary, 1.2);  // Lighter on hover
                    return Theme.Colors.primary;  // Default
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Submit Application")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: root.isValid ? Theme.Colors.primaryText : Theme.Colors.textSecondary
                }

                MouseArea {
                    id: submitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.isValid
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        if (root.isValid) {
                            var duration = parseInt(root.instanceDuration) || 0;
                            root.submitted(root.instanceName, duration, selectedDisk, selectedDiskSizeMB, getProcessList());
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {}

    FileDialog {
        id: processFileDialog
        title: qsTr("Select a program to add")
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var url = processFileDialog.file.toString();
            var localPath = "";
            if (url.startsWith("file:///")) {
                localPath = decodeURIComponent(url.substring(8));
            } else if (url.startsWith("file://")) {
                localPath = decodeURIComponent(url.substring(7));
            } else {
                localPath = decodeURIComponent(url);
            }
            if (localPath && localPath.length > 0) {
                var fileName = localPath.split(/[/\\]/).pop();
                processListModel.append({
                    name: fileName,
                    path: localPath
                });

                // 记录当前目录，便于下次默认打开上次路径
                var folderUrl = url.substring(0, url.lastIndexOf("/"));
                if (folderUrl && folderUrl.length > 0) {
                    root.lastProcessFolder = folderUrl;
                }
            }
        }
    }
}
