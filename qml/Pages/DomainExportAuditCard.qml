import QtQuick 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Rectangle {
    id: card

    property var audits: []
    property int actionRightMargin: 6
    property int actionTextPixelSize: 14
    property int actionTextWeight: Font.Medium

    signal viewExportRequested(var auditData)
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

    function formatFileSizeLowercase(bytesValue) {
        var s = (Theme.Utils.formatSize(bytesValue) || "").toString().trim();
        return s.replace(/\b([KMGT]?B)\b/g, function (unit) {
            return unit.toLowerCase();
        });
    }

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
                text: qsTr("File Export Review")
                font.pixelSize: 14
                color: Theme.Colors.textCaption
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
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.preferredWidth: card.colApplyCode
                        Layout.fillHeight: true
                        Text {
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
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
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
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("File Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("File Size")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                            width: Math.max(0, parent.width - 12)
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Application Time")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                            width: Math.max(0, parent.width)
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 30
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
                        Text {
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
                                Layout.minimumWidth: 28
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
                                Layout.minimumWidth: 28
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.fileName || modelData.file_name || ""
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
                                Layout.minimumWidth: 28
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: card.formatFileSizeLowercase(modelData.fileSize) || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 3
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 28
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
                                Layout.minimumWidth: 28
                                Layout.fillHeight: true
                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: Theme.Utils.formatDateTime(modelData.applyTime || modelData.createdAt || "")
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 0
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 4
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 28
                                Layout.fillHeight: true
                                StatusBadge {
                                    id: expStatusBadge
                                    anchors.left: parent.left
                                    anchors.leftMargin: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - 30)
                                    status: modelData.status || ""
                                    MouseArea {
                                        id: expStatusHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.ArrowCursor
                                    }
                                    Loader {
                                        active: expStatusBadge.truncated && expStatusHover.containsMouse
                                        sourceComponent: expStatusTooltipComp
                                        onLoaded: {
                                            var win = expStatusBadge.Window.window;
                                            if (win && item)
                                                item.parent = win.contentItem;
                                        }
                                    }
                                    Component {
                                        id: expStatusTooltipComp
                                        Item {
                                            id: expTip
                                            z: 99999
                                            property point cellTL: {
                                                var win = expStatusBadge.Window.window;
                                                if (!win)
                                                    return Qt.point(0, 0);
                                                return expStatusBadge.mapToItem(win.contentItem, 0, 0);
                                            }
                                            property real anchorX: {
                                                var win = expStatusBadge.Window.window;
                                                if (!win)
                                                    return 0;
                                                return expStatusBadge.mapToItem(win.contentItem, expStatusBadge.width * 0.5, 0).x;
                                            }
                                            readonly property real arrowSz: 6
                                            readonly property real winW: expStatusBadge.Window.window ? expStatusBadge.Window.window.width : 800
                                            readonly property real winH: expStatusBadge.Window.window ? expStatusBadge.Window.window.height : 600
                                            readonly property rect bRect: {
                                                var win = expStatusBadge.Window.window;
                                                if (!win)
                                                    return Qt.rect(0, 0, winW, winH);
                                                var tl = card.mapToItem(win.contentItem, 0, 0);
                                                return Qt.rect(tl.x, tl.y, card.width, card.height);
                                            }
                                            readonly property real bW: Math.min(400, expTipText.implicitWidth + 18)
                                            readonly property real bH: expTipText.implicitHeight + 16
                                            readonly property real bX: Math.max(bRect.x + 4, Math.min(anchorX - bW * 0.5, bRect.x + bRect.width - bW - 4))
                                            readonly property real arrX: Math.max(4, Math.min(anchorX - bX - arrowSz, bW - arrowSz * 2 - 4))
                                            readonly property bool flip: (cellTL.y - bH - arrowSz) < (bRect.y + 4)
                                            width: expBubble.width
                                            height: expBubble.height + arrowSz
                                            x: bX
                                            y: (expTip.flip ? (cellTL.y + expStatusBadge.height) : (cellTL.y - bH - arrowSz)) + 5
                                            opacity: 0
                                            Component.onCompleted: opacity = 1
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 120
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                            Rectangle {
                                                id: expBubble
                                                x: 0
                                                y: expTip.flip ? expTip.arrowSz : 0
                                                width: expTip.bW
                                                height: expTip.bH
                                                color: "#1e5a8e"
                                                radius: 4
                                                Text {
                                                    id: expTipText
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
                                                width: expTip.arrowSz * 2
                                                height: expTip.arrowSz
                                                x: expTip.arrX
                                                y: expTip.flip ? 0 : expTip.bH
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.fillStyle = "#1e5a8e";
                                                    ctx.beginPath();
                                                    if (expTip.flip) {
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
                                    id: exportOperationText
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.max(card.actionRightMargin, parent.width - card.actionRightMargin - actionFm.advanceWidth(qsTr("Actions")))
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("View")
                                    font.pixelSize: card.actionTextPixelSize
                                    font.weight: card.actionTextWeight
                                    property bool hovered: false
                                    font.underline: false
                                    color: Theme.Colors.primary
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: exportOperationText.hovered = true
                                        onExited: exportOperationText.hovered = false
                                        onClicked: card.viewExportRequested(modelData)
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
                onPageChanged: function (page) {
                    card.currentPage = page;
                }
            }
        }
    }
}
