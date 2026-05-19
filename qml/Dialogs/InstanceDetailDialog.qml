import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root

    // Use separate properties to trigger re-evaluation
    property real parentWidth: parent ? parent.width : 800
    property real parentHeight: parent ? parent.height : 600

    width: {
        // Dynamic width based on parent size, with min/max constraints
        var preferredWidth = 400
        var maxWidth = parentWidth * 0.8
        var minWidth = 340
        return Math.max(minWidth, Math.min(preferredWidth, maxWidth))
    }
    height: {
        // Dynamic height calculation based on actual content
        var titleHeight = 18
        var topMargin = 20
        var bottomMargin = 20
        var afterTitleSpace = 10
        var costFieldHeight = 0
        var afterCostSpace = 0
        var fieldsHeight = fieldsContainer ? fieldsContainer.implicitHeight : 150
        var beforeWhitelistSpace = 0
        var whitelistLabelHeight = 0
        var afterWhitelistLabelSpace = 0
        var whitelistTableHeight = 0
        var buttonsSpace = shouldShowActionButtons ? 8 : 0
        var buttonsHeight = shouldShowActionButtons ? 36 : 0

        var totalHeight = topMargin + titleHeight + afterTitleSpace + costFieldHeight +
                         afterCostSpace + fieldsHeight + beforeWhitelistSpace +
                         whitelistLabelHeight + afterWhitelistLabelSpace +
                         whitelistTableHeight + buttonsSpace + buttonsHeight + bottomMargin

        var maxHeight = parentHeight * 0.9
        return Math.min(totalHeight, maxHeight)
    }
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: Math.max(0, (parentWidth - width) / 2)
    y: Math.max(0, (parentHeight - height) / 2)

    property string instanceId: ""
    property string status: ""
    property string creator: ""
    property string instanceSize: ""
    property string appliedTime: ""
    property string instanceRemainingDays: ""
    property string instanceCost: ""  // Instance cost
    property var whitelistApps: []  // Whitelist applications array
    property bool showActionButtons: false  // Show approve/reject buttons for pending instances
    property bool shouldShowActionButtons: showActionButtons && (status === "待审核")
    property bool isApproverView: false  // Whether viewing as approver (affects title display)
    property bool allowApproveReject: true  // If true, allow approve/reject actions (controlled by domain status)
    property int currentPage: 1  // Current page for whitelist pagination

    readonly property var statusStyle: Theme.Colors.getStatusColor(status)

    function getTotalPages() {
        return whitelistApps && whitelistApps.length > 0 ? Math.ceil(whitelistApps.length / 3) : 0
    }

    function normalizeCurrentPage() {
        var total = getTotalPages()
        if (total <= 0) {
            if (currentPage !== 1) {
                currentPage = 1
            }
            return
        }

        if (currentPage < 1) {
            currentPage = 1
            return
        }

        if (currentPage > total) {
            currentPage = total
        }
    }

    onWhitelistAppsChanged: normalizeCurrentPage()

    function getPagedApps() {
        if (!whitelistApps || whitelistApps.length === 0) return []
        var startIdx = (currentPage - 1) * 3
        var endIdx = Math.min(startIdx + 3, whitelistApps.length)
        var result = []
        for (var i = startIdx; i < endIdx; i++) {
            result.push(whitelistApps[i])
        }
        return result
    }

    // Get page numbers to display (with ellipsis support)
    function getVisiblePages() {
        var total = getTotalPages()
        if (total <= 7) {
            // Show all pages if 7 or less
            var pages = []
            for (var i = 1; i <= total; i++) {
                pages.push(i)
            }
            return pages
        }

        // Show first, last, current and adjacent pages with ellipsis
        var pages = []
        if (currentPage <= 3) {
            // Near start: 1 2 3 4 ... last
            for (var i = 1; i <= Math.min(4, total); i++) {
                pages.push(i)
            }
            if (total > 5) {
                pages.push(-1) // -1 means ellipsis
                pages.push(total)
            } else if (total === 5) {
                pages.push(5)
            }
        } else if (currentPage >= total - 2) {
            // Near end: 1 ... last-3 last-2 last-1 last
            pages.push(1)
            if (total > 5) {
                pages.push(-1)
            }
            for (var i = Math.max(total - 3, 2); i <= total; i++) {
                pages.push(i)
            }
        } else {
            // Middle: 1 ... current-1 current current+1 ... last
            pages.push(1)
            pages.push(-1)
            pages.push(currentPage - 1)
            pages.push(currentPage)
            pages.push(currentPage + 1)
            pages.push(-2) // -2 means second ellipsis
            pages.push(total)
        }
        return pages
    }

    signal approveClicked()
    signal rejectClicked()
    signal cancelClicked()

    // Monitor parent size changes
    Connections {
        target: root.parent
        function onWidthChanged() {
            root.parentWidth = root.parent.width
        }
        function onHeightChanged() {
            root.parentHeight = root.parent.height
        }
    }

    background: null
    padding: 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            spacing: 0

            Item {
                width: parent.width
                height: 18

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: isApproverView ? qsTr("Security Domain Instance Application Details") : qsTr("Security Domain Instance Details")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#0f172b"
                }

                Rectangle {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.top: parent.top
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

            Item {
                width: parent.width
                height: 12
            }

            // Instance cost field - only show for approval dialog
            Column {
                width: 223
                spacing: 2
                visible: false

                SelectableText {
                    text: qsTr("Instance Cost")
                    font.pixelSize: 14
                    color: "#62748e"
                }

                Row {
                    spacing: 0

                    SelectableText {
                        text: root.instanceCost || "0"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: "#ff5736"
                    }

                    SelectableText {
                        text: qsTr(" CNY")
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#ff5736"
                        anchors.baseline: parent.children[0].baseline
                    }
                }
            }

            Item {
                width: parent.width
                height: 0
                visible: false
            }

            // Fields container with proper flow layout
            Column {
                id: fieldsContainer
                width: parent.width
                spacing: 12
                readonly property int twoColumnGap: 16
                readonly property real leftColumnRatio: 0.58
                readonly property int leftColumnWidth: Math.floor((width - twoColumnGap) * leftColumnRatio)
                readonly property int rightColumnWidth: Math.max(0, width - twoColumnGap - leftColumnWidth)

                // Row 1: Instance ID and Status
                Row {
                    width: parent.width
                    spacing: fieldsContainer.twoColumnGap

                    Column {
                        width: fieldsContainer.leftColumnWidth
                        spacing: 4

                        SelectableText {
                            text: qsTr("Instance No.")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        SelectableText {
                            text: root.instanceId
                            font.pixelSize: 16
                            color: "#000000"
                        }
                    }

                    Column {
                        width: fieldsContainer.rightColumnWidth
                        spacing: 4

                        SelectableText {
                            text: qsTr("Status")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        Rectangle {
                            width: 54
                            height: 22
                            radius: 8
                            color: statusStyle.bg
                            border.color: statusStyle.border
                            border.width: 1

                            SelectableText {
                                anchors.centerIn: parent
                                text: root.status
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: statusStyle.text
                            }
                        }
                    }
                }

                // Row 2: Creator and Instance Size
                Row {
                    width: parent.width
                    spacing: fieldsContainer.twoColumnGap

                    Column {
                        width: fieldsContainer.leftColumnWidth
                        spacing: 4

                        SelectableText {
                            text: qsTr("Creator")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        SelectableText {
                            text: root.creator
                            font.pixelSize: 16
                            color: "#000000"
                        }
                    }

                    Column {
                        width: fieldsContainer.rightColumnWidth
                        spacing: 4

                        SelectableText {
                            text: qsTr("Security Domain Instance Size")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        SelectableText {
                            text: (root.instanceSize || "").replace(/MB/g, "Mb")
                            font.pixelSize: 16
                            color: "#000000"
                        }
                    }
                }

                // Row 3: Applied Time
                Row {
                    width: parent.width
                    spacing: 0

                    Column {
                        width: parent.width
                        spacing: 4

                        SelectableText {
                            text: qsTr("Application Time")
                            font.pixelSize: 14
                            color: "#62748e"
                        }

                        SelectableText {
                            text: Theme.Utils.formatDateTime(root.appliedTime)
                            font.pixelSize: 16
                            color: "#000000"
                        }
                    }
                }
            }

            // Application whitelist section hidden to keep all statuses' content consistent
            Column {
                width: parent.width
                spacing: 4
                visible: false

                Item {
                    width: parent.width
                    height: 12
                }

                SelectableText {
                    text: qsTr("App Whitelist")
                    font.pixelSize: 14
                    color: "#62748e"
                }

                Item {
                    width: parent.width
                    height: 4
                }

                // Whitelist table - dynamic height based on content
                Rectangle {
                    width: parent.width
                    height: root.whitelistApps && root.whitelistApps.length > 0 ? 193 : 85
                    radius: 8
                    color: "white"
                    border.color: "#cbd5e1"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        spacing: 0

                        // Empty state - show icon when whitelist is empty
                        Item {
                            width: parent.width
                            height: parent.height
                            visible: !root.whitelistApps || root.whitelistApps.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 36
                                    height: 36
                                    source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                                    sourceSize: Qt.size(36, 36)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No data")
                                    font.pixelSize: 13
                                    color: "#90A1B9"
                                }
                            }
                        }

                        // Table header - only show when whitelist is not empty
                        Item {
                            width: parent.width
                            height: 40
                            visible: root.whitelistApps && root.whitelistApps.length > 0
                            clip: true

                            Rectangle {
                                width: parent.width
                                height: parent.height + 8  // Extend below to hide bottom border
                                radius: 8
                                color: "#f5f8fb"
                                border.color: "#cbd5e1"
                                border.width: 1
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 0
                                color: "transparent"
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8

                                Text {
                                    width: (parent.width - 8) / 2
                                    height: parent.height
                                    text: qsTr("Process Path")
                                    font.pixelSize: 14
                                    color: "#314158"
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: (parent.width - 8) / 2
                                    height: parent.height
                                    text: qsTr("Hash")
                                    font.pixelSize: 14
                                    color: "#314158"
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Table body - only show when whitelist is not empty
                        Column {
                            width: parent.width
                            height: Math.max(111, 37 * Math.min(3, root.getPagedApps().length))  // Minimum height for 3 rows
                            spacing: 0
                            visible: root.whitelistApps && root.whitelistApps.length > 0

                            Repeater {
                                id: tableRepeater
                                model: root.getPagedApps()

                                Rectangle {
                                    width: parent.width
                                    height: 37
                                    color: "transparent"

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: "#e5e7eb"
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 0

                                        // Process path cell with tooltip
                                        Item {
                                            width: (parent.width - 8) / 2
                                            height: parent.height

                                            Text {
                                                id: pathText
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                text: modelData.diskPartition || ""
                                                font.pixelSize: 14
                                                color: "#314158"
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignLeft
                                                elide: Text.ElideMiddle
                                            }

                                            Rectangle {
                                                id: pathTooltipItem
                                                visible: false
                                                color: "#f5f8fb"
                                                opacity: 1
                                                radius: 6
                                                width: pathTooltipItemText.width + 20
                                                height: pathTooltipItemText.height + 16
                                                z: 1000
                                                y: -(height + 4)
                                                x: Math.max(0, Math.min(parent.width - width, 0))
                                                border.color: "#cbd5e1"
                                                border.width: 1

                                                Text {
                                                    id: pathTooltipItemText
                                                    anchors.centerIn: parent
                                                    text: modelData.diskPartition || ""
                                                    font.pixelSize: 12
                                                    color: "#314158"
                                                    wrapMode: Text.NoWrap
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    pathTooltipItem.visible = true
                                                }
                                                onExited: {
                                                    pathTooltipItem.visible = false
                                                }
                                            }
                                        }

                                        // Hash cell with tooltip
                                        Item {
                                            width: (parent.width - 8) / 2
                                            height: parent.height

                                            Text {
                                                id: hashText
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                text: modelData.hash || ""
                                                font.pixelSize: 14
                                                color: "#314158"
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignLeft
                                                elide: Text.ElideMiddle
                                            }

                                            Rectangle {
                                                id: hashTooltipItem
                                                visible: false
                                                color: "#f5f8fb"
                                                opacity: 1
                                                radius: 6
                                                width: hashTooltipItemText.width + 20
                                                height: hashTooltipItemText.height + 16
                                                z: 1000
                                                y: -(height + 4)
                                                x: Math.max(0, Math.min(parent.width - width, 0))
                                                border.color: "#cbd5e1"
                                                border.width: 1

                                                Text {
                                                    id: hashTooltipItemText
                                                    anchors.centerIn: parent
                                                    text: modelData.hash || ""
                                                    font.pixelSize: 12
                                                    color: "#314158"
                                                    wrapMode: Text.NoWrap
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    hashTooltipItem.visible = true
                                                }
                                                onExited: {
                                                    hashTooltipItem.visible = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 5
                            visible: root.whitelistApps && root.whitelistApps.length > 0
                        }

                        // Pagination - only show when whitelist is not empty
                        Item {
                            width: parent.width
                            height: 32
                            visible: root.whitelistApps && root.whitelistApps.length > 0

                            Row {
                                id: paginationRow
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6
                                property int totalPages: root.getTotalPages()
                                property var visiblePages: root.getVisiblePages()

                                // Previous button
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 3
                                    visible: parent.totalPages > 0
                                    color: "transparent"
                                    opacity: root.currentPage > 1 ? 1 : 0.6

                                    Text {
                                        anchors.centerIn: parent
                                        text: "<"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.currentPage > 1 ? "#212b36" : "#90a1b9"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.currentPage > 1
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentPage > 1) {
                                                root.currentPage--
                                            }
                                        }
                                    }
                                }

                                // Dynamic page buttons with ellipsis support
                                Repeater {
                                    model: parent.visiblePages

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 3
                                        property int pageNum: modelData
                                        property bool isEllipsis: pageNum < 0
                                        property bool isCurrentPage: pageNum === root.currentPage
                                        color: pageMouseArea.pressed ? "#1b5fa8" : (pageMouseArea.containsMouse && !isEllipsis ? "#e3f2fd" : (isCurrentPage ? "transparent" : "white"))
                                        border.color: isCurrentPage ? "#2b7fff" : "#d5dce5"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isEllipsis ? "..." : pageNum.toString()
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: pageMouseArea.pressed ? "#ffffff" : (isCurrentPage ? "#2b7fff" : "#212b36")
                                        }

                                        MouseArea {
                                            id: pageMouseArea
                                            anchors.fill: parent
                                            enabled: !isEllipsis
                                            hoverEnabled: true
                                            cursorShape: isCurrentPage ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                if (!isEllipsis && !isCurrentPage) {
                                                    root.currentPage = pageNum
                                                }
                                            }
                                        }
                                    }
                                }

                                // Next button
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 3
                                    visible: parent.totalPages > 0
                                    color: "transparent"
                                    opacity: root.currentPage < paginationRow.totalPages ? 1 : 0.6

                                    Text {
                                        anchors.centerIn: parent
                                        text: ">"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: root.currentPage < paginationRow.totalPages ? "#212b36" : "#90a1b9"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.currentPage < paginationRow.totalPages
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentPage < paginationRow.totalPages) {
                                                root.currentPage++
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Spacing between content and buttons (only when buttons are shown)
            Item {
                width: parent.width
                height: shouldShowActionButtons ? 12 : 0
                visible: shouldShowActionButtons
            }

            // Footer buttons - only visible for pending status with actions
            Item {
                width: parent.width
                height: 36
                visible: shouldShowActionButtons

                // Reject button
                Rectangle {
                    anchors.right: approveButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 36
                    radius: 8
                    property bool hovered: false
                    property bool pressed: false
                    opacity: root.allowApproveReject ? 1.0 : 0.5
                    color: pressed ? "#ffe9e9" : (hovered ? "#fff5f5" : "#ffffff")
                    border.color: pressed ? "#ff6b6b" : (hovered ? "#ff9090" : "#ffa2a2")
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    SelectableText {
                        anchors.centerIn: parent
                        text: qsTr("Reject")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: parent.pressed ? "#9f0006" : (parent.hovered ? "#c50009" : "#e7000b")
                    }

                    MouseArea {
                        id: rejectArea
                        anchors.fill: parent
                        enabled: root.allowApproveReject
                        hoverEnabled: true
                        cursorShape: root.allowApproveReject ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            root.rejectClicked()
                            root.close()
                        }
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onPressed: parent.pressed = true
                        onReleased: parent.pressed = false
                        onCanceled: parent.pressed = false
                    }
                }

                // Approve button
                Rectangle {
                    id: approveButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 36
                    radius: 8
                    opacity: root.allowApproveReject ? 1.0 : 0.5
                    color: {
                        if (approveArea.pressed) return "#0a3d6b"
                        if (approveArea.containsMouse) return "#0d5a95"
                        return "#0f4c81"
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    visible: shouldShowActionButtons

                    SelectableText {
                        anchors.centerIn: parent
                        text: qsTr("Approve")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }

                    MouseArea {
                        id: approveArea
                        anchors.fill: parent
                        enabled: root.allowApproveReject
                        hoverEnabled: true
                        cursorShape: root.allowApproveReject ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            root.approveClicked()
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
