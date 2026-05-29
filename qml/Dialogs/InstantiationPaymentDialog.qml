import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    height: 382
    title: qsTr("Security Domain Instance Payment Confirmation")
    onCloseRequested: cancelClicked()

    property string instanceSize: "250 GB"
    property string instanceFee: "2 months"
    property string billingRule: "30 CNY/GB/Month"
    property string estimatedFee: "350.00"
    property string durationText: ""

    signal confirmClicked(string duration)
    signal cancelClicked

    Column {
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 12
        }

        Rectangle {
            width: parent.width
            height: 81
            radius: 10
            color: "#fffbeb"
            border.width: 0.65
            border.color: "#fee685"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 8
                anchors.topMargin: 16
                anchors.bottomMargin: 4
                spacing: 12

                Image {
                    width: 20
                    height: 20
                    anchors.top: warningText.top
                    source: "qrc:/icons/icon-warnning.svg"
                    fillMode: Image.PreserveAspectFit
                }

                SelectableText {
                    id: warningText
                    width: 320
                    wrapMode: TextEdit.Wrap
                    text: qsTr("Instantiating this security domain requires payment of the following fees:")
                    font.pixelSize: 14
                    color: Theme.Colors.textLabel
                }
            }
        }

        Item {
            width: parent.width
            height: 16
        }

        Column {
            width: parent.width
            spacing: 12

            Item {
                width: parent.width
                height: 20

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Storage Space:")
                    font.pixelSize: 14
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.instanceSize
                    font.pixelSize: 14
                    color: Theme.Colors.textHeading
                }
            }

            Item {
                width: parent.width
                height: 20

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Instance Duration:")
                    font.pixelSize: 14
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.instanceFee
                    font.pixelSize: 14
                    color: Theme.Colors.textHeading
                }
            }

            Item {
                width: parent.width
                height: 20

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Billing Rule:")
                    font.pixelSize: 14
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.billingRule
                    font.pixelSize: 14
                    color: Theme.Colors.textHeading
                }
            }

            Rectangle {
                width: parent.width
                height: 0.65
                color: Qt.rgba(0, 0, 0, 0.1)
            }

            Item {
                width: parent.width
                height: 20

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Estimated Fee:")
                    font.pixelSize: 14
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.estimatedFee + qsTr(" CNY")
                    font.pixelSize: 14
                    color: Theme.Colors.textHeading
                }
            }
        }

        Item {
            width: parent.width
            height: 24
        }

        Row {
            width: parent.width
            height: 36
            spacing: 8
            layoutDirection: Qt.RightToLeft

            PrimaryButton {
                text: qsTr("Confirm Payment")
                onClicked: {
                    root.confirmClicked(root.durationText);
                    root.close();
                }
            }

            SecondaryButton {
                text: qsTr("Cancel")
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }
        }
    }
}
