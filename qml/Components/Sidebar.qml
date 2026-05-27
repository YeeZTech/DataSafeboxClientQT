import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Rectangle {
    id: sidebar

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
            width: 175.342
            height: 24
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 16

            Text {
                id: companyNameText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 0
                text: AppConfig.vendorCompanyName()
                font.pixelSize: 16
                font.weight: Font.Bold
                color: Theme.Colors.primary
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

            Rectangle {
                id: createButton
                height: 36
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: createButtonMouseArea.containsMouse ? (createButtonMouseArea.pressed ? Qt.darker(Theme.Colors.primary, 1.2) : Qt.lighter(Theme.Colors.primary, 1.2)) : Theme.Colors.primary
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    id: createButtonText
                    anchors.centerIn: parent
                    text: qsTr("Create Security Domain")
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    color: Theme.Colors.primaryText
                }

                MouseArea {
                    id: createButtonMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: sidebar.createDomainRequested()
                }
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
                                    source: Qt.resolvedUrl("icons/icon-dropdown.svg")
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
                                    source: Qt.resolvedUrl("icons/icon-security-domain.svg")
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
                                    font.pixelSize: 14
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

                                    Image {
                                        id: domainRefreshIcon
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        source: Qt.resolvedUrl("icons/icon-update-refresh.svg")
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
                                        running: sidebar.domainRefreshing
                                    }

                                    MouseArea {
                                        id: domainRefreshArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: securityDomainHeader.hovered = false
                                        onExited: securityDomainHeader.hovered = false
                                        onClicked: sidebar.refreshDomainsRequested()
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
                                        font.pixelSize: 14
                                        font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                        color: parent.isSelected ? Theme.Colors.primary : (parent.hovered ? "#1e3a5f" : "#45556c")
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
                                                    color: "#1e5a8e"
                                                    radius: 4

                                                    Text {
                                                        id: domainNameTooltipText
                                                        anchors.centerIn: parent
                                                        width: Math.max(0, parent.width - 16)
                                                        text: domainNameText.text
                                                        font.pixelSize: 13
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
                                                            ctx.fillStyle = "#1e5a8e";
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
                                        color: "#D4183D"
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
                                    source: Qt.resolvedUrl("icons/icon-dropdown.svg")
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
                                    source: Qt.resolvedUrl("icons/icon-security-instance.svg")
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
                                    font.pixelSize: 14
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
                                        font.pixelSize: 14
                                        font.weight: Font.Normal
                                        color: "#45556c"
                                        maximumLineCount: 1
                                        elide: Text.ElideMiddle
                                        width: Math.max(0, parent.width - x - 8)
                                        readonly property bool isOverflow: implicitWidth > width
                                        property bool showTooltip: securityInstanceItemMouseArea.containsMouse && securityInstanceNameText.isOverflow && securityInstanceItemMouseArea.mouseX >= securityInstanceNameText.x && securityInstanceItemMouseArea.mouseX <= (securityInstanceNameText.x + securityInstanceNameText.width)

                                        Rectangle {
                                            visible: parent.showTooltip
                                            width: Math.min(instanceNameTooltipText.implicitWidth + 16, 400)
                                            height: 28
                                            color: "#1e5a8e"
                                            radius: 4
                                            z: 1000
                                            y: -height - 8
                                            x: -8

                                            Text {
                                                id: instanceNameTooltipText
                                                anchors.centerIn: parent
                                                text: parent.parent.text
                                                font.pixelSize: 13
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
                                                    ctx.fillStyle = "#1e5a8e";
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
        Item {
            id: userProfileSection
            width: parent.width
            height: 56
            anchors.bottom: parent.bottom
            anchors.left: parent.left

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(0, 0, 0, 0.1)
                visible: !userMenu.visible
            }

            Row {
                id: userProfileRow
                visible: !userMenu.visible
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "#d4e4f1"
                    clip: true

                    Image {
                        id: sidebarUserAvatar
                        anchors.fill: parent
                        source: sidebar.currentUserAvatar
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: sidebar.currentUserAvatar !== ""
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: Qt.resolvedUrl("icons/icon-user-avatar.svg")
                        fillMode: Image.PreserveAspectFit
                        visible: sidebar.currentUserAvatar === "" || sidebarUserAvatar.status === Image.Error
                    }
                }

                Text {
                    id: sidebarUserNameText
                    width: 111
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!sidebar.currentUser)
                            return "";
                        return sidebar.currentUser.displayName || sidebar.currentUser.userName || "";
                    }
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    color: "#314158"
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                    maximumLineCount: 1
                    elide: Text.ElideMiddle
                    readonly property bool isOverflow: implicitWidth > width
                    property bool showTooltip: userProfileToggleArea.containsMouse && sidebarUserNameText.isOverflow && userProfileToggleArea.mouseX >= (userProfileRow.x + sidebarUserNameText.x) && userProfileToggleArea.mouseX <= (userProfileRow.x + sidebarUserNameText.x + sidebarUserNameText.width)

                    Rectangle {
                        visible: parent.showTooltip
                        width: Math.min(sidebarUserNameTooltipText.implicitWidth + 16, 400)
                        height: 28
                        color: "#1e5a8e"
                        radius: 4
                        z: 1000
                        y: -height - 8
                        x: -8

                        Text {
                            id: sidebarUserNameTooltipText
                            anchors.centerIn: parent
                            text: parent.parent.text
                            font.pixelSize: 13
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
                                ctx.fillStyle = "#1e5a8e";
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

                Image {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("icons/icon-dropdown-arrow.svg")
                    fillMode: Image.PreserveAspectFit
                    rotation: userMenu.visible ? 0 : 180

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            BadgeIndicator {
                visible: !userMenu.visible && count > 0
                x: 161
                anchors.verticalCenter: parent.verticalCenter
                count: sidebar.hasUpdateNotification ? 1 : sidebar.unreadMessageCount
            }

            MouseArea {
                id: userProfileToggleArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                visible: !userMenu.visible
                onClicked: {
                    userMenu.visible = true;
                }
            }

            Rectangle {
                id: userMenu
                visible: false
                width: parent.width
                height: userMenuContent.height
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: "white"
                border.color: "#e2e8f0"
                border.width: 1

                Column {
                    id: userMenuContent
                    width: parent.width

                    Rectangle {
                        width: parent.width
                        height: 56
                        color: userHeaderMouseArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            id: userMenuHeaderRow
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: "#D4E4F1"
                                clip: true

                                Image {
                                    id: userMenuHeaderAvatar
                                    anchors.fill: parent
                                    source: sidebar.currentUserAvatar
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: sidebar.currentUserAvatar !== ""
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                    fillMode: Image.PreserveAspectFit
                                    visible: sidebar.currentUserAvatar === "" || userMenuHeaderAvatar.status === Image.Error
                                }
                            }

                            Text {
                                id: userMenuHeaderUserNameText
                                width: parent.width - 32 - 16 - 36
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!sidebar.currentUser)
                                        return "";
                                    return sidebar.currentUser.displayName || sidebar.currentUser.userName || "";
                                }
                                font.pixelSize: 14
                                color: "#334155"
                                maximumLineCount: 1
                                elide: Text.ElideMiddle
                                readonly property bool isOverflow: implicitWidth > width
                                property bool showTooltip: userHeaderMouseArea.containsMouse && userMenuHeaderUserNameText.isOverflow && userHeaderMouseArea.mouseX >= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x) && userHeaderMouseArea.mouseX <= (userMenuHeaderRow.x + userMenuHeaderUserNameText.x + userMenuHeaderUserNameText.width)

                                Rectangle {
                                    visible: parent.showTooltip
                                    width: Math.min(userMenuHeaderNameTooltipText.implicitWidth + 16, 400)
                                    height: 28
                                    color: "#1e5a8e"
                                    radius: 4
                                    z: 1000
                                    y: -height - 8
                                    x: -8

                                    Text {
                                        id: userMenuHeaderNameTooltipText
                                        anchors.centerIn: parent
                                        text: parent.parent.text
                                        font.pixelSize: 13
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
                                            ctx.fillStyle = "#1e5a8e";
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

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-dropdown-arrow.svg")
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        MouseArea {
                            id: userHeaderMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#e2e8f0"
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: userInfoMouseArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                id: userInfoMenuAvatar
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: sidebar.currentUserAvatar !== "" ? sidebar.currentUserAvatar : Qt.resolvedUrl("icons/icon-user-avatar.svg")
                                fillMode: Image.PreserveAspectFit
                                clip: true
                                onStatusChanged: {
                                    if (status === Image.Error && source !== Qt.resolvedUrl("icons/icon-user-avatar.svg")) {
                                        source = Qt.resolvedUrl("icons/icon-user-avatar.svg");
                                    }
                                }
                            }

                            Text {
                                text: qsTr("User Info")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: userInfoMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                Qt.openUrlExternally(AppConfig.userCenterUrl());
                                sidebar.minimizeWindowRequested();
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: billMenuArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-bill.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: qsTr("My Bills")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: billMenuArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                Qt.openUrlExternally(AppConfig.walletUrl());
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: messagesMouseArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-message.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: qsTr("Message")
                                    font.pixelSize: 14
                                    color: "#334155"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        BadgeIndicator {
                            x: 166
                            anchors.verticalCenter: parent.verticalCenter
                            count: sidebar.unreadMessageCount
                        }

                        MouseArea {
                            id: messagesMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebar.pageRequested("messageCenter")
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: settingsMouseArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-settings.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: qsTr("Settings")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: settingsMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                sidebar.pageRequested("settings");
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: customerServiceMenuArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-help.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: qsTr("Help")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: customerServiceMenuArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                Qt.openUrlExternally(AppConfig.helpDocsUrl());
                            }
                        }
                    }

                    Rectangle {
                        id: updateMenuItem
                        width: parent.width
                        height: 40
                        color: updateMouseArea.containsMouse ? "#E8F1F8" : "transparent"
                        opacity: 1.0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-update-refresh.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: qsTr("Check for Updates")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        BadgeIndicator {
                            visible: sidebar.hasUpdateNotification
                            x: 166
                            anchors.verticalCenter: parent.verticalCenter
                            count: 1
                        }

                        MouseArea {
                            id: updateMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                sidebar.checkUpdateClicked();
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#e2e8f0"
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: logoutMouseArea.containsMouse ? "#E8F1F8" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-logout.svg")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: qsTr("Logout")
                                font.pixelSize: 14
                                color: "#334155"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: logoutMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                userMenu.visible = false;
                                sidebar.logoutRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
