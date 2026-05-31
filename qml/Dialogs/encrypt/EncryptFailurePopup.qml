import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 420
    title: qsTr("Encryption Failed")

    property string errorText: ""

    signal retryRequested
    signal contactSupportRequested

    Column {
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 72
            Rectangle {
                width: 56
                height: 56
                anchors.centerIn: parent
                radius: 28
                color: "#fee2e2"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#ef4444"
                }
            }
        }

        Text {
            width: parent.width
            text: qsTr("Encryption Failed")
            font.pixelSize: Theme.Typography.h3
            font.weight: Font.Medium
            color: Theme.Colors.textHeading
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            textFormat: Text.RichText
            text: qsTr("File encryption failed. Reason: ") + "<a href='https://help.yeez.tech/docs/bu-zhou-5-mai-fang-jia-mi-yuan-shi-shu-ju' style='color:#ef4444;text-decoration:underline;'>" + root.errorText + "</a>，" + qsTr(" You may try encrypting again or contact support for help.")
            font.pixelSize: Theme.Typography.body
            color: "#475569"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            onLinkActivated: Qt.openUrlExternally(link)
        }

        Row {
            anchors.right: parent.right
            spacing: 12
            topPadding: 4

            SecondaryButton {
                text: qsTr("Contact Support")
                accent: true
                onClicked: {
                    root.close();
                    root.contactSupportRequested();
                }
            }

            PrimaryButton {
                text: qsTr("Retry")
                onClicked: {
                    root.close();
                    root.retryRequested();
                }
            }
        }
    }
}
