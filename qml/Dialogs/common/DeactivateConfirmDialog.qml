import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

BaseDialog {
    id: root
    dialogWidth: 500
    title: titleText
    onCloseRequested: cancelClicked()

    property string domainName: ""
    property string titleText: qsTr("Confirm Deactivate Security Domain")
    property string questionPrefix: qsTr("Are you sure you want to deactivate security domain")
    property string questionSuffix: qsTr("?")
    property string descriptionText: qsTr("After deactivation this domain becomes read-only. Existing instances are not affected.")
    property bool showDescription: true
    property string confirmButtonText: qsTr("Confirm Deactivate")
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
            color: "#fefce8"
            border.color: "#f59e0b"  // amber-500 for better visibility
            border.width: 1.5
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
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                spacing: 12  // Space between icon and text
                Image {
                    id: warningIcon
                    width: 20
                    height: 20
                    source: "qrc:/icons/icon-warning.svg"
                    sourceSize: Qt.size(20, 20)
                }

                // Warning text content
                Column {
                    id: warningTexts
                    width: warningContent.width - warningIcon.width - warningContent.spacing
                    spacing: 8

                    // Main question text
                    SelectableText {
                        width: parent.width
                        wrapMode: TextEdit.Wrap
                        text: root.questionPrefix + " \"" + root.domainName + "\" " + root.questionSuffix
                        font.pixelSize: Theme.Typography.h3
                        color: Theme.Colors.textLabel
                    }

                    // Description text
                    SelectableText {
                        width: parent.width
                        wrapMode: TextEdit.Wrap
                        text: root.descriptionText
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                        visible: root.showDescription && root.descriptionText && root.descriptionText.length > 0
                        height: visible ? implicitHeight : 0
                    }
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
            spacing: 16
            height: 36
            SecondaryButton {
                text: qsTr("Cancel")
                onClicked: {
                    root.close();
                    root.cancelClicked();
                }
            }
            DangerButton {
                text: root.confirmButtonText
                onClicked: {
                    root.confirmClicked();
                    root.close();
                }
            }
        }
    }
}
