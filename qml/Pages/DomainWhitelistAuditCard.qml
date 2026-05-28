import QtQuick 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0
import "DomainUtils.js" as DomainUtils

Rectangle {
    id: card

    property var audits: []
    property int actionRightMargin: 6
    property int actionTextPixelSize: 14
    property int actionTextWeight: Font.Medium

    signal viewAuditRequested(var auditData)
    function resetPage() {
        currentPage = 1;
    }

    property int auditCount: audits ? audits.length : 0
    property int currentPage: 1
    property int itemsPerPage: 3
    property int totalPages: auditCount > 0 ? Math.ceil(auditCount * 1.0 / itemsPerPage) : 0
    readonly property int colApplyCode: 100
    readonly property int colAction: 82

    FontMetrics {
        id: actionFm
        font.pixelSize: card.actionTextPixelSize
        font.weight: card.actionTextWeight
    }

    function normalizeCurrentPage() {
        if (totalPages <= 0) {
            if (currentPage !== 1)
                currentPage = 1;
            return;
        }
        if (currentPage < 1) {
            currentPage = 1;
            return;
        }
        if (currentPage > totalPages)
            currentPage = totalPages;
    }
    onAuditCountChanged: normalizeCurrentPage()
    onTotalPagesChanged: normalizeCurrentPage()

    height: 32 + 28 + 12 + (auditCount > 0 ? (32 + (32 * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
    radius: 14
    color: Theme.Colors.backgroundWhite
    antialiasing: true
    smooth: true
    clip: true

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Item {
            width: parent.width
            height: 28

            SelectableText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("App Whitelist Review")
                font.pixelSize: 14
                color: "#62748e"
            }
        }

        Column {
            width: parent.width
            spacing: 0

            EmptyState {
                visible: card.auditCount === 0
            }

            Rectangle {
                width: parent.width
                height: 32
                property bool hovered: false
                color: hovered ? "#f2f7fd" : "transparent"
                visible: card.auditCount > 0

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.Colors.borderSlate
                }

                HoverHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onHoveredChanged: parent.hovered = hovered
                }

                RowLayout {
                    id: appWhitelistHeaderRow
                    anchors.fill: parent
                    spacing: 0
                    property int titleGap: Math.max(6, card.colApplyCode - applicationIdText.implicitWidth)

                    Item {
                        Layout.preferredWidth: card.colApplyCode
                        Layout.fillHeight: true
                        SelectableText {
                            id: applicationIdText
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Application ID")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Applicant")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("App Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Application Time")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 54
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Status")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.preferredWidth: card.colAction
                        Layout.fillHeight: true
                        SelectableText {
                            anchors.right: parent.right
                            anchors.rightMargin: card.actionRightMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Actions")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }
                }
            }

            Column {
                width: parent.width
                height: Math.max(96, 32 * Math.min(card.itemsPerPage, Math.max(0, card.auditCount - (card.currentPage - 1) * card.itemsPerPage)))
                spacing: 0
                visible: card.auditCount > 0

                Repeater {
                    model: {
                        var list = card.audits || [];
                        var start = (card.currentPage - 1) * card.itemsPerPage;
                        return list.slice(start, Math.min(start + card.itemsPerPage, list.length));
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        property bool hovered: false
                        color: hovered ? "#f2f7fd" : "transparent"

                        HoverHandler {
                            acceptedDevices: PointerDevice.Mouse
                            onHoveredChanged: parent.hovered = hovered
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            Item {
                                Layout.preferredWidth: card.colApplyCode
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.applyCode || modelData.id || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 4
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.applicantUserName || modelData.applicant || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 4
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.appName || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 4
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.instanceName || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 4
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.Utils.formatDateTime(modelData.applyTime || modelData.createdAt || "")
                                    font.pixelSize: 14
                                    color: Theme.Colors.textLabel
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                StatusBadge {
                                    id: whitelistStatusBadge
                                    anchors.left: parent.left
                                    anchors.leftMargin: 54
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - 54)
                                    status: modelData.status || ""
                                    MouseArea {
                                        id: wlStatusHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.ArrowCursor
                                    }
                                    Loader {
                                        active: whitelistStatusBadge.truncated && wlStatusHover.containsMouse
                                        sourceComponent: wlStatusTooltipComp
                                        onLoaded: {
                                            var win = whitelistStatusBadge.Window.window;
                                            if (win && item)
                                                item.parent = win.contentItem;
                                        }
                                    }
                                    Component {
                                        id: wlStatusTooltipComp
                                        Item {
                                            id: wlTip
                                            z: 99999
                                            property point cellTL: {
                                                var win = whitelistStatusBadge.Window.window;
                                                if (!win)
                                                    return Qt.point(0, 0);
                                                return whitelistStatusBadge.mapToItem(win.contentItem, 0, 0);
                                            }
                                            property real anchorX: {
                                                var win = whitelistStatusBadge.Window.window;
                                                if (!win)
                                                    return 0;
                                                return whitelistStatusBadge.mapToItem(win.contentItem, whitelistStatusBadge.width * 0.5, 0).x;
                                            }
                                            readonly property real arrowSz: 6
                                            readonly property real winW: whitelistStatusBadge.Window.window ? whitelistStatusBadge.Window.window.width : 800
                                            readonly property real winH: whitelistStatusBadge.Window.window ? whitelistStatusBadge.Window.window.height : 600
                                            readonly property rect bRect: {
                                                var win = whitelistStatusBadge.Window.window;
                                                if (!win)
                                                    return Qt.rect(0, 0, winW, winH);
                                                var tl = card.mapToItem(win.contentItem, 0, 0);
                                                return Qt.rect(tl.x, tl.y, card.width, card.height);
                                            }
                                            readonly property real bW: Math.min(400, wlTipText.implicitWidth + 18)
                                            readonly property real bH: wlTipText.implicitHeight + 16
                                            readonly property real bX: Math.max(bRect.x + 4, Math.min(anchorX - bW * 0.5, bRect.x + bRect.width - bW - 4))
                                            readonly property real arrX: Math.max(4, Math.min(anchorX - bX - arrowSz, bW - arrowSz * 2 - 4))
                                            readonly property bool flip: (cellTL.y - bH - arrowSz) < (bRect.y + 4)
                                            width: wlBubble.width
                                            height: wlBubble.height + arrowSz
                                            x: bX
                                            y: (wlTip.flip ? (cellTL.y + whitelistStatusBadge.height) : (cellTL.y - bH - arrowSz)) + 5
                                            opacity: 0
                                            Component.onCompleted: opacity = 1
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 120
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                            Rectangle {
                                                id: wlBubble
                                                x: 0
                                                y: wlTip.flip ? wlTip.arrowSz : 0
                                                width: wlTip.bW
                                                height: wlTip.bH
                                                color: "#1e5a8e"
                                                radius: 4
                                                Text {
                                                    id: wlTipText
                                                    anchors {
                                                        left: parent.left
                                                        leftMargin: 9
                                                        right: parent.right
                                                        rightMargin: 9
                                                        top: parent.top
                                                        topMargin: 8
                                                    }
                                                    text: Theme.Colors.translateStatus(modelData.status || "")
                                                    color: "white"
                                                    font.pixelSize: 13
                                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                    maximumLineCount: 999
                                                }
                                            }
                                            Canvas {
                                                width: wlTip.arrowSz * 2
                                                height: wlTip.arrowSz
                                                x: wlTip.arrX
                                                y: wlTip.flip ? 0 : wlTip.bH
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.fillStyle = "#1e5a8e";
                                                    ctx.beginPath();
                                                    if (wlTip.flip) {
                                                        ctx.moveTo(width * 0.5, 0);
                                                        ctx.lineTo(0, height);
                                                        ctx.lineTo(width, height);
                                                    } else {
                                                        ctx.moveTo(0, 0);
                                                        ctx.lineTo(width * 0.5, height);
                                                        ctx.lineTo(width, 0);
                                                    }
                                                    ctx.closePath();
                                                    ctx.fill();
                                                }
                                                Component.onCompleted: requestPaint()
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.preferredWidth: card.colAction
                                Layout.fillHeight: true

                                Text {
                                    id: appWhitelistOperationText
                                    property bool hovered: false
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.max(card.actionRightMargin, parent.width - card.actionRightMargin - actionFm.advanceWidth(qsTr("Actions")))
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("View")
                                    font.pixelSize: card.actionTextPixelSize
                                    font.weight: card.actionTextWeight
                                    font.underline: false
                                    color: Theme.Colors.primary

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: appWhitelistOperationText.hovered = true
                                        onExited: appWhitelistOperationText.hovered = false
                                        onClicked: card.viewAuditRequested(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PaginationControl {
                visible: card.auditCount > 0 && card.totalPages > 1
                currentPage: card.currentPage
                totalPages: card.totalPages
                onPageChanged: card.currentPage = page
            }
        }
    }
}
