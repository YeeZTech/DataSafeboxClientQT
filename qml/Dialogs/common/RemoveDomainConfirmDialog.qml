import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 446
    title: qsTr("Remove This Security Domain?")
    onCloseRequested: cancelClicked()

    signal confirmClicked
    signal cancelClicked

    Column {
        id: contentColumn
        width: parent.width
        spacing: 0

        // Warning message area
        Rectangle {
            width: parent.width
            radius: 10
            color: "#fffbeb"
            border.color: "#fee685"
            border.width: 1
            implicitHeight: warningContent.implicitHeight + warningContent.anchors.topMargin + warningContent.anchors.bottomMargin
            height: implicitHeight

            Row {
                id: warningContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 12  // Space between icon and text

                Image {
                    id: warningIcon
                    width: 20
                    height: 20
                    source: "qrc:/icons/icon-warning.svg"
                    sourceSize: Qt.size(20, 20)
                }

                SelectableText {
                    width: warningContent.width - warningIcon.width - warningContent.spacing
                    wrapMode: TextEdit.Wrap
                    text: qsTr("After removal, this security domain will disappear from the list. This operation cannot be undone.")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }
            }
        }

        // Spacing between warning box and buttons
        Item {
            width: parent.width
            height: 28
        }

        // Footer buttons
        Row {
            anchors.right: parent.right
            spacing: 8
            height: 36
            SecondaryButton {
                text: qsTr("Cancel")
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }
            DangerButton {
                text: qsTr("Confirm")
                onClicked: {
                    root.confirmClicked();
                    root.close();
                }
            }
        }
    }
}
