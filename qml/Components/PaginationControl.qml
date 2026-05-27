import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: paginationRoot
    width: parent ? parent.width : 200
    height: 36

    property int currentPage: 1
    property int totalPages: 0

    signal pageChanged(int page)

    visible: totalPages > 1

    function getVisiblePages() {
        var total = paginationRoot.totalPages;
        var current = paginationRoot.currentPage;
        var pages = [];
        if (total <= 7) {
            for (var i = 1; i <= total; i++)
                pages.push(i);
        } else {
            if (current <= 4) {
                for (var j = 1; j <= 5; j++)
                    pages.push(j);
                pages.push(-1);
                pages.push(total);
            } else if (current >= total - 3) {
                pages.push(1);
                pages.push(-1);
                for (var k = total - 4; k <= total; k++)
                    pages.push(k);
            } else {
                pages.push(1);
                pages.push(-1);
                for (var m = current - 1; m <= current + 1; m++)
                    pages.push(m);
                pages.push(-1);
                pages.push(total);
            }
        }
        return pages;
    }

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10
        spacing: 6

        Text {
            text: "<"
            font.pixelSize: 14
            property bool hovered: false
            property bool pressed: false
            color: {
                if (paginationRoot.currentPage <= 1)
                    return "#919eab";
                if (pressed)
                    return "white";
                if (hovered)
                    return "#1b5fa8";
                return "#212b36";
            }
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 22
                height: 22
                radius: 3
                visible: paginationRoot.currentPage > 1 && (parent.hovered || parent.pressed)
                color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                z: -1
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: paginationRoot.currentPage > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: {
                    parent.hovered = false;
                    parent.pressed = false;
                }
                onPressed: parent.pressed = true
                onReleased: parent.pressed = false
                onClicked: {
                    paginationRoot.currentPage--;
                    paginationRoot.pageChanged(paginationRoot.currentPage);
                }
            }
        }

        Repeater {
            model: paginationRoot.getVisiblePages()
            Rectangle {
                width: 22
                height: 22
                radius: 3
                property int pageNum: modelData
                property bool isEllipsis: pageNum === -1
                property bool hovered: false
                property bool pressed: false
                property bool isCurrent: pageNum === paginationRoot.currentPage
                color: {
                    if (pressed && !isCurrent)
                        return "#1b5fa8";
                    if (hovered)
                        return "#e3f2fd";
                    return "white";
                }
                border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: parent.isEllipsis ? "..." : parent.pageNum
                    font.pixelSize: 12
                    color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !parent.isEllipsis
                    cursorShape: !parent.isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true
                    onEntered: parent.hovered = true
                    onExited: {
                        parent.hovered = false;
                        parent.pressed = false;
                    }
                    onPressed: if (!parent.isCurrent)
                        parent.pressed = true
                    onReleased: parent.pressed = false
                    onClicked: {
                        if (!parent.isCurrent) {
                            paginationRoot.currentPage = parent.pageNum;
                            paginationRoot.pageChanged(paginationRoot.currentPage);
                        }
                    }
                }
            }
        }

        Text {
            text: ">"
            font.pixelSize: 14
            property bool hovered: false
            property bool pressed: false
            color: {
                if (paginationRoot.currentPage >= paginationRoot.totalPages)
                    return "#919eab";
                if (pressed)
                    return "white";
                if (hovered)
                    return "#1b5fa8";
                return "#212b36";
            }
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 22
                height: 22
                radius: 3
                visible: paginationRoot.currentPage < paginationRoot.totalPages && (parent.hovered || parent.pressed)
                color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                z: -1
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: paginationRoot.currentPage < paginationRoot.totalPages
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: {
                    parent.hovered = false;
                    parent.pressed = false;
                }
                onPressed: parent.pressed = true
                onReleased: parent.pressed = false
                onClicked: {
                    paginationRoot.currentPage++;
                    paginationRoot.pageChanged(paginationRoot.currentPage);
                }
            }
        }
    }
}
