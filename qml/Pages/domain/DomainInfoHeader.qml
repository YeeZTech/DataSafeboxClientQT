import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Item {
    id: root
    width: parent.width
    height: 32

    property string domainName: ""
    // 当前用户是否为安全域创建方。非创建方（使用方）下两个操作按钮仍可点击，但行为不同。
    property bool isCreator: true
    // 安全域是否处于已关闭/创建失败等停用状态。
    property bool isDomainInactive: false
    property bool encryptButtonBusy: false
    property string domainPubKey: ""

    property alias encryptFileButton: encryptFileButton
    property alias createInstanceButton: createInstanceButton

    signal instantiateRequested
    signal encryptRequested
    // 使用方点击"加密文件"按钮时触发，用于弹出提示弹窗 (PRD 3.6)。
    signal encryptUserHintRequested
    signal guideRequested
    signal errorOccurred(string message, string title)

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            id: headerTitleText
            // Flexible title: shrinks as the action buttons grow, but never below a
            // readable floor (longer EN labels no longer crush it to zero).
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            Layout.rightMargin: 48
            Layout.alignment: Qt.AlignVCenter
            text: root.domainName
            font.pixelSize: Theme.Typography.h1
            font.weight: Font.Medium
            color: Theme.Colors.textHeading
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter

            ToolTip.visible: truncated && headerTitleHover.containsMouse
            ToolTip.text: root.domainName
            ToolTip.delay: 500

            HoverHandler {
                id: headerTitleHover
                enabled: headerTitleText.truncated
            }
        }

        // Buttons stay in a plain Row (sizes to content, keeps the 36px button
        // height) and the Row is the layout-managed item on the right.
        Row {
            id: headerButtonRow
            Layout.alignment: Qt.AlignVCenter
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
                // 创建方与使用方均可点击；所有状态（含已关闭/创建失败）下均可点击，行为一致。
                primaryOutline: true
                text: qsTr("How to Instantiate?")
                onClicked: root.instantiateRequested()
            }

            PrimaryButton {
                id: encryptFileButton
                // 使用方始终可点击（点击仅弹出提示）；创建方仅在加密进行中禁用。
                // 停用安全域时创建方仍可打开加密弹窗，弹窗内"加密文件"按钮置灰 (PRD 3.3)。
                readonly property bool disabled: root.isCreator && root.encryptButtonBusy
                visible: true
                enabled: !disabled
                iconSource: "qrc:/icons/icon-encrypt-to-domain.svg"
                text: qsTr("Encrypt Files")
                onClicked: {
                    if (!root.isCreator) {
                        // 使用方：弹出"加密操作仅由创建方执行"的提示弹窗 (PRD 3.6)。
                        root.encryptUserHintRequested();
                        return;
                    }
                    if (!root.domainPubKey) {
                        root.errorOccurred(qsTr("Security domain public key not found"), qsTr("Encrypt File"));
                        return;
                    }
                    root.encryptRequested();
                }
            }
        }
    }
}
