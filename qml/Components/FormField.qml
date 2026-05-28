import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Row {
    id: root

    property string label: ""
    property bool required: false
    property string errorText: ""
    property int labelWidth: 110
    property int fieldSpacing: 40
    default property alias fieldContent: fieldContainer.data

    width: parent ? parent.width : 400
    spacing: root.fieldSpacing
    height: Math.max(36, fieldContainer.implicitHeight)

    Item {
        width: root.labelWidth
        height: 36

        Row {
            anchors.right: parent.right
            anchors.rightMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                visible: root.required
                text: "*"
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.requiredMarker
                anchors.top: parent.top
                anchors.topMargin: 2
            }

            Text {
                text: root.label
                font.pixelSize: Theme.Typography.body
                color: Theme.Colors.textLabel
            }
        }
    }

    Column {
        id: fieldContainer
        width: parent.width - root.labelWidth - root.fieldSpacing
        spacing: 4

        Text {
            visible: root.errorText !== ""
            text: root.errorText
            font.pixelSize: Theme.Typography.small
            color: Theme.Colors.textError
            width: parent.width
        }
    }
}
