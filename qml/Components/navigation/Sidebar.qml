import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme

Rectangle {
    id: sidebar

    // Width needed to show the company name on a single line, plus the 16px
    // left/right margins of its container. Floored at 232 so the CN layout is
    // unchanged; wider locales (e.g. EN) expand the sidebar instead of wrapping.
    readonly property real preferredWidth: Math.max(232, companyNameText.implicitWidth + 2 * 16)

    property var currentUser: null
    property string currentUserAvatar: ""
    property string selectedDomainCode: ""
    property bool hasUpdateNotification: false
    property int unreadMessageCount: 0
    property var domainList: []
    property bool domainRefreshing: false

    signal createDomainRequested
    signal domainSelected(string domainCode, string pubKey, string name)
    signal refreshDomainsRequested
    signal pageRequested(string page)
    signal logoutRequested
    signal checkUpdateClicked
    signal minimizeWindowRequested

    color: Theme.Colors.backgroundSidebar
    border.color: Theme.Colors.borderSlate
    border.width: 1

    Item {
        id: sidebarContent
        anchors.fill: parent

        Item {
            height: 24
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16

            Text {
                id: companyNameText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Beijing YeeZTech Co., Ltd")
                font.pixelSize: Theme.Typography.h3
                font.weight: Font.Bold
                color: Theme.Colors.primary
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: companyNameMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(AppConfig.vendorUrl())
            }
        }

        Item {
            width: parent.width
            height: 36
            anchors.top: parent.top
            anchors.topMargin: 68

            PrimaryButton {
                id: createButton
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Create Security Domain")
                onClicked: sidebar.createDomainRequested()
            }
        }

        Item {
            id: navigationArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 116
            anchors.bottom: userProfileSection.top
            anchors.bottomMargin: 8
            clip: true

            ScrollView {
                id: navigationScrollView
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6
                    anchors.right: parent ? parent.right : undefined
                    anchors.top: parent ? parent.top : undefined
                    anchors.bottom: parent ? parent.bottom : undefined
                }

                Column {
                    id: navContent
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    spacing: 8

                    Item {
                        id: securityDomainSection
                        width: parent.width

                        property bool securityDomainExpanded: true

                        property int headerHeight: 36
                        property int listTopMargin: 44
                        property int itemHeight: 32
                        height: {
                            if (!securityDomainExpanded) {
                                return headerHeight;
                            }
                            if (securityDomainRepeater.model && securityDomainRepeater.model.length > 0) {
                                var listBottom = listTopMargin + securityDomainRepeater.model.length * itemHeight;
                                return Math.max(headerHeight, listBottom);
                            }
                            return headerHeight;
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            id: securityDomainHeader
                            width: parent.width
                            height: 36
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            radius: 4
                            property bool hovered: false
                            color: hovered ? "#eaf2fb" : "transparent"

                            Row {
                                spacing: 8
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                Image {
                                    id: dropdownIcon1
                                    width: 14
                                    height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/icons/icon-dropdown.svg"
                                    fillMode: Image.PreserveAspectFit
                                    rotation: securityDomainSection.securityDomainExpanded ? 0 : -90

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityDomainHeader.hovered = true
                                        onExited: securityDomainHeader.hovered = false
                                        onClicked: {
                                            securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded;
                                        }
                                    }

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Image {
                                    id: securityDomainIcon
                                    width: 16
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/icons/icon-security-domain.svg"
                                    fillMode: Image.PreserveAspectFit

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityDomainHeader.hovered = true
                                        onExited: securityDomainHeader.hovered = false
                                        onClicked: {
                                            securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded;
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Security Domain")
                                    font.pixelSize: Theme.Typography.body
                                    font.weight: Font.Bold
                                    color: Theme.Colors.primary
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityDomainHeader.hovered = true
                                        onExited: securityDomainHeader.hovered = false
                                        onClicked: {
                                            securityDomainSection.securityDomainExpanded = !securityDomainSection.securityDomainExpanded;
                                        }
                                    }
                                }

                                Item {
                                    id: domainRefreshBtn
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter

                                    // The domain list loads synchronously, so the spin
                                    // would otherwise end before a single frame renders.
                                    // Guarantee at least one full turn per click, and keep
                                    // spinning while a load is still in flight.
                                    property bool minSpinElapsed: true

                                    Image {
                                        id: domainRefreshIcon
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        source: "qrc:/icons/icon-update-refresh.svg"
                                        fillMode: Image.PreserveAspectFit
                                        opacity: domainRefreshArea.pressed ? 0.5 : (domainRefreshArea.containsMouse ? 1.0 : 0.7)
                                        scale: domainRefreshArea.pressed ? 0.85 : 1.0
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 100
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 80
                                            }
                                        }
                                    }

                                    RotationAnimator {
                                        id: domainRefreshAnim
                                        target: domainRefreshIcon
                                        from: 0
                                        to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                        running: sidebar.domainRefreshing || !domainRefreshBtn.minSpinElapsed
                                        // Restore the icon to its resting angle when
                                        // the refresh finishes (PRD: 动画停止并恢复正常状态)
                                        onStopped: domainRefreshIcon.rotation = 0
                                    }

                                    // Keeps the spin visible for at least one full turn
                                    // even when the list loads instantly.
                                    Timer {
                                        id: domainRefreshMinSpin
                                        interval: 800
                                        onTriggered: domainRefreshBtn.minSpinElapsed = true
                                    }

                                    MouseArea {
                                        id: domainRefreshArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityDomainHeader.hovered = false
                                        onExited: securityDomainHeader.hovered = false
                                        onClicked: {
                                            domainRefreshBtn.minSpinElapsed = false;
                                            domainRefreshMinSpin.restart();
                                            sidebar.refreshDomainsRequested();
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: securityDomainListContainer
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.top: parent.top
                            anchors.topMargin: 36

                            height: securityDomainRepeater.model && securityDomainRepeater.model.length > 0 ? (securityDomainRepeater.model.length * 32) : 0
                            visible: securityDomainSection.securityDomainExpanded
                            opacity: securityDomainSection.securityDomainExpanded ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Repeater {
                                id: securityDomainRepeater
                                model: sidebar.domainList

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.topMargin: index * 32
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    height: 32
                                    width: Math.max(0, parent.width - 8)
                                    radius: 4
                                    property bool hovered: false
                                    readonly property bool isSelected: (modelData.domainCode || "") === sidebar.selectedDomainCode && sidebar.selectedDomainCode !== ""
                                    color: isSelected ? "#c2d8ef" : (hovered ? "#d6e8f5" : Qt.rgba(194 / 255, 216 / 255, 239 / 255, 0))
                                    border.color: "transparent"
                                    border.width: 0
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Rectangle {
                                        x: 8
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.Colors.getStatusColor(modelData.status || Theme.Colors.statusRunning).dot
                                    }

                                    Text {
                                        id: domainNameText
                                        x: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        font.pixelSize: Theme.Typography.body
                                        font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                        color: parent.isSelected ? Theme.Colors.primary : (parent.hovered ? "#1e3a5f" : Theme.Colors.textCaption)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        maximumLineCount: 1
                                        elide: Text.ElideMiddle
                                        width: Math.max(0, (pendingBadge.visible ? pendingBadge.x - 6 : parent.width - 8) - x)
                                        readonly property bool isOverflow: implicitWidth > width
                                        property bool showTooltip: domainItemMouseArea.containsMouse && domainNameText.isOverflow && domainItemMouseArea.mouseX >= domainNameText.x && domainItemMouseArea.mouseX <= (domainNameText.x + domainNameText.width)

                                        Popup {
                                            id: domainNameTooltip
                                            parent: Overlay.overlay
                                            modal: false
                                            focus: false
                                            closePolicy: Popup.NoAutoClose
                                            padding: 0
                                            visible: domainNameText.showTooltip
                                            z: 99999

                                            readonly property real maxBubbleWidth: Overlay.overlay ? Math.max(160, Overlay.overlay.width - 16) : 400
                                            readonly property real bubbleWidth: Math.min(Math.max(domainNameTooltipText.implicitWidth + 16, 120), maxBubbleWidth)

                                            x: {
                                                var p = domainNameText.mapToItem(Overlay.overlay, 0, 0);
                                                var desired = p.x + (domainNameText.width - bubbleWidth) / 2;
                                                var minX = 8;
                                                var maxX = Overlay.overlay ? (Overlay.overlay.width - bubbleWidth - 8) : desired;
                                                return Math.max(minX, Math.min(desired, maxX));
                                            }
                                            y: {
                                                var p = domainNameText.mapToItem(Overlay.overlay, 0, 0);
                                                return p.y - bubbleBackground.height - 8;
                                            }

                                            background: Item {
                                                Rectangle {
                                                    id: bubbleBackground
                                                    width: domainNameTooltip.bubbleWidth
                                                    height: Math.max(28, domainNameTooltipText.implicitHeight + 10)
                                                    color: Theme.Colors.tooltipBackground
                                                    radius: 4

                                                    Text {
                                                        id: domainNameTooltipText
                                                        anchors.centerIn: parent
                                                        width: Math.max(0, parent.width - 16)
                                                        text: domainNameText.text
                                                        font.pixelSize: Theme.Typography.caption
                                                        color: "white"
                                                        wrapMode: Text.WrapAnywhere
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }

                                                    Canvas {
                                                        width: 10
                                                        height: 5
                                                        anchors.top: parent.bottom
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        onPaint: {
                                                            var ctx = getContext("2d");
                                                            ctx.reset();
                                                            ctx.fillStyle = Theme.Colors.tooltipBackground;
                                                            ctx.beginPath();
                                                            ctx.moveTo(0, 0);
                                                            ctx.lineTo(5, 5);
                                                            ctx.lineTo(10, 0);
                                                            ctx.closePath();
                                                            ctx.fill();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: pendingBadge
                                        property int auditCount: 0
                                        visible: auditCount > 0
                                        x: 130
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: auditCount > 99 ? 32 : (auditCount > 9 ? 24 : 16)
                                        height: 16
                                        radius: 8
                                        color: Theme.Colors.notificationRed
                                        z: 10
                                        Text {
                                            anchors.centerIn: parent
                                            color: "#fff"
                                            font.pixelSize: 11
                                            font.bold: true
                                            text: pendingBadge.auditCount > 99 ? "99+" : pendingBadge.auditCount.toString()
                                        }
                                    }

                                    MouseArea {
                                        id: domainItemMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: parent.hovered = false
                                        onClicked: {
                                            sidebar.domainSelected(modelData.domainCode || "", modelData.pubKey || "", modelData.name || "");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: securityInstanceSection
                        visible: false
                        width: parent.width

                        property bool securityInstanceExpanded: true

                        property int headerHeight: 36
                        property int listTopMargin: 44
                        property int itemHeight: 32
                        height: {
                            if (!securityInstanceExpanded) {
                                return headerHeight;
                            }
                            if (securityInstanceRepeater.model && securityInstanceRepeater.model.length > 0) {
                                var listBottom = listTopMargin + securityInstanceRepeater.model.length * itemHeight;
                                return Math.max(headerHeight, listBottom);
                            }
                            return headerHeight;
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            id: securityInstanceHeader
                            width: parent.width
                            height: 36
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            radius: 4
                            property bool hovered: false
                            color: hovered ? "#eaf2fb" : "transparent"

                            Row {
                                spacing: 8
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                Image {
                                    id: dropdownIcon2
                                    width: 14
                                    height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/icons/icon-dropdown.svg"
                                    fillMode: Image.PreserveAspectFit
                                    rotation: securityInstanceSection.securityInstanceExpanded ? 0 : -90

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded;
                                        }
                                    }

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Image {
                                    id: securityInstanceIcon
                                    width: 16
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/icons/icon-security-instance.svg"
                                    fillMode: Image.PreserveAspectFit

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityInstanceHeader.hovered = true
                                        onExited: securityInstanceHeader.hovered = false
                                        onClicked: {
                                            securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded;
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Security Domain Instance")
                                    font.pixelSize: Theme.Typography.body
                                    font.weight: Font.Bold
                                    color: Theme.Colors.primary
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityInstanceHeader.hovered = true
                                        onExited: securityInstanceHeader.hovered = false
                                        onClicked: {
                                            securityInstanceSection.securityInstanceExpanded = !securityInstanceSection.securityInstanceExpanded;
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: securityInstanceListContainer
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.top: parent.top
                            anchors.topMargin: 36

                            height: securityInstanceRepeater.model && securityInstanceRepeater.model.length > 0 ? (securityInstanceRepeater.model.length * 32) : 0
                            visible: securityInstanceSection.securityInstanceExpanded
                            opacity: securityInstanceSection.securityInstanceExpanded ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Repeater {
                                id: securityInstanceRepeater
                                model: []

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.topMargin: index * 32
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    height: 32
                                    width: Math.max(0, parent.width - 8)
                                    radius: 4
                                    property bool hovered: false
                                    readonly property bool isSelected: false
                                    color: isSelected ? "#c8d9e8" : (hovered ? "#eaf2fb" : "transparent")

                                    Rectangle {
                                        x: 8
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.color
                                    }

                                    Text {
                                        id: securityInstanceNameText
                                        x: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        font.pixelSize: Theme.Typography.body
                                        font.weight: Font.Normal
                                        color: Theme.Colors.textCaption
                                        maximumLineCount: 1
                                        elide: Text.ElideMiddle
                                        width: Math.max(0, parent.width - x - 8)
                                        readonly property bool isOverflow: implicitWidth > width
                                        property bool showTooltip: securityInstanceItemMouseArea.containsMouse && securityInstanceNameText.isOverflow && securityInstanceItemMouseArea.mouseX >= securityInstanceNameText.x && securityInstanceItemMouseArea.mouseX <= (securityInstanceNameText.x + securityInstanceNameText.width)

                                        Rectangle {
                                            visible: parent.showTooltip
                                            width: Math.min(instanceNameTooltipText.implicitWidth + 16, 400)
                                            height: 28
                                            color: Theme.Colors.tooltipBackground
                                            radius: 4
                                            z: 1000
                                            y: -height - 8
                                            x: -8

                                            Text {
                                                id: instanceNameTooltipText
                                                anchors.centerIn: parent
                                                text: parent.parent.text
                                                font.pixelSize: Theme.Typography.caption
                                                color: "white"
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                            }

                                            Canvas {
                                                width: 10
                                                height: 5
                                                anchors.top: parent.bottom
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.fillStyle = Theme.Colors.tooltipBackground;
                                                    ctx.beginPath();
                                                    ctx.moveTo(0, 0);
                                                    ctx.lineTo(5, 5);
                                                    ctx.lineTo(10, 0);
                                                    ctx.closePath();
                                                    ctx.fill();
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: securityInstanceItemMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: parent.hovered = false
                                        onClicked:
                                        // placeholder — instance detail navigation not yet wired
                                        {}
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 36
                            }
                        }
                    }
                }
            }
        }

        SidebarNav {
            id: userProfileSection
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            currentUser: sidebar.currentUser
            currentUserAvatar: sidebar.currentUserAvatar
            hasUpdateNotification: sidebar.hasUpdateNotification
            unreadMessageCount: sidebar.unreadMessageCount

            onPageRequested: function (page) {
                sidebar.pageRequested(page);
            }
            onLogoutRequested: sidebar.logoutRequested()
            onCheckUpdateClicked: sidebar.checkUpdateClicked()
            onMinimizeWindowRequested: sidebar.minimizeWindowRequested()
        }
    }
}
