import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as Theme

Item {
    id: root
    width: parent ? parent.width : 778
    height: parent ? parent.height : 801
    
    property string domainName: ""
    property string payer: ""
    property var payerOptions: ["创建者", "使用者"]
    property var visibleUsers: []
    property string description: ""
    readonly property string trimmedDomainName: domainName.trim()
    readonly property string domainNameError: {
        var name = root.trimmedDomainName
        if (name.length === 0) {
            return ""
        }

        if (name.length < 2 || name.length > 32) {
            return qsTr("Name must be between 2 and 32 characters")
        }

        if (!/^[A-Za-z0-9_\-\u4E00-\u9FFF]+$/.test(name)) {
            return qsTr("Name contains illegal characters, only Chinese, English, numbers, _ and - are supported")
        }

        return ""
    }
    property bool isValid: trimmedDomainName !== "" && domainNameError === "" && payer !== "" && description.length <= 500
    property bool isSubmitting: false
    property var currentUser: null
    // Unified typography
    property string fontFamily: "Microsoft YaHei"
    property int fontSizeTitle: 28
    property int fontSizeLabel: 18
    property int fontSizeBody: 16
    property int fontSizeCaption: 14
    
    signal submit()
    signal cancel()
    
    // Reset form when it becomes visible
    onVisibleChanged: {
        if (visible) {
            resetForm()
        }
    }
    
    // Function to reset all form fields
    function resetForm() {
        isSubmitting = false
        domainName = ""
        payer = ""
        visibleUsers = []
        description = ""
        if (nameInput) {
            nameInput.text = ""
        }
        if (descriptionArea) {
            descriptionArea.text = ""
        }
    }
    
    Column {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            width: parent.width
            height: 79.993
            color: Theme.Colors.backgroundWhite
            border.width: 0
            
            SelectableText {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Create Security Domain")
                font.family: root.fontFamily
                font.pixelSize: root.fontSizeTitle
                font.weight: Font.Medium
                color: Theme.Colors.textTitle
            }
        }
        
        // Form content area
        Rectangle {
            width: parent.width
            height: parent.height - 79.993 - 79.993
            color: Theme.Colors.backgroundWhite  // White background for main content area
            clip: true
            
            Item {
                id: scrollView
                anchors.fill: parent
                clip: true  // Prevent overflow; layout uses responsive widths
                
                Flickable {
                    id: formFlickable
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: formContent.height
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                    }
                    
                Item {
                    id: formContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    property int spacingRow: 40
                    property int labelWidth: 176  // 固定宽度，确保标签对齐
                    property int fieldWidth: Math.max(240, width - labelWidth - spacingRow)  // 根据formContent宽度计算
                    height: descriptionRow.y + descriptionRow.height + 16  // 动态计算高度，底部边距从24改为16
                    
                    // Background MouseArea to clear focus when clicking empty space
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            nameInput.focus = false
                            descriptionArea.focus = false
                            root.forceActiveFocus()
                        }
                    }
                    Row {
                        id: nameRow
                        anchors.top: parent.top
                        anchors.topMargin: 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: formContent.spacingRow
                        height: nameFieldColumn.implicitHeight
                        
                        // Label
                        Item {
                            width: formContent.labelWidth
                            height: 36
                            
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: -4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: "*"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeLabel
                                    color: "#fb2c36"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                SelectableText {
                                    id: nameLabel
                                    text: qsTr("Name:")
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeLabel
                                    color: "#314158"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        
                        // Input field + error message column
                        Column {
                            id: nameFieldColumn
                            width: formContent.fieldWidth
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 36
                                radius: 8
                                antialiasing: true
                                smooth: true
                                clip: true
                                color: {
                                    if (nameInput.activeFocus) return Theme.Colors.backgroundWhite
                                    if (nameInput.text.length > 0) return Theme.Colors.backgroundWhite
                                    return nameInputMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                                }
                                border.color: domainNameErrorText.visible ? "#fb2c36" : "#cad5e2"  // 灰色边框
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeBody
                                    color: "#314158"  // 输入文字颜色
                                    selectByMouse: true
                                    selectionColor: "#d4e4f1"
                                    selectedTextColor: "#0f172b"

                                    onTextChanged: {
                                        root.domainName = text
                                    }

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 0
                                        anchors.rightMargin: 0
                                        anchors.topMargin: 0
                                        anchors.bottomMargin: 0
                                        verticalAlignment: Text.AlignVCenter
                                        text: qsTr("Please enter name")
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSizeBody
                                        color: "#5a7c9b"
                                        visible: !nameInput.text && !nameInput.activeFocus
                                    }
                                }

                                // Right-click context menu for name input
                                InputContextMenu {
                                    anchors.fill: parent
                                    target: nameInput
                                }

                                // Hover detection area
                                MouseArea {
                                    id: nameInputMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor
                                }
                            }

                            Text {
                                id: domainNameErrorText
                                width: parent.width - 12
                                x: 12
                                visible: root.domainNameError.length > 0
                                text: root.domainNameError
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                color: "#fb2c36"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    
                    // Instance Fee Payer field - radio button selector
                    Row {
                        id: payerRow
                        anchors.top: nameRow.bottom
                        anchors.topMargin: 40
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: formContent.spacingRow
                        height: 36  // 统一高度为36
                        
                        // Label with required marker and help button
                        Item {
                            width: formContent.labelWidth
                            height: 36

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: -19
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: "*"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeLabel
                                    color: "#fb2c36"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                SelectableText {
                                    id: payerLabelText
                                    text: qsTr("Cost Bearer:")
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeLabel
                                    color: "#314158"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                // Help button
                                Rectangle {
                                    id: helpButton
                                    width: 16
                                    height: 16
                                    color: "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 2
                                    visible: true
                                    
                                    Image {
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        source: Qt.resolvedUrl("icons/icon-help.svg")
                                        sourceSize: Qt.size(16, 16)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                    }
                                    
                                    MouseArea {
                                        id: helpButtonMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    
                                    // Tooltip
                                    Rectangle {
                                        id: helpTooltip
                                        visible: helpButtonMouseArea.containsMouse
                                        x: parent.width / 2 - width / 2
                                        y: -height - 4  // 向上移动4像素
                                        width: 240
                                        height: tooltipText.implicitHeight + 16
                                        color: "#1d4171"
                                        radius: 8
                                        z: 1000
                                        
                                        Text {
                                            id: tooltipText
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: qsTr("Instances incur fees (1 CNY/GB/Month), borne by the creator or the instance user.")
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            lineHeight: 15
                                            lineHeightMode: Text.FixedHeight
                                            font.letterSpacing: -0.3125
                                            color: "#FFFFFF"
                                            wrapMode: Text.WordWrap
                                        }
                                        
                                        // Tooltip arrow (pointing down to help button)
                                        Canvas {
                                            id: tooltipArrow
                                            width: 10
                                            height: 6
                                            x: parent.width / 2 - width / 2
                                            y: parent.height  // 箭头在tooltip底部
                                            
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.fillStyle = "#1d4171"
                                                ctx.beginPath()
                                                ctx.moveTo(0, 0)  // 左上角
                                                ctx.lineTo(10, 0)  // 右上角
                                                ctx.lineTo(5, 6)  // 底部顶点
                                                ctx.closePath()
                                                ctx.fill()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Radio button group
                        Row {
                            width: formContent.fieldWidth
                            height: 36
                            spacing: 24
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 2
                            
                            // 创建者 radio button
                            Row {
                                spacing: 8
                                height: parent.height
                                
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    property bool hovered: false
                                    border.color: root.payer === "创建者"
                                        ? Theme.Colors.primary
                                        : (hovered ? Qt.darker(Theme.Colors.primary, 1.1) : "#cad5e2")
                                    border.width: 1
                                    color: "transparent"
                                    
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.centerIn: parent
                                        color: Theme.Colors.primary
                                        visible: root.payer === "创建者"
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: parent.hovered = false
                                        onClicked: {
                                            root.payer = "创建者"
                                        }
                                    }
                                }
                                
                                Text {
                                    text: qsTr("Creator")
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeBody
                                    font.weight: Font.Normal
                                    font.letterSpacing: -0.3125
                                    color: "#314158"
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.payer = "创建者"
                                        }
                                    }
                                }
                            }
                            
                            // 使用者 radio button
                            Row {
                                spacing: 8
                                height: parent.height
                                
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    property bool hovered: false
                                    border.color: root.payer === "使用者"
                                        ? Theme.Colors.primary
                                        : (hovered ? Qt.darker(Theme.Colors.primary, 1.1) : "#cad5e2")
                                    border.width: 1
                                    color: "transparent"
                                    
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.centerIn: parent
                                        color: Theme.Colors.primary
                                        visible: root.payer === "使用者"
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: parent.hovered = false
                                        onClicked: {
                                            root.payer = "使用者"
                                        }
                                    }
                                }
                                
                                Text {
                                    text: qsTr("User")
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeBody
                                    font.weight: Font.Normal
                                    font.letterSpacing: -0.3125
                                    color: "#314158"
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.payer = "使用者"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Height is dynamic based on whether users exist
                    Column {
                        id: visibleUsersColumn
                        anchors.top: payerRow.bottom
                        anchors.topMargin: 40
                        spacing: 8
                        width: parent.width
                        
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: formContent.spacingRow
                            
                            // Label
                            Item {
                                width: formContent.labelWidth
                                height: 36
                                
                                SelectableText {
                                    id: usersLabel
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Visible Users:")
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeLabel
                                    color: "#314158"
                                }
                            }
                            Column {
                                width: formContent.fieldWidth
                                spacing: 8
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 36
                                    radius: 6
                                    antialiasing: true
                                    smooth: true
                                    clip: true
                                    color: addUserMouseArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                                    border.color: "#cad5e2"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    
                                    SelectableText {
                                        anchors.centerIn: parent
                                        text: qsTr("Add Visible User")
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSizeBody
                                        font.weight: Font.Medium
                                        color: "#5a7c9b"  // 与输入文字一致
                                    }
                                    
                                    MouseArea {
                                        id: addUserMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            addUserDialog.domainCreator = (root.currentUser)
                                                ? (root.currentUser.userName || "")
                                                : ""
                                            addUserDialog.open()
                                        }
                                    }
                                }
                                
                                // User table below button - only show when users exist
                                Rectangle {
                                    width: parent.width
                                    height: root.visibleUsers.length > 0 ? (40 + root.visibleUsers.length * 37) : 0  // Header (40px) + rows (37px each)
                                    radius: 6
                                    antialiasing: true
                                    smooth: true
                                    clip: true
                                    color: Theme.Colors.backgroundWhite
                                    border.color: "#cad5e2"
                                    border.width: 1
                                    visible: root.visibleUsers.length > 0
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: parent.radius - 1
                                        color: "transparent"
                                        clip: true
                                        
                                        Column {
                                            anchors.fill: parent
                                        Rectangle {
                                            width: parent.width
                                            height: 40
                                            color: Theme.Colors.backgroundWhite
                                            radius: parent.parent.radius - 1
                                            antialiasing: true
                                            clip: true
                                            
                                            // Bottom border
                                            Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 1
                                                    color: Qt.rgba(0, 0, 0, 0.1)
                                                }
                                            
                                            Row {
                                                anchors.fill: parent
                                                
                                                // Account column - Expanded to fill space
                                                Item {
                                                    width: (parent.width - 96) / 2
                                                    height: parent.height
                                                    
                                                    SelectableText {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: qsTr("Account")
                                                        font.family: root.fontFamily
                                                        font.pixelSize: root.fontSizeBody
                                                        font.weight: Font.Medium
                                                        color: Theme.Colors.textLabel
                                                    }
                                                }

                                                // Name column
                                                Item {
                                                    width: (parent.width - 96) / 2
                                                    height: parent.height

                                                    SelectableText {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 48
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: qsTr("Name")
                                                        font.family: root.fontFamily
                                                        font.pixelSize: root.fontSizeBody
                                                        font.weight: Font.Medium
                                                        color: Theme.Colors.textLabel
                                                    }
                                                }
                                                Item {
                                                    width: 96
                                                    height: parent.height
                                                    
                                                    SelectableText {
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: qsTr("Actions")
                                                        font.family: root.fontFamily
                                                        font.pixelSize: root.fontSizeBody
                                                        font.weight: Font.Medium
                                                        color: Theme.Colors.textLabel
                                                    }
                                                }
                                            }
                                        }
                                        
                                            // Table body - list of users
                                            Repeater {
                                                model: root.visibleUsers
                                            
                                            Rectangle {
                                                width: parent.width
                                                height: 37
                                                color: "transparent"
                                                
                                                // Bottom border (except for last row)
                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: index < root.visibleUsers.length - 1 ? 1 : 0
                                                    color: Qt.rgba(0, 0, 0, 0.1)
                                                }
                                                
                                                Row {
                                                    anchors.fill: parent
                                                    
                                                    // Account cell - Expanded to fill space
                                                    Item {
                                                        width: (parent.width - 96) / 2
                                                        height: parent.height
                                                        
                                                        CenteredTooltipText {
                                                            anchors.fill: parent
                                                            value: modelData.authUserName || modelData.user_name || modelData.account || ""
                                                            textPixelSize: root.fontSizeBody
                                                            textColor: Theme.Colors.textLabel
                                                            leftMargin: 8
                                                            rightMargin: 28
                                                        }
                                                    }

                                                    // Name cell
                                                    Item {
                                                        width: (parent.width - 96) / 2
                                                        height: parent.height

                                                        CenteredTooltipText {
                                                            anchors.fill: parent
                                                            value: modelData.displayName || modelData.account || ""
                                                            textPixelSize: root.fontSizeBody
                                                            textColor: Theme.Colors.textLabel
                                                            leftMargin: 48
                                                            rightMargin: 28
                                                        }
                                                    }
                                                    Item {
                                                        width: 96
                                                        height: parent.height
                                                        
                                                        Rectangle {
                                                            anchors.right: parent.right
                                                            anchors.rightMargin: 5
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: removeText.implicitWidth + 8
                                                            height: removeText.implicitHeight + 4
                                                            radius: 4
                                                            color: removeMouseArea.containsMouse ? Qt.rgba(251/255, 44/255, 54/255, 0.1) : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 180 } }
                                                            
                                                            SelectableText {
                                                                id: removeText
                                                                anchors.centerIn: parent
                                                                text: qsTr("Remove")
                                                                font.family: root.fontFamily
                                                                font.pixelSize: root.fontSizeBody
                                                                color: removeMouseArea.containsMouse ? Qt.darker(Theme.Colors.requiredMarker, 1.2) : Theme.Colors.requiredMarker
                                                                Behavior on color { ColorAnimation { duration: 180 } }
                                                            }
                                                            
                                                            MouseArea {
                                                                id: removeMouseArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    // Remove user from list
                                                                    var users = root.visibleUsers
                                                                    users.splice(index, 1)
                                                                    root.visibleUsers = users
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
                            }
                        }
                    }
                    
                    // Description field - dynamically positioned below user list
                    Row {
                        id: descriptionRow
                        anchors.top: visibleUsersColumn.bottom
                        anchors.topMargin: 40  // 与其他字段间距保持一致
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: formContent.spacingRow
                        height: Math.max(140, Math.min(280, scrollView.height - y - 50))  // 动态计算高度，最小140，最大280，50为底部留白
                        
                        // Label
                        Item {
                            width: formContent.labelWidth
                            height: 34
                            
                            SelectableText {
                                id: descLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Description:")
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSizeLabel
                                color: "#314158"
                            }
                        }
                        
                        // Text area
                        Item {
                            width: parent.width - formContent.labelWidth - formContent.spacingRow
                            height: parent.height  // 与 Row 高度一致，自动调整
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                antialiasing: true
                                smooth: true
                                clip: true
                                color: {
                                    if (descriptionArea.activeFocus) return Theme.Colors.backgroundWhite
                                    if (descriptionArea.text.length > 0) return Theme.Colors.backgroundWhite
                                    return descriptionHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                                }
                                border.color: "#cad5e2"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 24
                                    clip: true
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                                    
                                    TextArea {
                                        id: descriptionArea
                                        width: parent.width
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSizeBody
                                        color: "#314158"  // 输入文字颜色
                                        background: null
                                        wrapMode: TextArea.Wrap
                                        selectByMouse: true
                                        selectionColor: "#d4e4f1"
                                        selectedTextColor: "#0f172b"
                                        
                                        // Remove default padding to align with placeholder
                                        leftPadding: 0
                                        rightPadding: 0
                                        topPadding: 0
                                        bottomPadding: 0
                                        
                                        property int maxLength: 500
                                        
                                        onTextChanged: {
                                            if (text.length <= maxLength) {
                                                root.description = text
                                            } else {
                                                var cursorPos = cursorPosition
                                                text = root.description
                                                cursorPosition = Math.min(cursorPos - 1, text.length)
                                            }
                                        }
                                        
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 0  // Align with TextArea text position
                                            anchors.top: parent.top
                                            anchors.topMargin: 0  // Align with TextArea text position
                                            verticalAlignment: Text.AlignTop
                                            text: qsTr("Please enter a description")
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSizeBody
                                            color: "#5a7c9b"
                                            visible: !descriptionArea.text && !descriptionArea.activeFocus
                                        }
                                    }
                                }
                                
                                // Right-click context menu for description input
                                InputContextMenu {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12  // Match ScrollView margins
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 24
                                    target: descriptionArea
                                    z: 1  // Above ScrollView content
                                }
                                
                                // Hover detection area
                                MouseArea {
                                    id: descriptionHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                                SelectableText {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    text: descriptionArea.text.length + "/500"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeCaption
                                    color: Theme.Colors.textCounter
                                }
                            }
                        }
                    }
                }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 79.993
            color: Theme.Colors.backgroundWhite
            border.color: Theme.Colors.borderSlate
            border.width: 0.653
            
            Rectangle {
                id: submitButton
                anchors.centerIn: parent
                height: 44
                implicitWidth: submitButtonText.implicitWidth + 40
                radius: 6
                antialiasing: true
                smooth: true
                clip: true
                property real breatheOpacity: 1.0
                  color: (root.isValid && !root.isSubmitting)
                      ? (submitButtonMouseArea.containsMouse
                        ? (submitButtonMouseArea.pressed
                           ? Qt.darker(Theme.Colors.primary, 1.2)
                           : Qt.lighter(Theme.Colors.primary, 1.2))
                        : Theme.Colors.primary)
                      : Theme.Colors.buttonDisabled
                Behavior on color { 
                    ColorAnimation { 
                        duration: 120
                    } 
                }
                opacity: (root.isValid && !root.isSubmitting) ? breatheOpacity : 1.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutCubic
                    }
                }
                
                SequentialAnimation on breatheOpacity {
                    running: root.isValid && !root.isSubmitting && !submitButtonMouseArea.containsMouse
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.85; duration: 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.85; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                }
                
                SelectableText {
                    id: submitButtonText
                    anchors.centerIn: parent
                    text: root.isSubmitting ? qsTr("Creating...") : qsTr("Create Security Domain")
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeBody
                    font.weight: Font.Medium
                    color: (root.isValid && !root.isSubmitting) ? Theme.Colors.primaryText : Theme.Colors.textSecondary
                }
                
                MouseArea {
                    id: submitButtonMouseArea
                    anchors.fill: parent
                    enabled: root.isValid && !root.isSubmitting
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onClicked: {
                        if (root.isValid && !root.isSubmitting && root.description.length <= 500) {
                            root.isSubmitting = true
                            root.submit()
                        }
                    }
                }
            }
        }
    }
    
    // Background overlay for dialog
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: addUserDialog.opened
        z: 100
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                addUserDialog.close()
            }
        }
    }
    
    // Add Visible User Dialog
    AddVisibleUserDialog {
        id: addUserDialog
        parent: root
        dim: false  // We handle dimming ourselves
        
        onOpened: {
            // Reset account input when dialog opens
            account = ""
        }
        
        onAddClicked: function(account) {
            var trimmed = account ? account.trim() : ""
            if (!trimmed)
                return

            // 从 addUserDialog 获取用户详细信息
            var userInfo = addUserDialog.currentUserInfo || {}
            var userId = (userInfo.user_id || userInfo.authUserId || "").trim()
            var userName = (userInfo.user_name || userInfo.authUserName || "").trim()
            var newAccount = (userInfo.account || "").trim()
            var displayName = (userInfo.displayName || newAccount).trim()
            if (!newAccount || !userId || !userName) {
                return
            }

            // 仅按 username/account 去重
            for (var i = 0; i < root.visibleUsers.length; i++) {
                var user = root.visibleUsers[i]
                if (user && user.account === newAccount) {
                    return
                }
            }

            var newUser = {
                account: newAccount,
                displayName: displayName,
                authUserId: userId,
                authUserName: userName
            }
            
            // Add user to visibleUsers list
            var users = root.visibleUsers
            users.push(newUser)
            root.visibleUsers = users
        }
        
        onCancelClicked: {
            // Handled by Popup's closePolicy
        }
    }

}

