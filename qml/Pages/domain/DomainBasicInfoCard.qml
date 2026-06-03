import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Card {
    id: card

    property var domainData: ({})
    property bool isDomainReadOnly: false
    // 当前用户是否为创建方；安全域是否已停用（已关闭/创建失败）。
    // PRD 3.3：停用安全域时创建方仍可进入编辑态，但"保存"按钮置灰并提示。
    property bool isCreator: false
    property bool isDomainInactive: false
    property bool isEditingDescription: false
    property string editedDescription: ""
    property bool isDescriptionSaving: false
    property string descriptionErrorMessage: ""
    readonly property int descriptionMaxLength: 500

    property string domainCreatorText: ""
    property string payerText: ""

    signal editDescriptionRequested
    signal saveDescriptionRequested(string text)
    signal cancelDescriptionRequested

    property bool _savingFromButton: false
    property string _originalDescription: ""

    Column {
        id: basicInfoColumn
        width: parent.width
        height: implicitHeight
        spacing: 24

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 24
            rowSpacing: 24

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                SelectableText {
                    text: qsTr("Name")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                Text {
                    id: basicInfoNameText
                    width: parent.width
                    text: card.domainData.name || ""
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                    elide: Text.ElideRight

                    ToolTip.visible: truncated && basicInfoNameHover.containsMouse
                    ToolTip.text: card.domainData.name || ""
                    ToolTip.delay: 500

                    HoverHandler {
                        id: basicInfoNameHover
                        enabled: basicInfoNameText.truncated
                    }
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                SelectableText {
                    text: qsTr("Creator Dianshu ID")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    text: card.domainCreatorText
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                SelectableText {
                    text: qsTr("Status")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                Rectangle {
                    width: Math.max(60, statusLabel.implicitWidth + 18)
                    height: 28
                    radius: 8
                    property var domainStatusStyle: Theme.Colors.getStatusColor(card.domainData.status || Theme.Colors.statusNormal)
                    color: domainStatusStyle.bg
                    border.color: domainStatusStyle.border
                    border.width: 1

                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: Theme.Colors.translateStatus(card.domainData.status || "")
                        font.pixelSize: Theme.Typography.body
                        font.weight: Font.Medium
                        color: parent.domainStatusStyle.text
                    }
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                SelectableText {
                    text: qsTr("Creation Time")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    text: Theme.Utils.formatDateTime(card.domainData.createdAt)
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                Row {
                    spacing: 4

                    SelectableText {
                        text: qsTr("Fee Payer")
                        font.pixelSize: Theme.Typography.body
                        color: Theme.Colors.textCaption
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 16
                        height: 16
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2

                        Image {
                            id: payerInfoIcon
                            width: 16
                            height: 16
                            anchors.centerIn: parent
                            source: "qrc:/icons/icon-info-dark.svg"
                            fillMode: Image.PreserveAspectFit
                            visible: true

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: payerTooltip.visible = true
                                onExited: payerTooltip.visible = false
                            }
                        }

                        Rectangle {
                            id: payerTooltip
                            visible: false
                            width: tooltipLabel.implicitWidth + 16
                            height: tooltipLabel.implicitHeight + 10
                            color: Theme.Colors.tooltipBackground
                            radius: 4
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 5
                            z: 100
                            x: -parent.x
                            property real arrowX: Math.max(4, Math.min(parent.x + 8 - 6, width - 16))

                            Canvas {
                                width: 12
                                height: 6
                                anchors.top: parent.bottom
                                x: payerTooltip.arrowX

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = Theme.Colors.tooltipBackground;
                                    ctx.beginPath();
                                    ctx.moveTo(0, 0);
                                    ctx.lineTo(6, 6);
                                    ctx.lineTo(12, 0);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }

                            Text {
                                id: tooltipLabel
                                anchors.centerIn: parent
                                text: qsTr("Who pays the costs incurred after security domain instantiation")
                                font.pixelSize: Theme.Typography.small
                                color: Theme.Colors.primaryText
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                }

                SelectableText {
                    text: card.payerText
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10
                visible: card.domainData.status === Theme.Colors.statusClosed

                SelectableText {
                    text: qsTr("Deactivation Time")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                SelectableText {
                    text: Theme.Utils.formatDateTime(card.domainData.updatedAt)
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Item {
                width: parent.width
                height: 32

                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: qsTr("Description")
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textCaption
                }

                Rectangle {
                    id: editButton
                    anchors.right: parent.right
                    anchors.rightMargin: -15
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    height: 32
                    radius: 8
                    visible: true
                    // 编辑入口：创建方始终可点击；进入编辑态后若安全域已停用，"保存"置灰 (PRD 3.3)
                    readonly property bool saveBlocked: card.isEditingDescription && card.isDomainInactive
                    opacity: (card.isCreator && !saveBlocked) ? 1.0 : 0.5
                    property bool hovered: false
                    property bool pressed: false
                    color: {
                        // 保存被拦截时保持置灰外观，不显示 hover/pressed 高亮 (PRD 3.3)
                        if (editButton.saveBlocked)
                            return "transparent";
                        if (pressed)
                            return "#c1d9ef";
                        if (hovered)
                            return "#eaf2fb";
                        return "transparent";
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                source: "qrc:/icons/icon-edit.svg"
                                fillMode: Image.PreserveAspectFit
                                visible: !card.isEditingDescription
                            }

                            Canvas {
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                visible: card.isEditingDescription

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = Theme.Colors.primary;
                                    ctx.lineWidth = 2;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(3, 8);
                                    ctx.lineTo(6, 11);
                                    ctx.lineTo(13, 4);
                                    ctx.stroke();
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.isEditingDescription ? qsTr("Save") : qsTr("Edit")
                            font.pixelSize: Theme.Typography.h3
                            font.weight: Font.Medium
                            color: Theme.Colors.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // 创建方可点击进入/退出编辑态；保存被拦截时在 onClicked 内提前返回。
                        enabled: card.isCreator && !card.isDescriptionSaving
                        hoverEnabled: true
                        cursorShape: (card.isCreator && !editButton.saveBlocked) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onPressed: {
                            parent.pressed = true;
                            if (card.isEditingDescription)
                                card._savingFromButton = true;
                        }
                        onReleased: {
                            parent.pressed = false;
                            card._savingFromButton = false;
                        }
                        onCanceled: {
                            parent.pressed = false;
                            card._savingFromButton = false;
                        }
                        onClicked: {
                            if (!card.isCreator || card.isDescriptionSaving)
                                return;
                            if (card.isEditingDescription) {
                                // PRD 3.3：安全域已停用时保存不可用，仅展示提示。
                                if (card.isDomainInactive)
                                    return;
                                if ((card.editedDescription || "").length > card.descriptionMaxLength) {
                                    card.descriptionErrorMessage = qsTr("Description cannot exceed 500 characters");
                                    return;
                                }
                                card.descriptionErrorMessage = "";
                                card.saveDescriptionRequested(card.editedDescription);
                            } else {
                                card._originalDescription = card.domainData.description || "";
                                card.editedDescription = card._originalDescription;
                                card.descriptionErrorMessage = "";
                                card.editDescriptionRequested();
                            }
                        }
                    }

                    // 停用安全域时"保存"按钮的悬停提示 (PRD 3.3)
                    HintTooltip {
                        parent: editButton
                        text: qsTr("Security domain is deactivated, this operation is not supported")
                        visible: editButton.saveBlocked && editButton.hovered
                    }
                }
            }

            Rectangle {
                id: descriptionBox
                width: parent.width
                visible: card.isEditingDescription || (card.domainData.description && card.domainData.description.length > 0)
                property int minHeight: 45
                property int padding: 20

                height: {
                    if (card.isEditingDescription) {
                        var textAreaHeight = descriptionTextArea.contentHeight > 0 ? descriptionTextArea.contentHeight : 25;
                        return Math.max(minHeight, textAreaHeight + padding + 4);
                    } else {
                        return Math.max(minHeight, descriptionText.implicitHeight + padding);
                    }
                }
                radius: 8
                color: {
                    if (!card.isEditingDescription)
                        return Theme.Colors.inputBackground;
                    if (descriptionTextArea.activeFocus)
                        return Theme.Colors.backgroundWhite;
                    return descriptionHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite;
                }
                border.color: Theme.Colors.borderField
                border.width: card.isEditingDescription ? 1 : 0
                antialiasing: true
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                SelectableText {
                    id: descriptionText
                    anchors.left: parent.left
                    anchors.leftMargin: 0
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    width: parent.width
                    text: (card.domainData.description && card.domainData.description.length > 0) ? card.domainData.description : ""
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                    wrapMode: TextEdit.Wrap
                    visible: !card.isEditingDescription
                }

                TextArea {
                    id: descriptionTextArea
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.right: parent.right
                    anchors.rightMargin: 17
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    height: contentHeight > 0 ? contentHeight : 25
                    text: card.editedDescription
                    font.pixelSize: Theme.Typography.h3
                    color: Theme.Colors.textHeading
                    selectedTextColor: Theme.Colors.textHeading
                    selectionColor: Theme.Colors.accent
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    // 创建方在停用安全域时仍可编辑描述文本（保存被拦截，PRD 3.3）
                    readOnly: !card.isCreator
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    visible: card.isEditingDescription

                    onTextChanged: {
                        card.editedDescription = text;
                        if ((text || "").length > card.descriptionMaxLength) {
                            card.descriptionErrorMessage = qsTr("Description cannot exceed 500 characters");
                        } else {
                            card.descriptionErrorMessage = "";
                        }
                    }

                    Keys.onEscapePressed: {
                        card.editedDescription = card._originalDescription;
                        card.descriptionErrorMessage = "";
                        card.cancelDescriptionRequested();
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && card.isEditingDescription && !card._savingFromButton) {
                            card.editedDescription = card._originalDescription;
                            card.descriptionErrorMessage = "";
                            card.cancelDescriptionRequested();
                        }
                    }

                    Component.onCompleted: {
                        if (card.isEditingDescription)
                            forceActiveFocus();
                    }
                }

                InputContextMenu {
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.right: parent.right
                    anchors.rightMargin: 17
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    height: descriptionTextArea.contentHeight > 0 ? descriptionTextArea.contentHeight : 25
                    target: descriptionTextArea
                    visible: card.isEditingDescription
                    z: 1
                }

                MouseArea {
                    id: descriptionHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    visible: card.isEditingDescription
                }

                Connections {
                    target: card
                    function onIsEditingDescriptionChanged() {
                        if (card.isEditingDescription) {
                            descriptionTextArea.forceActiveFocus();
                            descriptionTextArea.selectAll();
                        }
                    }
                }
            }

            Row {
                width: parent.width
                visible: card.isEditingDescription

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (card.editedDescription || "").length + "/" + card.descriptionMaxLength
                        font.pixelSize: Theme.Typography.caption
                        color: (card.editedDescription || "").length > card.descriptionMaxLength ? Theme.Colors.textError : "#64748b"
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6
                visible: card.isEditingDescription && card.descriptionErrorMessage !== ""

                Image {
                    width: 16
                    height: 16
                    source: "qrc:/icons/icon-error.svg"
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    antialiasing: true
                }

                Text {
                    text: card.descriptionErrorMessage
                    font.pixelSize: Theme.Typography.body
                    color: Theme.Colors.textError
                }
            }
        }
    }
}
