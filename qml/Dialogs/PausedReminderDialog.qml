import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Popup {
    id: root

    property var focusInstanceNames: []
    property string fallbackDomainCode: ""
    property string billUrl: "https://test-dsbox.dianshudata.com/wallet"
    property var dataManager: Theme.DataManager

    readonly property string reminderMessage: qsTr("Account overdue. Please recharge on the <a href=\"bill\"><u><b>My Bills</b></u></a> page to continue.")
    readonly property string instanceNamesText: {
        var names = [];
        function pushUnique(value) {
            var text = (value || "").toString().trim();
            if (!text) {
                return;
            }
            if (names.indexOf(text) === -1) {
                names.push(text);
            }
        }
        if (root.focusInstanceNames && root.focusInstanceNames.length) {
            for (var i = 0; i < root.focusInstanceNames.length; i++) {
                pushUnique(root.focusInstanceNames[i]);
            }
        }
        if (names.length === 0 && root.fallbackDomainCode && root.dataManager && root.dataManager.getInstanceNamesByDomainCode) {
            var domainNames = root.dataManager.getInstanceNamesByDomainCode(root.fallbackDomainCode) || [];
            for (var j = 0; j < domainNames.length; j++) {
                pushUnique(domainNames[j]);
            }
        }
        if (names.length === 0) {
            return "-";
        }
        if (names.length <= 2) {
            return names.join("、");
        }
        return names[0] + "、" + names[1] + "...";
    }

    readonly property string balanceText: {
        if (!root.dataManager || !root.dataManager.arrearsOverviewData) {
            return "-";
        }
        var raw = root.dataManager.arrearsOverviewData.balance;
        if (raw === undefined || raw === null || raw === "") {
            return "-";
        }
        var num = Number(raw);
        if (isNaN(num)) {
            return String(raw);
        }
        return num.toFixed(2);
    }

    parent: Overlay.overlay
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(460, (parent ? parent.width : 460) - 24)
    height: Math.max(224, amountText.y + amountText.implicitHeight + 24)
    x: ((parent ? parent.width : width) - width) / 2
    y: ((parent ? parent.height : height) - height) / 2

    background: Rectangle {
        color: "#ffffff"
        radius: 10
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
    }

    contentItem: Item {
        anchors.fill: parent

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 24
            text: qsTr("Balance Reminder")
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.Colors.textHeading
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 60
            height: 77
            radius: 10
            color: "#fffbeb"
            border.color: "#fee685"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: "transparent"
                border.color: "#f97316"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: "#f97316"
                }
            }

            Text {
                id: reminderText
                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.RichText
                text: root.reminderMessage
                font.pixelSize: 14
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.WordWrap
                color: Theme.Colors.textCaption
            }

            MouseArea {
                id: reminderLinkArea
                anchors.fill: reminderText
                hoverEnabled: true
                cursorShape: reminderText.linkAt(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: function (mouse) {
                    var link = reminderText.linkAt(mouse.x, mouse.y);
                    if (!link) {
                        return;
                    }
                    var targetUrl = (root.billUrl && root.billUrl.length > 0) ? root.billUrl : "https://test-dsbox.dianshudata.com/wallet";
                    Qt.openUrlExternally(targetUrl);
                    root.close();
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 155
            height: 24

            Text {
                id: instanceNamesLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14
                color: Theme.Colors.textLabel
                text: qsTr("Overdue Instance Names:")
            }

            Text {
                id: instanceNamesValue
                anchors.left: instanceNamesLabel.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14
                color: Theme.Colors.textLabel
                text: root.instanceNamesText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            MouseArea {
                id: instanceNamesHoverArea
                anchors.fill: instanceNamesValue
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            ToolTip.visible: instanceNamesHoverArea.containsMouse && instanceNamesValue.implicitWidth > instanceNamesValue.width
            ToolTip.text: root.instanceNamesText
            ToolTip.delay: 300
        }

        Text {
            id: amountText
            anchors.left: parent.left
            anchors.leftMargin: 51
            anchors.top: parent.top
            anchors.topMargin: 188
            font.pixelSize: 14
            color: Theme.Colors.textLabel
            textFormat: Text.RichText
            text: qsTr("Total Overdue:") + "   <span style='color:#bb4d00;font-weight:600;'>" + root.balanceText + "</span> " + qsTr("CNY")
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: closeArea.containsMouse ? Theme.Colors.backgroundGray : "transparent"
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 20

            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: 18
                color: closeArea.containsMouse ? Theme.Colors.primary : Theme.Colors.textLabel
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
        }
    }
}
