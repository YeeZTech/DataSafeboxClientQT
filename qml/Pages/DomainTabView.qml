import QtQuick 2.15
import QtQuick.Controls 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0

Column {
    id: root
    spacing: 16

    property var domainData: ({})
    property bool isDomainReadOnly: false
    property var currentUser: null

    property bool isEditingDescription: false
    property string editedDescription: ""
    property bool isDescriptionSaving: false
    property string descriptionErrorMessage: ""
    property string domainCreatorText: ""
    property string payerText: ""

    property bool operationBusy: false
    property string pendingRemovedAccount: ""
    property int actionRightMargin: 6
    property int actionTextPixelSize: 14
    property int actionTextWeight: Font.Medium

    property alias visibleUsersCard: visibleUsersCard
    property alias relatedInstancesCard: relatedInstancesCard
    property alias appWhitelistAuditCard: appWhitelistAuditCard
    property alias exportAuditCard: exportAuditCard

    signal editDescriptionRequested
    signal saveDescriptionRequested(string text)
    signal cancelDescriptionRequested
    signal editedDescriptionUpdated(string text)
    signal descriptionErrorMessageUpdated(string text)
    signal addUserRequested
    signal removeUserRequested(string account, string authUserId)
    signal viewInstanceRequested(var instanceData, bool isApprover)
    signal viewWhitelistAuditRequested(var auditData)
    signal viewExportRequested(var auditData)
    signal deactivateRequested

    DomainBasicInfoCard {
        id: basicInfoCard
        width: parent.width
        domainData: root.domainData
        isDomainReadOnly: root.isDomainReadOnly
        isEditingDescription: root.isEditingDescription
        editedDescription: root.editedDescription
        isDescriptionSaving: root.isDescriptionSaving
        descriptionErrorMessage: root.descriptionErrorMessage
        domainCreatorText: root.domainCreatorText
        payerText: root.payerText

        onEditedDescriptionChanged: root.editedDescriptionUpdated(basicInfoCard.editedDescription)
        onDescriptionErrorMessageChanged: root.descriptionErrorMessageUpdated(basicInfoCard.descriptionErrorMessage)
        onEditDescriptionRequested: root.editDescriptionRequested()
        onSaveDescriptionRequested: function (text) {
            root.saveDescriptionRequested(text);
        }
        onCancelDescriptionRequested: root.cancelDescriptionRequested()
    }

    DomainVisibleUsersCard {
        id: visibleUsersCard
        width: parent.width
        visibleUsers: root.domainData.visibleUsers || []
        isDomainReadOnly: root.isDomainReadOnly
        operationBusy: root.operationBusy
        pendingRemovedAccount: root.pendingRemovedAccount
        actionRightMargin: root.actionRightMargin
        actionTextPixelSize: root.actionTextPixelSize
        actionTextWeight: root.actionTextWeight

        onAddUserRequested: root.addUserRequested()
        onRemoveUserRequested: function (account, authUserId) {
            root.removeUserRequested(account, authUserId);
        }
    }

    DomainInstancesCard {
        id: relatedInstancesCard
        width: parent.width
        instances: root.domainData.instances || []
        visibleUsers: root.domainData.visibleUsers || []
        currentUser: root.currentUser
        domainData: root.domainData
        isDomainReadOnly: root.isDomainReadOnly
        actionRightMargin: root.actionRightMargin
        actionTextPixelSize: root.actionTextPixelSize
        actionTextWeight: root.actionTextWeight

        onViewInstanceRequested: function (instanceData, isApprover) {
            root.viewInstanceRequested(instanceData, isApprover);
        }
    }

    DomainWhitelistAuditCard {
        id: appWhitelistAuditCard
        width: parent.width
        audits: root.domainData.appWhitelistAudits || []
        actionRightMargin: root.actionRightMargin
        actionTextPixelSize: root.actionTextPixelSize
        actionTextWeight: root.actionTextWeight

        onViewAuditRequested: function (auditData) {
            root.viewWhitelistAuditRequested(auditData);
        }
    }

    DomainExportAuditCard {
        id: exportAuditCard
        width: parent.width
        audits: root.domainData.exportAudits || []
        actionRightMargin: root.actionRightMargin
        actionTextPixelSize: root.actionTextPixelSize
        actionTextWeight: root.actionTextWeight

        onViewExportRequested: function (auditData) {
            root.viewExportRequested(auditData);
        }
    }

    Rectangle {
        id: disableBtn
        height: 38
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 8
        property bool hovered: false
        property bool pressed: false
        color: pressed ? "#ffd5d5" : (hovered ? "#fff5f5" : "#ffffff")
        border.width: 1
        border.color: pressed ? "#ff5050" : (hovered ? "#ff9090" : "#ffa2a2")
        visible: !root.isDomainReadOnly
        implicitWidth: disableText.implicitWidth + 40

        Text {
            id: disableText
            anchors.centerIn: parent
            text: qsTr("Disable This Security Domain")
            font.pixelSize: 14
            font.weight: Font.Medium
            color: parent.pressed ? "#900006" : (parent.hovered ? "#c50009" : Theme.Colors.textError)
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.isDomainReadOnly
            hoverEnabled: true
            cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: root.deactivateRequested()
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onPressed: parent.pressed = true
            onReleased: parent.pressed = false
        }
    }
}
