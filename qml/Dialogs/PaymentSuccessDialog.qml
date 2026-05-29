import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 448
    height: 303.28
    title: qsTr("Security Domain Instance Payment Confirmation")
    onCloseRequested: cancelClicked()

    signal confirmClicked
    signal cancelClicked

    Column {
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 32
        }

        Rectangle {
            width: 64
            height: 64
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#DCFCE7"

            Image {
                anchors.centerIn: parent
                width: 40
                height: 40
                source: "qrc:/icons/icon-check-success.svg"
                fillMode: Image.PreserveAspectFit
            }
        }

        Item {
            width: parent.width
            height: 16
        }

        Item {
            width: parent.width
            height: 24

            SelectableText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Payment Successful")
                font.pixelSize: 16
                font.weight: Font.Medium
                color: Theme.Colors.textHeading
            }
        }

        Item {
            width: parent.width
            height: 32
        }

        PrimaryButton {
            width: parent.width
            text: qsTr("OK")
            onClicked: {
                root.confirmClicked();
                root.close();
            }
        }
    }
}
