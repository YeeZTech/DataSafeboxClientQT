import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Rectangle {
    id: card

    property var visibleUsers: []
    property bool isDomainReadOnly: false
    property bool operationBusy: false
    property string pendingRemovedAccount: ""
    property int actionRightMargin: 6
    property int actionTextPixelSize: 14
    property int actionTextWeight: Font.Medium

    signal addUserRequested
    signal removeUserRequested(string account, string authUserId)
    function resetPage() {
        currentPage = 1;
    }

    property int userCount: visibleUsers ? visibleUsers.length : 0
    property int currentPage: 1
    property int itemsPerPage: 3
    property int totalPages: userCount > 0 ? Math.ceil(userCount * 1.0 / itemsPerPage) : 0
    readonly property int operationColumnWidth: 88
    readonly property int nameColumnWidth: Math.floor((width - 32 - operationColumnWidth) / 2)
    readonly property int accountColumnWidth: Math.max(0, width - 32 - nameColumnWidth - operationColumnWidth)

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
    onUserCountChanged: normalizeCurrentPage()
    onTotalPagesChanged: normalizeCurrentPage()

    height: 32 + 28 + 12 + (userCount > 0 ? (32 + (32 * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
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
                text: qsTr("Visible Users")
                font.pixelSize: 14
                color: "#62748e"
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 74
                height: 32
                radius: 8
                property bool hovered: false
                property bool pressed: false
                color: {
                    if (pressed)
                        return "#c1d9ef";
                    if (hovered)
                        return "#eaf2fb";
                    return "transparent";
                }
                visible: true
                opacity: (!card.isDomainReadOnly && !card.operationBusy) ? 1.0 : 0.5
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: card.actionRightMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/icon-add-user-blue.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Add")
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.Colors.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !card.isDomainReadOnly && !card.operationBusy
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onPressed: parent.pressed = true
                    onReleased: parent.pressed = false
                    onCanceled: parent.pressed = false
                    onClicked: card.addUserRequested()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 0

            EmptyState {
                visible: card.userCount === 0
            }

            Rectangle {
                width: parent.width
                height: 32
                property bool hovered: false
                color: hovered ? "#f2f7fd" : "transparent"
                visible: card.userCount > 0

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

                Row {
                    anchors.fill: parent

                    Item {
                        width: card.accountColumnWidth
                        height: parent.height

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Dianshu ID")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        width: card.nameColumnWidth
                        height: parent.height

                        SelectableText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Nickname")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Theme.Colors.textLabel
                        }
                    }

                    Item {
                        width: card.operationColumnWidth
                        height: parent.height
                        visible: true

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
                height: Math.max(96, 32 * Math.min(card.itemsPerPage, Math.max(0, card.userCount - (card.currentPage - 1) * card.itemsPerPage)))
                spacing: 0
                visible: card.userCount > 0

                Repeater {
                    model: {
                        var users = card.visibleUsers || [];
                        var start = (card.currentPage - 1) * card.itemsPerPage;
                        return users.slice(start, Math.min(start + card.itemsPerPage, users.length));
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

                        Row {
                            anchors.fill: parent

                            Item {
                                width: card.accountColumnWidth
                                height: parent.height

                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.authUserName || modelData.user_name || modelData.account || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 28
                                    boundsItem: card
                                }
                            }

                            Item {
                                width: card.nameColumnWidth
                                height: parent.height

                                CenteredTooltipText {
                                    anchors.fill: parent
                                    value: modelData.displayName || modelData.account || ""
                                    textPixelSize: 14
                                    textColor: Theme.Colors.textLabel
                                    leftMargin: 6
                                    rightMargin: 28
                                    boundsItem: card
                                }
                            }

                            Item {
                                width: card.operationColumnWidth
                                height: parent.height
                                visible: true
                                opacity: !card.isDomainReadOnly ? 1.0 : 0.5
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    id: removeText
                                    anchors.right: parent.right
                                    anchors.rightMargin: card.actionRightMargin
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Remove")
                                    font.pixelSize: card.actionTextPixelSize
                                    font.weight: card.actionTextWeight
                                    property bool hovered: false
                                    color: removeText.hovered ? "#d32f2f" : "#f44336"

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !card.isDomainReadOnly && !card.operationBusy
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onEntered: removeText.hovered = true
                                        onExited: removeText.hovered = false
                                        onClicked: {
                                            if (card.isDomainReadOnly || card.operationBusy)
                                                return;
                                            if (card.pendingRemovedAccount)
                                                return;
                                            var targetAccount = modelData.account || "";
                                            var targetAuthUserId = modelData.authUserId || "";
                                            if (!targetAuthUserId)
                                                return;
                                            card.removeUserRequested(targetAccount, targetAuthUserId);
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
