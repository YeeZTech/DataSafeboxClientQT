import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Item {
    id: root
    width: parent.width
    height: 32

    property string domainName: ""
    property bool isDomainReadOnly: false
    property bool encryptButtonBusy: false
    property string domainPubKey: ""

    property alias encryptFileButton: encryptFileButton
    property alias createInstanceButton: createInstanceButton

    signal instantiateRequested
    signal encryptRequested
    signal guideRequested
    signal errorOccurred(string message, string title)

    Text {
        id: headerTitleText
        anchors.left: parent.left
        anchors.right: headerButtonRow.left
        anchors.rightMargin: 48
        anchors.verticalCenter: parent.verticalCenter
        text: root.domainName
        font.pixelSize: Theme.Typography.h1
        font.weight: Font.Medium
        color: Theme.Colors.textHeading
        elide: Text.ElideRight

        ToolTip.visible: truncated && headerTitleHover.containsMouse
        ToolTip.text: root.domainName
        ToolTip.delay: 500

        HoverHandler {
            id: headerTitleHover
            enabled: headerTitleText.truncated
        }
    }

    Row {
        id: headerButtonRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        LinkText {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("View Feature Guide")
            fontSize: Theme.Typography.body
            onClicked: root.guideRequested()
        }

        SecondaryButton {
            id: createInstanceButton
            visible: true
            enabled: !root.isDomainReadOnly
            text: qsTr("How to Instantiate Security Domain?")
            onClicked: {
                if (root.isDomainReadOnly)
                    return;
                root.instantiateRequested();
            }
        }

        PrimaryButton {
            id: encryptFileButton
            readonly property bool disabled: root.isDomainReadOnly || root.encryptButtonBusy
            visible: true
            enabled: !disabled
            iconSource: "qrc:/icons/icon-encrypt-to-domain.svg"
            text: qsTr("Encrypt Files to This Security Domain")
            onClicked: {
                if (!root.domainPubKey) {
                    root.errorOccurred(qsTr("Security domain public key not found"), qsTr("Encrypt File"));
                    return;
                }
                root.encryptRequested();
            }
        }
    }
}
