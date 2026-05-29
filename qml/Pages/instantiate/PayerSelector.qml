import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Row {
    id: root

    property string selectedPayer: ""
    property string creatorValue: ""
    property string userValue: ""
    property int labelWidth: 110
    property int fieldWidth: 240
    property int fieldSpacing: 40
    property string fontFamily: "Microsoft YaHei"
    property int fontSizeLabel: Theme.Typography.body
    property int fontSizeBody: Theme.Typography.h3

    signal payerSelected(string payer)

    width: parent ? parent.width : 400
    height: 36
    spacing: root.fieldSpacing

    Item {
        width: root.labelWidth
        height: 36

        Row {
            id: payerTextRow
            anchors.right: parent.right
            anchors.rightMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: "*"
                font.family: root.fontFamily
                font.pixelSize: root.fontSizeLabel
                color: Theme.Colors.requiredMarker
                anchors.verticalCenter: parent.verticalCenter
            }

            SelectableText {
                text: qsTr("Cost Bearer:")
                font.family: root.fontFamily
                font.pixelSize: root.fontSizeLabel
                color: Theme.Colors.textLabel
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HelpTooltipButton {
            anchors.left: payerTextRow.right
            anchors.leftMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            fontFamily: root.fontFamily
            tooltipText: qsTr("Creating a security domain instance will incur fees (1 CNY/GB/Month). The fees can be borne by the security domain creator or the instance user.")
        }
    }

    Row {
        width: root.fieldWidth
        height: 36
        spacing: 24
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 2

        PayerOption {
            value: root.creatorValue
            label: qsTr("Creator")
            selected: root.selectedPayer === root.creatorValue
            fontFamily: root.fontFamily
            fontSizeBody: root.fontSizeBody
            onOptionClicked: function (value) {
                root.payerSelected(value);
            }
        }

        PayerOption {
            value: root.userValue
            label: qsTr("User")
            selected: root.selectedPayer === root.userValue
            fontFamily: root.fontFamily
            fontSizeBody: root.fontSizeBody
            onOptionClicked: function (value) {
                root.payerSelected(value);
            }
        }
    }

    component PayerOption: Row {
        id: option

        property string value: ""
        property string label: ""
        property bool selected: false
        property string fontFamily: "Microsoft YaHei"
        property int fontSizeBody: Theme.Typography.h3

        signal optionClicked(string value)

        spacing: 8
        height: 36

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            property bool hovered: false
            border.color: option.selected ? Theme.Colors.primary : (hovered ? Qt.darker(Theme.Colors.primary, 1.1) : Theme.Colors.borderField)
            border.width: 1
            color: "transparent"

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.centerIn: parent
                color: Theme.Colors.primary
                visible: option.selected
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: option.optionClicked(option.value)
            }
        }

        Text {
            text: option.label
            font.family: option.fontFamily
            font.pixelSize: option.fontSizeBody
            font.weight: Font.Normal
            color: Theme.Colors.textLabel
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: option.optionClicked(option.value)
            }
        }
    }
}
