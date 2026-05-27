import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Rectangle {
    id: card

    property var domainData: ({})
    property bool isDomainReadOnly: false
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

    width: parent ? parent.width : 200
    height: 48 + basicInfoColumn.implicitHeight
    radius: 14
    color: Theme.Colors.backgroundWhite
    antialiasing: true

    property bool _savingFromButton: false
    property string _originalDescription: ""

    Column {
        id: basicInfoColumn
        anchors.fill: parent
        anchors.margins: 24
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
                    font.pixelSize: 14
                    color: "#62748e"
                }

                Text {
                    id: basicInfoNameText
                    width: parent.width
                    text: card.domainData.name || ""
                    font.pixelSize: 16
                    color: "#0f172b"
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
                    text: qsTr("Creator")
                    font.pixelSize: 14
                    color: "#62748e"
                }

                SelectableText {
                    text: card.domainCreatorText
                    font.pixelSize: 16
                    color: "#0f172b"
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                SelectableText {
                    text: qsTr("Status")
                    font.pixelSize: 14
                    color: "#62748e"
                }

                Rectangle {
                    width: {
                        var statusText = card.domainData.status || "";
                        return Math.max(60, statusText.length * 14 + 18);
                    }
                    height: 28
                    radius: 8
                    property var domainStatusStyle: Theme.Colors.getStatusColor(card.domainData.status || Theme.Colors.statusNormal)
                    color: domainStatusStyle.bg
                    border.color: domainStatusStyle.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.Colors.translateStatus(card.domainData.status || "")
                        font.pixelSize: 16
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
                    font.pixelSize: 14
                    color: "#62748e"
                }

                SelectableText {
                    text: Theme.Utils.formatDateTime(card.domainData.createdAt)
                    font.pixelSize: 16
                    color: "#0f172b"
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 10

                Row {
                    spacing: 4

                    SelectableText {
                        text: qsTr("Fee Payer")
                        font.pixelSize: 14
                        color: "#62748e"
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
                            color: "#1e5a8e"
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
                                    ctx.fillStyle = "#1e5a8e";
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
                                font.pixelSize: 12
                                color: "#ffffff"
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                }

                SelectableText {
                    text: card.payerText
                    font.pixelSize: 16
                    color: "#0f172b"
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
                    font.pixelSize: 14
                    color: "#62748e"
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -15
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    height: 32
                    radius: 8
                    visible: true
                    opacity: !card.isDomainReadOnly ? 1.0 : 0.5
                    property bool hovered: false
                    property bool pressed: false
                    color: {
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
                                source: Qt.resolvedUrl("icons/icon-edit.svg")
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
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: Theme.Colors.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !card.isDomainReadOnly && !card.isDescriptionSaving
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
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
                            if (card.isDomainReadOnly || card.isDescriptionSaving)
                                return;
                            if (card.isEditingDescription) {
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
                border.color: "#cad5e2"
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
                    font.pixelSize: 14
                    color: "#0f172b"
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
                    font.pixelSize: 14
                    color: "#0f172b"
                    selectedTextColor: "#0f172b"
                    selectionColor: "#d4e4f1"
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    readOnly: card.isDomainReadOnly
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
                        font.pixelSize: 13
                        color: (card.editedDescription || "").length > card.descriptionMaxLength ? "#e7000b" : "#64748b"
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
                    source: "icons/icon-error.svg"
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    antialiasing: true
                }

                Text {
                    text: card.descriptionErrorMessage
                    font.pixelSize: 14
                    color: "#e7000b"
                }
            }
        }
    }
}
