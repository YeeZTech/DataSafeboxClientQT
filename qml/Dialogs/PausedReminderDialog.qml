import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
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

    focus: true
    dialogWidth: Math.min(460, (parent ? parent.width : 460) - 24)
    title: qsTr("Balance Reminder")

    Column {
        width: parent.width
        spacing: 16

        Rectangle {
            width: parent.width
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
                font.pixelSize: Theme.Typography.body
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
            width: parent.width
            height: 24

            Text {
                id: instanceNamesLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textLabel
                text: qsTr("Overdue Instance Names:")
            }

            Text {
                id: instanceNamesValue
                anchors.left: instanceNamesLabel.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.Typography.body
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
            leftPadding: 27
            font.pixelSize: Theme.Typography.body
            color: Theme.Colors.textLabel
            textFormat: Text.RichText
            text: qsTr("Total Overdue:") + "   <span style='color:#bb4d00;font-weight:600;'>" + root.balanceText + "</span> " + qsTr("CNY")
        }
    }
}
