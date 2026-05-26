import QtQuick 2.15
import QtQuick.Layouts 1.15
import "." as Theme
import "DomainUtils.js" as DomainUtils
import "DateTimeUtils.js" as DateTimeUtils

Rectangle {
    id: card

    property var instances: []
    property var visibleUsers: []
    property var currentUser: null
    property var domainData: null
    property bool isDomainReadOnly: false
    property int actionRightMargin: 6
    property int actionTextPixelSize: 14
    property int actionTextWeight: Font.Medium

    signal viewInstanceRequested(var instanceData, bool isApprover)
    function resetPage() { currentPage = 1 }

    property int instanceCount: DomainUtils.toJsArray(instances).length
    property int currentPage: 1
    property int itemsPerPage: 3
    property int totalPages: instanceCount > 0 ? Math.ceil(instanceCount * 1.0 / itemsPerPage) : 0

    readonly property int firstColumnWidth: 140
    readonly property int lastColumnWidth: 78
    readonly property int middleColumnWidth: 176

    FontMetrics {
        id: actionFm
        font.pixelSize: card.actionTextPixelSize
        font.weight: card.actionTextWeight
    }

    function normalizeCurrentPage() {
        if (totalPages <= 0) { if (currentPage !== 1) currentPage = 1; return }
        if (currentPage < 1) { currentPage = 1; return }
        if (currentPage > totalPages) currentPage = totalPages
    }
    onInstanceCountChanged: normalizeCurrentPage()
    onTotalPagesChanged: normalizeCurrentPage()

    function getPagedInstances() {
        var list = DomainUtils.toJsArray(instances)
        var start = (currentPage - 1) * itemsPerPage
        return list.slice(start, Math.min(start + itemsPerPage, list.length))
    }

    function resolveApplicantText(instance) {
        return DomainUtils.resolveInstanceApplicantText(instance, visibleUsers)
    }

    function formatRemainingDays(instance) {
        var days = DateTimeUtils.remainingDays(instance)
        if (days < 0) return "-"
        if (days === 0) return "0" + qsTr(" days")
        return days + qsTr(" days")
    }

    height: 32 + 28 + 12 + (instanceCount > 0 ? (32 + (32 * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
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
                text: qsTr("Related Security Domain Instances")
                font.pixelSize: 14
                color: "#62748e"
            }
        }

        Column {
            width: parent.width
            spacing: 0

            EmptyState {
                visible: card.instanceCount === 0
            }

            Rectangle {
                width: parent.width
                height: 32
                property bool hovered: false
                color: hovered ? "#f2f7fd" : "transparent"
                visible: card.instanceCount > 0

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
                        Layout.preferredWidth: card.firstColumnWidth
                        Layout.minimumWidth: card.firstColumnWidth
                        Layout.maximumWidth: card.firstColumnWidth
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
                        Layout.preferredWidth: card.middleColumnWidth
                        Layout.minimumWidth: card.middleColumnWidth
                        Layout.maximumWidth: card.middleColumnWidth
                        Layout.fillHeight: true

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Instance Name")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.preferredWidth: card.middleColumnWidth
                        Layout.minimumWidth: card.middleColumnWidth
                        Layout.maximumWidth: card.middleColumnWidth
                        Layout.fillHeight: true

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Creation Time")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.preferredWidth: card.middleColumnWidth
                        Layout.minimumWidth: card.middleColumnWidth
                        Layout.maximumWidth: card.middleColumnWidth
                        Layout.fillHeight: true

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 31
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Status")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        Layout.preferredWidth: card.lastColumnWidth
                        Layout.minimumWidth: card.lastColumnWidth
                        Layout.maximumWidth: card.lastColumnWidth
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
                height: Math.max(96, 32 * Math.min(card.itemsPerPage, Math.max(0, card.instanceCount - (card.currentPage - 1) * card.itemsPerPage)))
                spacing: 0
                visible: card.instanceCount > 0

                Repeater {
                    model: card.getPagedInstances()

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
                                Layout.preferredWidth: card.firstColumnWidth
                                Layout.fillHeight: true

                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: card.resolveApplicantText(modelData)
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 6
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.preferredWidth: card.middleColumnWidth
                                Layout.minimumWidth: card.middleColumnWidth
                                Layout.maximumWidth: card.middleColumnWidth
                                Layout.fillHeight: true

                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.instanceName || modelData.name || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 6
                                    beforeChars: 6
                                    afterChars: 6
                                    boundsItem: card
                                }
                            }

                            Item {
                                Layout.preferredWidth: card.middleColumnWidth
                                Layout.minimumWidth: card.middleColumnWidth
                                Layout.maximumWidth: card.middleColumnWidth
                                Layout.fillHeight: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.Utils.formatDateTime(modelData.createdAt || modelData.appliedTime)
                                    font.pixelSize: 14
                                    color: Theme.Colors.textLabel
                                }
                            }

                            Item {
                                Layout.preferredWidth: card.middleColumnWidth
                                Layout.minimumWidth: card.middleColumnWidth
                                Layout.maximumWidth: card.middleColumnWidth
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 31
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: instanceStatusText.implicitWidth + 12
                                    implicitHeight: 24
                                    radius: 6
                                    property var instanceStatusStyle: Theme.Colors.getStatusColor(modelData.status || "")
                                    color: instanceStatusStyle.bg
                                    border.color: instanceStatusStyle.border
                                    border.width: 1

                                    Text {
                                        id: instanceStatusText
                                        anchors.centerIn: parent
                                        text: Theme.Colors.translateStatus(modelData.status || "")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: parent.instanceStatusStyle.text
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }

                            Item {
                                Layout.preferredWidth: card.lastColumnWidth
                                Layout.minimumWidth: card.lastColumnWidth
                                Layout.maximumWidth: card.lastColumnWidth
                                Layout.fillHeight: true

                                Text {
                                    id: instanceOperationText
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
                                        onEntered: instanceOperationText.hovered = true
                                        onExited: instanceOperationText.hovered = false
                                        onClicked: {
                                            var isApprover = false
                                            if (card.currentUser && DomainUtils.isInstanceCreatorVisibleUser(modelData, card.visibleUsers)) {
                                                if (DomainUtils.isCurrentUserDomainCreator(card.currentUser, card.domainData)) {
                                                    isApprover = true
                                                }
                                            }
                                            card.viewInstanceRequested(modelData, isApprover)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PaginationControl {
                currentPage: card.currentPage
                totalPages: card.totalPages
                onPageChanged: card.currentPage = page
            }
        }
    }
}
