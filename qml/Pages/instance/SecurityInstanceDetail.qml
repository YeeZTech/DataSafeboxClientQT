import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0
import DataSafebox.Dialogs 1.0
import "DateTimeUtils.js" as DateTimeUtils

Item {
    id: root
    width: 778
    height: 1000

    // Instance name property - should be set from parent
    property string instanceName: ""
    // Current user - should be set from parent
    property var currentUser: null

    // Instance data - will be loaded from DataManager or use static data
    property var instanceData: _emptyInstanceData()
    readonly property bool isInstanceActive: instanceData && instanceData.status !== "已关闭"
    // Only "运行中" instances can import/export files
    readonly property bool canImportExportFiles: instanceData && instanceData.status === "运行中"
    // "已授权" 实例用于显示"实例化此安全域"按钮
    readonly property bool isAuthorizedInstance: instanceData && instanceData.status === "已授权"
    readonly property bool isPendingInstance: instanceData && instanceData.status === "待审核"
    readonly property bool showManagementPanels: !(isPendingInstance || isAuthorizedInstance)

    // Signals
    signal backRequested
    signal importFileRequested
    signal exportFileRequested(var filePaths, string reasonText)
    signal deleteRequested
    signal instantiateRequested(string durationText)

    // Check expiration when component loads or becomes visible
    Component.onCompleted: {
        checkAndUpdateExpiration();
    }

    onVisibleChanged: {
        if (visible) {
            checkAndUpdateExpiration();
        }
    }

    function _emptyInstanceData() {
        return {
            id: "",
            name: instanceName || "",
            status: "",
            creator: "",
            path: "",
            createdAt: "",
            duration: ""
        };
    }

    function formatDurationLabel(durationText) {
        if (durationText === undefined || durationText === null)
            return "-";
        var text = durationText.toString().trim();
        if (!text.length)
            return "-";
        return text.indexOf(qsTr(" months")) !== -1 ? text : text + qsTr(" months");
    }

    function displayExpiredTime(instance) {
        if (!instance)
            return "-";
        var status = instance.status || "";
        if (status === "待审核" || status === "已拒绝")
            return "-";
        // 后端下发的绝对到期时间优先于按 createdAt + duration 的推算
        if (instance.expireAt !== undefined)
            return Theme.Utils.formatExpiry(instance.expireAt);
        var expiryDate = DateTimeUtils.resolveExpiryDate(instance);
        if (!expiryDate)
            return "-";
        return Theme.Utils.formatDateTime(expiryDate);
    }

    // Check if instance has expired and update status if needed
    function checkAndUpdateExpiration() {
        var instance = root.instanceData;
        if (!instance || !instance.id)
            return;
        if (instance.status !== "运行中")
            return;
        if (!instance.createdAt && !instance.expiresAt)
            return;
        var expiryDate = DateTimeUtils.resolveExpiryDate(instance);
        if (!expiryDate)
            return;
        if (new Date() > expiryDate)
            root.instanceData = _emptyInstanceData();
    }

    function applyPaymentSuccess(durationText) {
        var currentInstance = root.instanceData;
        if (!currentInstance || !currentInstance.id) {
            return;
        }
        root.instanceData = root._emptyInstanceData();
    }

    // Update instanceData when instanceName changes
    onInstanceNameChanged: {
        instanceData = _emptyInstanceData();
    }

    // 根据实例大小（MB）、实例时长（月）和计费规则（如"30元/GB/月"）计算预计费用
    function calculateEstimatedFee(sizeValue, durationText, billingRule) {
        // 解析月份
        var months = 0;
        if (durationText && typeof durationText === "string") {
            var m = durationText.match(/(\d+)/);
            if (m) {
                months = parseInt(m[1]);
            }
        } else if (durationText) {
            months = parseInt(durationText);
        }
        if (!months || months <= 0)
            return "0.00";

        // 解析容量（以 MB 为单位）
        var sizeMB = 0;
        if (!sizeValue && sizeValue !== 0) {
            return "0.00";
        }
        if (typeof sizeValue === "string") {
            var match = sizeValue.match(/^(\d+)/);
            if (match) {
                sizeMB = parseInt(match[1]);
            } else {
                return "0.00";
            }
        } else {
            sizeMB = parseInt(sizeValue);
        }
        if (isNaN(sizeMB) || sizeMB <= 0)
            return "0.00";

        // 转成 GB
        var sizeGB = sizeMB / 1024.0;

        // 从计费规则字符串中提取单价（元/GB/月）
        var pricePerGBPerMonth = 0;
        if (billingRule && typeof billingRule === "string") {
            var pm = billingRule.match(/(\d+(\.\d+)?)/);
            if (pm) {
                pricePerGBPerMonth = parseFloat(pm[1]);
            }
        }
        if (!pricePerGBPerMonth || pricePerGBPerMonth <= 0)
            return "0.00";
        var fee = sizeGB * months * pricePerGBPerMonth;
        if (!isFinite(fee) || fee < 0)
            return "0.00";
        return fee.toFixed(2);
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentArea.height + 64

        background: Rectangle {
            color: "#e8edf3"
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Item {
            id: contentArea
            width: 778
            height: 970

            // Header section with title and import button
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.top: parent.top
                anchors.topMargin: 32
                width: 778
                height: 36

                // Title
                SelectableText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: instanceData.name || qsTr("Security Domain Instance")

                    // Import File Button（仅运行中实例显示）
                    PrimaryButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.canImportExportFiles
                        text: qsTr("Import File")
                        onClicked: root.importFileRequested()
                    }

                    // 实例化此安全域 按钮（仅已授权实例显示，使用蓝色背景、白色文字和图标）
                    PrimaryButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.isAuthorizedInstance
                        text: qsTr("Encrypt File to This Security Domain")
                        onClicked: {
                            var durationText = instanceData.duration ? instanceData.duration.toString() : "1";
                            instantiationPaymentDialog.durationText = durationText;
                            var rawSize = instanceData.volumnSize || instanceData.size;
                            var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(rawSize);
                            instantiationPaymentDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes);
                            instantiationPaymentDialog.instanceFee = (durationText && durationText.length > 0 ? (durationText + qsTr(" months")) : "-");
                            instantiationPaymentDialog.billingRule = qsTr("30 CNY/GB/Month");
                            instantiationPaymentDialog.estimatedFee = calculateEstimatedFee(rawSize, durationText, instantiationPaymentDialog.billingRule);
                            instantiationPaymentDialog.open();
                        }
                    }
                }

                InstanceInfoCard {
                    id: basicInfoCard
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.top: parent.top
                    anchors.topMargin: 92
                    width: 778
                    instanceData: root.instanceData
                    expiryText: displayExpiredTime(root.instanceData)
                }

                // Authorized Instance Notification Card
                Rectangle {
                    id: authorizedNotificationCard
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.top: basicInfoCard.bottom
                    anchors.topMargin: 25
                    width: 778
                    height: isAuthorizedInstance ? 73 : 0
                    visible: root.isAuthorizedInstance
                    color: "#E6F7FF"
                    border.color: "#BEDBFF"
                    border.width: 1
                    radius: 14

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 25
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            source: "qrc:/icons/icon-info.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        SelectableText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Application approved. Click \"Start Domain\" to proceed.")
                            font.pixelSize: Theme.Typography.h3
                            font.weight: Font.Normal
                            color: Theme.Colors.textLabel
                            wrapMode: Text.WordWrap
                            width: 574
                        }
                    }
                }

                InstanceWhitelistCard {
                    id: whitelistCard
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.top: root.isAuthorizedInstance ? authorizedNotificationCard.bottom : basicInfoCard.bottom
                    anchors.topMargin: root.showManagementPanels ? 25 : 0
                    width: 778
                    visible: root.showManagementPanels
                    processWhitelist: root.instanceData.processWhitelist || []
                }

                InstanceExportCard {
                    id: exportApplicationCard
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.top: whitelistCard.bottom
                    anchors.topMargin: root.showManagementPanels ? 25 : 0
                    width: 778
                    visible: root.showManagementPanels
                    exportRequests: root.instanceData.exportRequests || []
                    canImportExportFiles: root.canImportExportFiles

                    onExportFileClicked: {
                        var exportBasePath = root.instanceData && root.instanceData.diskPartition ? root.instanceData.diskPartition : "";
                        exportFileDialog.allowedDirectory = exportBasePath;
                        exportFileDialog.resetForm();
                        exportFileDialog.open();
                    }

                    onViewExportClicked: function (rowData) {
                        exportDetailDialog.exportId = rowData.applyCode || "";
                        exportDetailDialog.applicant = rowData.applicantUserName || rowData.applicant || root.instanceData.creatorUserName || root.instanceData.creator || "-";
                        exportDetailDialog.fileSize = Number(rowData.fileSize) || 0;
                        exportDetailDialog.status = rowData.status || "待审核";
                        exportDetailDialog.applyTime = rowData.applyTime || "";
                        exportDetailDialog.instanceName = root.instanceData.name || "";
                        exportDetailDialog.files = rowData.files || [];
                        exportDetailDialog.reason = rowData.reason || "";
                        exportDetailDialog.fileCode = rowData.fileCode || "";
                        exportDetailDialog.fileHash = rowData.fileHash || "";
                        exportDetailDialog.open();
                    }
                }

                // Delete Button
                PrimaryButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: exportApplicationCard.bottom
                    anchors.topMargin: (root.isInstanceActive && root.showManagementPanels) ? 25 : 0
                    visible: root.isInstanceActive && root.showManagementPanels
                    text: qsTr("Delete Instance")
                    onClicked: {
                        deleteInstanceConfirmDialog.domainName = root.instanceData && root.instanceData.name ? root.instanceData.name : root.instanceName;
                        deleteInstanceConfirmDialog.open();
                    }
                }
            }
        }

        // 运行时长设置弹窗
        SetDurationDialog {
            id: setDurationDialog

            onConfirmClicked: function (durationText) {
                instantiationPaymentDialog.durationText = durationText;
                var rawSize = instanceData.volumnSize || instanceData.size;
                var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(rawSize);
                instantiationPaymentDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes);
                instantiationPaymentDialog.instanceFee = (durationText && durationText.length > 0 ? (durationText + qsTr(" months")) : "-");
                instantiationPaymentDialog.billingRule = qsTr("30 CNY/GB/Month");
                instantiationPaymentDialog.estimatedFee = calculateEstimatedFee(rawSize, durationText, instantiationPaymentDialog.billingRule);
                instantiationPaymentDialog.open();
            }

            onCancelClicked: {}
        }

        // 实例化付款确认弹窗
        InstantiationPaymentDialog {
            id: instantiationPaymentDialog

            onConfirmClicked: function (durationText) {
                instantiationPaymentDialog.close();
                paymentSuccessDialog.open();
                root.instantiateRequested(durationText);
            }

            onCancelClicked: {}
        }

        // 支付成功弹窗
        PaymentSuccessDialog {
            id: paymentSuccessDialog

            onConfirmClicked: {
                var instanceName = root.instanceData && root.instanceData.name ? root.instanceData.name : root.instanceName;
                var msg = "支付成功确认: 实例=" + instanceName + ", 时长=" + (instantiationPaymentDialog.durationText || "-");
                SentryBridge.captureMessage(msg, 0);
                root.applyPaymentSuccess(instantiationPaymentDialog.durationText);
                instantiationPaymentDialog.durationText = "";
            }

            onCancelClicked: {}
        }

        // 删除实例确认弹窗（复用关闭安全域弹窗）
        DeactivateConfirmDialog {
            id: deleteInstanceConfirmDialog
            titleText: qsTr("Confirm Delete Instance")
            questionTemplate: qsTr("Are you sure you want to delete the instance \"%1\" ?")
            confirmButtonText: qsTr("Confirm Delete")
            showDescription: false
            onConfirmClicked: {
                root.deleteRequested();
            }
        }

        // 导出文件弹窗
        ExportFileDialog {
            id: exportFileDialog

            onConfirmClicked: function (filePaths, reasonText) {
                root.exportFileRequested(filePaths, reasonText);
            }
        }

        // 导出文件详情弹窗
        ExportDetailDialog {
            id: exportDetailDialog
            isCreator: root.currentUser && root.instanceData && root.currentUser.userName === root.instanceData.creator
            allowApproveReject: false

            onApproveClicked: {}

            onRejectClicked: {}

            onCancelClicked: {}
        }
    }
}
