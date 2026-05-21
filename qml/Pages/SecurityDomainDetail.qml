import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as Theme

Item {
    id: root
    width: 992
    height: 801
    
    // Domain identification properties - set from parent
    property string domainPubKey: ""
    property string domainName: ""
    
    // Cached domainCode from current domain detail
    property string currentDomainCode: ""
    
    // Current user - set from parent (Main.qml)
    property var currentUser: null

    // Pending state for removing visible user (kept on root for delegate scope access)
    property string removeUserState_pendingRemovedAccount: ""
    property string removeUserState_pendingRemovedAuthUserId: ""
    property string removeUserState_pendingDomainPubKey: ""
    property string removeUserState_pendingDomainCode: ""
    // visibleUserOperationState promoted to root for delegate scope access
    property bool   visibleUserOperationState_busy: false

    // Pending state for adding visible user
    property var    pendingAddUserFullInfo: null

    // Pending state for instance audit
    property bool   instanceAuditPending: false

    // Pending state for audit request (app whitelist / export)
    property bool   auditRequestPending: false

    // Description saving state
    property bool   isDescriptionSaving: false

    function trimText(value) {
        if (value === undefined || value === null) return ""
        return ("" + value).trim()
    }

    function domainCreatorDisplayText(detail) {
        var d = detail || root.domainData || {}
        return trimText(d.creatorUserName)
            || trimText(d.creator)
            || trimText(d.creatorUserId || d.authUserId || d.userId)
    }

    function isCurrentUserDomainCreator(detail) {
        if (!currentUser || !detail) return false

        var userKeys = [
            trimText(currentUser.userName),
            trimText(currentUser.authUserId)
        ]
        var creatorKeys = [
            trimText(detail.creatorUserId),
            trimText(detail.authUserId),
            trimText(detail.userId),
            trimText(detail.creatorUserName),
            trimText(detail.creator)
        ]

        for (var i = 0; i < userKeys.length; i++) {
            if (!userKeys[i]) continue
            for (var j = 0; j < creatorKeys.length; j++) {
                if (creatorKeys[j] && userKeys[i] === creatorKeys[j]) {
                    return true
                }
            }
        }
        return false
    }

    function isDomainInactiveStatus(statusText) {
        var s = (statusText || "").trim()
        return s === "已关闭" || s === "创建失败" || s === "停用" || s === "已停用" || s === "停用中"
    }
    
    // Check if current user is the creator of this domain
    property bool isCreator: {
        if (!currentUser || !domainData) return false
        return isCurrentUserDomainCreator(domainData)
    }
    property bool isDomainInactive: {
        if (root.domainData && root.domainData.isInactive !== undefined) {
            return !!root.domainData.isInactive || isDomainInactiveStatus(root.domainData.status)
        }
        return isDomainInactiveStatus(root.domainData ? root.domainData.status : "")
    }
    property bool isDomainReadOnly: root.isDomainInactive || (!root.isCreator)
    
    // Domain data - loaded from DataManager or provided by parent
    property int dataVersion: 0
    property bool domainDetailLoading: false
    // 初始化为空对象，后续由 *Loaded 信号 / reloadAllData 显式赋值
    // 不要在 binding 中调用读取 root.domainData 的函数，否则形成自引用 binding loop
    property var domainData: emptyDomainDetail()
    
    // Signals
    signal instantiateRequested()

    property bool _pendingGuideShow: false
    property int _guideShowRetryCount: 0

    /** 从外部触发功能引导弹窗显示（安全域创建成功后调用） */
    function showGuide() {
        _pendingGuideShow = true
        _guideShowRetryCount = 0
        guideShowTimer.restart()
    }
    
    // Description editing state
    property bool isEditingDescription: false
    property string editedDescription: ""
    property string _originalDescription: ""
    property bool _savingFromButton: false
    readonly property int descriptionMaxLength: 500
    property string descriptionErrorMessage: ""
    // Shared right alignment baseline for 添加/操作/查看/移除
    readonly property int actionRightMargin: 6
    readonly property int actionTextPixelSize: 14
    readonly property int actionTextWeight: Font.Medium
    property bool auditDataLoaded: false

    function resetAuditDataLoading() {
        auditDataLoaded = false
    }

    function canShowGuideNow() {
        return root.visible
            && root.width > 0
            && root.height > 0
            && encryptFileButton.width > 0
            && encryptFileButton.height > 0
            && onboardingGuide.steps.length > 0
    }

    Timer {
        id: guideShowTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (!root._pendingGuideShow) {
                stop()
                return
            }
            root._guideShowRetryCount++
            if (root.canShowGuideNow()) {
                root._pendingGuideShow = false
                stop()
                onboardingGuide.show()
                return
            }
            if (root._guideShowRetryCount >= 30) {
                root._pendingGuideShow = false
                stop()
            }
        }
    }

    function canRenderAuditEmptyState(detail) {
        var d = detail || root.domainData
        if (!d) {
            return false
        }
        if (d._syncedFromBackend) {
            return true
        }
        // If backend returned audit arrays (even empty), we can render empty state
        if (Array.isArray(d.appWhitelistAudits) || Array.isArray(d.exportAudits)) {
            return true
        }
        var hasWhitelist = !!(d.appWhitelistAudits && d.appWhitelistAudits.length > 0)
        var hasExport = !!(d.exportAudits && d.exportAudits.length > 0)
        return hasWhitelist || hasExport
    }
    
    // Function to get domain data (called when domainName changes)
    function emptyDomainDetail() {
        return {
            name: domainName || "",
            creator: "",
            status: "",
            createdAt: "",
            payer: "",
            description: "",
            visibleUsers: [],
            instances: [],
            appWhitelistAudits: [],
            exportAudits: [],
            pubKey: domainPubKey || "",
            isInactive: false
        }
    }

    function toSortableTime(value) {
        var text = (value || "").toString().trim()
        if (!text.length) {
            return 0
        }
        if (/([+-]\d{2}):$/.test(text)) {
            text += "00"
        }
        var normalized = text.indexOf("T") === -1 ? text.replace(" ", "T") : text
        var date = new Date(normalized)
        if (!isNaN(date.getTime())) {
            return date.getTime()
        }
        var fallback = text.match(/^(\d{4})-(\d{2})-(\d{2})[T\s]?(\d{2})?:?(\d{2})?:?(\d{2})?/) 
        if (!fallback) {
            return 0
        }
        return Date.UTC(
            parseInt(fallback[1], 10),
            parseInt(fallback[2], 10) - 1,
            parseInt(fallback[3], 10),
            parseInt(fallback[4] || "0", 10),
            parseInt(fallback[5] || "0", 10),
            parseInt(fallback[6] || "0", 10)
        )
    }

    function normalizeInstanceId(value) {
        if (!value && value !== 0) {
            return ""
        }
        var normalized = ("" + value).trim()
        if (!normalized) {
            return ""
        }
        if (normalized[0] !== "I") {
            normalized = "I" + normalized
        }
        return normalized
    }

    function toJsArray(value) {
        if (!value) {
            return []
        }
        if (Array.isArray(value)) {
            return value.slice()
        }
        if (typeof value === "string" || typeof value !== "object") {
            return []
        }

        var length = Number(value.length)
        if (isNaN(length) || length < 0) {
            return []
        }

        var result = []
        for (var i = 0; i < length; i++) {
            result.push(value[i])
        }
        return result
    }

    function normalizeInstanceStatus(statusValue) {
        if (statusValue === undefined || statusValue === null) {
            return ""
        }

        var statusText = ("" + statusValue).trim()
        if (!statusText) {
            return ""
        }

        if (statusText === "0") return "待审核"
        if (statusText === "1") return "已授权"
        if (statusText === "2") return "已拒绝"
        if (statusText === "3") return "运行中"
        if (statusText === "4") return "已结束"
        return statusText
    }

    function normalizeInstance(rawInstance) {
        var raw = rawInstance || {}
        var instanceId = raw.id || raw.instanceCode || raw.instance_code || ""
        var instanceName = raw.name || raw.instanceName || raw.instance_name || ""
        var creatorUserId = raw.creatorUserId || raw.authUserId || raw.creator || raw.userId || ""
        var creatorUserName = raw.creatorUserName || raw.creatorName || raw.authUserName || ""
        var statusValue = raw.status !== undefined ? raw.status : raw.instanceStatus
        var volumeSize = raw.size !== undefined ? raw.size : raw.volumnSize

        var normalized = Object.assign({}, raw)
        normalized.id = instanceId
        normalized.instanceCode = raw.instanceCode || instanceId
        normalized.name = instanceName
        normalized.instanceName = raw.instanceName || instanceName
        normalized.status = normalizeInstanceStatus(statusValue)
        normalized.size = volumeSize
        normalized.creatorUserId = creatorUserId
        normalized.creatorUserName = creatorUserName
        normalized.authUserId = raw.authUserId || ""
        normalized.applicantAccount = raw.applicantAccount || creatorUserName || raw.account || raw.authUserName || ""
        normalized.user = raw.user || creatorUserName || normalized.applicantAccount || creatorUserId
        normalized.duration = raw.duration !== undefined ? raw.duration : raw.totalRunTime
        return normalized
    }

    function normalizeInstances(instances) {
        var source = toJsArray(instances)
        var normalized = []
        for (var i = 0; i < source.length; i++) {
            normalized.push(normalizeInstance(source[i]))
        }
        return normalized
    }

    function visibleUserMatchesInstance(visibleUser, instance) {
        if (!visibleUser || !instance) {
            return false
        }

        var userKeys = [
            visibleUser.authUserId,
            visibleUser.account,
            visibleUser.authUserName,
            visibleUser.displayName,
            visibleUser.user_id,
            visibleUser.user_name
        ]
        var instanceKeys = [
            instance.creatorUserId,
            instance.creatorUserName,
            instance.authUserId,
            instance.applicantAccount,
            instance.applicantUserId,
            instance.applicantUserName,
            instance.user
        ]

        for (var i = 0; i < userKeys.length; i++) {
            var userKey = (userKeys[i] || "").toString().trim()
            if (!userKey) continue
            for (var j = 0; j < instanceKeys.length; j++) {
                var instanceKey = (instanceKeys[j] || "").toString().trim()
                if (instanceKey && instanceKey === userKey) {
                    return true
                }
            }
        }
        return false
    }

    function visibleUserText(visibleUser, fallback) {
        if (!visibleUser) {
            return fallback || ""
        }

        var authUserName = (visibleUser.authUserName || visibleUser.user_name || "").toString().trim()
        return authUserName || fallback || ""
    }

    function resolveInstanceApplicantText(instance) {
        var fallback = (instance && (instance.creatorUserName || instance.applicantUserName || instance.creatorUserId || instance.authUserId || instance.applicantUserId || instance.user)) ? (instance.creatorUserName || instance.applicantUserName || instance.creatorUserId || instance.authUserId || instance.applicantUserId || instance.user).toString().trim() : ""
        var visibleUsers = toJsArray(root.domainData ? root.domainData.visibleUsers : [])
        for (var i = 0; i < visibleUsers.length; i++) {
            var visibleUser = visibleUsers[i] || {}
            if (visibleUserMatchesInstance(visibleUser, instance)) {
                return visibleUserText(visibleUser, fallback)
            }
        }
        return fallback
    }

    function isInstanceCreatorVisibleUser(instance) {
        var visibleUsers = toJsArray(root.domainData ? root.domainData.visibleUsers : [])
        for (var i = 0; i < visibleUsers.length; i++) {
            if (visibleUserMatchesInstance(visibleUsers[i], instance)) {
                return true
            }
        }
        return false
    }

    function sortByTimeDesc(list, primaryField, secondaryField) {
        var source = toJsArray(list)
        source.sort(function(a, b) {
            var ta = toSortableTime(a && a[primaryField] ? a[primaryField] : (secondaryField ? (a && a[secondaryField] ? a[secondaryField] : "") : ""))
            var tb = toSortableTime(b && b[primaryField] ? b[primaryField] : (secondaryField ? (b && b[secondaryField] ? b[secondaryField] : "") : ""))
            if (ta === tb) {
                return 0
            }
            return tb - ta
        })
        return source
    }

    function dedupeWhitelistAudits(list) {
        var source = toJsArray(list)
        var deduped = []
        var seen = {}
        for (var i = 0; i < source.length; i++) {
            var row = source[i] || {}
            var applyCode = (row.applyCode || row.id || "").toString().trim()
            var instanceId = (row.instanceId || "").toString().trim()
            var appName = (row.appName || "").toString().trim()
            var key = applyCode
                ? ("AC|" + applyCode)
                : ["IX", instanceId, appName].join("|")
            if (!key || seen[key]) {
                continue
            }
            seen[key] = true
            deduped.push(row)
        }
        return deduped
    }

    function dedupeExportAudits(list) {
        var source = toJsArray(list)
        var deduped = []
        var seen = {}
        for (var i = 0; i < source.length; i++) {
            var row = source[i] || {}
            var applyCode = (row.applyCode || row.id || "").toString().trim()
            var fileCode = (row.fileCode || "").toString().trim()
            var instanceId = (row.instanceId || "").toString().trim()
            var fileHash = (row.fileHash || "").toString().trim()
            var key = applyCode
                ? ("AC|" + applyCode + "|" + fileCode)
                : ["IX", instanceId, fileCode, fileHash].join("|")
            if (!key || seen[key]) {
                continue
            }
            seen[key] = true
            deduped.push(row)
        }
        return deduped
    }

    function getInstanceDetailFromCache(instanceId, instanceName) {
        return null
    }

    function resolveWhitelistProcessesByRow(row) {
        // Helper: normalize process entries so dialog can show fileName/fileHash
        function normProcs(src) {
            if (!src || src.length === 0) return []
            var out = []
            for (var k = 0; k < src.length; k++) {
                var e = src[k] || {}
                var fn = e.fileName || e.masterFileName || e.appName || ""
                if (!fn && (e.filePath || e.path)) {
                    var fp = (e.filePath || e.path).replace(/\\/g, "/")
                    var parts = fp.split("/")
                    fn = parts[parts.length - 1] || fp
                }
                out.push({
                    fileName:       fn,
                    masterFileName: e.masterFileName || fn,
                    filePath:       e.filePath || e.path || "",
                    fileCode:       e.fileCode || "",
                    fileHash:       e.fileHash || e.hash || "",
                    status:         e.status || ""
                })
            }
            return out
        }

        // First try: look up from instance detail cache
        var instDetail = getInstanceDetailFromCache(row.instanceId || "", row.instanceName || "")
        if (instDetail) {
            var applyCode = (row.applyCode || "").toString().trim()
            if (applyCode) {
                var audits = instDetail.appWhitelistAudits || []
                for (var i = 0; i < audits.length; i++) {
                    var audit = audits[i] || {}
                    if ((audit.applyCode || "").toString().trim() !== applyCode) continue
                    var src = audit.processes || audit.rawFiles || audit.filePaths || []
                    if (src.length > 0) return normProcs(src)
                }
            }
        }

        // Fallback: use processes/rawFiles stored directly on the row
        var rowSrc = row.processes || row.rawFiles || row.filePaths || []
        return normProcs(rowSrc)
    }

    function resolveExportDialogDataByRow(row) {
        var fallback = {
            fileCount: Number(row.fileCount) || 0,
            fileSize: Number(row.fileSize) || 0,
            status: row.status || "待审核",
            applyTime: row.applyTime || "",
            reason: row.reason || "",
            files: row.files || [],
            fileCode: row.fileCode || "",
            fileHash: row.fileHash || ""
        }
        var instDetail = getInstanceDetailFromCache(row.instanceId || "", row.instanceName || "")
        if (!instDetail) {
            return fallback
        }
        var applyCode = (row.applyCode || "").toString().trim()
        if (!applyCode) {
            return fallback
        }
        var reqs = instDetail.exportRequests || []
        for (var i = 0; i < reqs.length; i++) {
            var req = reqs[i] || {}
            if ((req.applyCode || "").toString().trim() !== applyCode) {
                continue
            }

            var reqFiles = req.rawFiles || req.filePaths || []
            var target = null
            var rowFileCode = (row.fileCode || "").toString().trim()
            if (rowFileCode && reqFiles && reqFiles.length > 0) {
                for (var rf = 0; rf < reqFiles.length; rf++) {
                    var raw = reqFiles[rf] || {}
                    if ((raw.fileCode || "").toString().trim() === rowFileCode) {
                        target = raw
                        break
                    }
                }
            }
            if (!target && reqFiles && reqFiles.length > 0) {
                target = reqFiles[0] || null
            }

            var totalSize = Number(req.fileSize)
            if (isNaN(totalSize) || totalSize < 0) {
                totalSize = Number(req.totalFileSize)
            }
            if (isNaN(totalSize) || totalSize < 0) {
                totalSize = Number(req.file_size)
            }
            if (isNaN(totalSize) || totalSize < 0) {
                totalSize = 0
            }

            var targetSize = Number(target && target.fileSize !== undefined ? target.fileSize : (target ? target.file_size : 0))
            if (isNaN(targetSize) || targetSize < 0) {
                targetSize = 0
            }
            if (targetSize <= 0 && totalSize > 0) {
                targetSize = totalSize
            }

            var targetPath = (target && (target.filePath || target.fileName)) ? (target.filePath || target.fileName) : ""
            return {
                fileCount: Number(req.fileCount) || (reqFiles ? reqFiles.length : 0),
                fileSize: targetSize,
                status: (target && target.status) || req.status || fallback.status,
                applyTime: req.applyTime || fallback.applyTime,
                reason: req.reason || fallback.reason,
                files: targetPath ? [targetPath] : (fallback.files || []),
                fileCode: (target && target.fileCode) || req.fileCode || fallback.fileCode,
                fileHash: (target && target.fileHash) || req.fileHash || fallback.fileHash
            }
        }
        return fallback
    }
    
    function getDomainData() {
        // 数据源为 Loaded 信号填充的 root.domainData，此函数仅作保护返回
        if (domainDetailLoading) return emptyDomainDetail()
        return root.domainData || emptyDomainDetail()
    }

    function reloadAllData() {
        if (!root.currentDomainCode) return
        if (typeof DsccBridge === "undefined") return
        DsccBridge.loadDomainSummary(root.currentDomainCode)
        DsccBridge.loadInstances(root.currentDomainCode)
        DsccBridge.loadAudits(root.currentDomainCode, 1)
        DsccBridge.loadAudits(root.currentDomainCode, 2)
    }

    function formatPayerText(payerValue) {
        if (!payerValue) {
            return "-"
        }
        if (payerValue === "创建方" || payerValue === "安全域创建方" || payerValue === "创建者") {
            return qsTr("Creator")
        }
        if (payerValue === "使用方" || payerValue === "安全域使用方" || payerValue === "使用者") {
            return qsTr("User")
        }
        return payerValue
    }
    
    // Update domainData when domainName changes
    onDomainNameChanged: {
        // 仅清理状态，不重新加载数据（加载由 onCurrentDomainCodeChanged 驱动）
        clearAllPendingStates()
    }

    onDomainPubKeyChanged: {
        // 仅清理状态，不重新加载数据（加载由 onCurrentDomainCodeChanged 驱动）
        clearAllPendingStates()
    }

    onCurrentDomainCodeChanged: {
        // 切换安全域的唯一入口：清状态 + 重设分页 + 重加全量数据
        clearAllPendingStates()
        resetAllPagedCardsToFirstPage()
        resetAuditDataLoading()
        domainData = emptyDomainDetail()
        reloadAllData()
        auditDataLoaded = canRenderAuditEmptyState(domainData)
    }
    
    // Function to clear all pending operation states
    function clearAllPendingStates() {
        // Clear deactivate domain pending state
        if (deactivateDomainState.isPending) {
            deactivateDomainState.isPending = false
            deactivateDomainState.pendingDomainPubKey = ""
            deactivateDomainState.pendingDomainCode = ""
        }
        
        // Clear remove user pending state
        if (root.removeUserState_pendingRemovedAccount) {
            root.removeUserState_pendingRemovedAccount = ""
            root.removeUserState_pendingDomainPubKey = ""
            root.removeUserState_pendingDomainCode = ""
        }
        
        // Clear add user pending state
        if (addUserDialog.pendingAccount) {
            addUserDialog.pendingAccount = ""
            addUserDialog.pendingVisibleUsers = []
            addUserDialog.pendingDomainPubKey = ""
            addUserDialog.pendingDomainCode = ""
        }

        root.visibleUserOperationState_busy = false

        // Reset description editing state
        isEditingDescription = false
        editedDescription = ""

        if (addUserDialog.isVerifying) {
            addUserDialog.isVerifying = false
        }

        addUserDialog.currentUserInfo = null
        if (addUserDialog.opened) {
            addUserDialog.close()
        }

        if (deactivateDialog.opened) {
            deactivateDialog.close()
        }

    }

    function resetAllPagedCardsToFirstPage() {
        if (typeof visibleUsersCard !== "undefined" && visibleUsersCard) {
            visibleUsersCard.currentPage = 1
        }
        if (typeof relatedInstancesCard !== "undefined" && relatedInstancesCard) {
            relatedInstancesCard.currentPage = 1
        }
        if (typeof appWhitelistAuditCard !== "undefined" && appWhitelistAuditCard) {
            appWhitelistAuditCard.currentPage = 1
        }
        if (typeof exportAuditCard !== "undefined" && exportAuditCard) {
            exportAuditCard.currentPage = 1
        }
    }

    function isVisibleUserOperationInProgress() {
        return !!root.visibleUserOperationState_busy
    }

    onDataVersionChanged: {
        // dataVersion 用于外部触发刷新，调用 reloadAllData
        if (!domainDetailLoading) {
            reloadAllData()
        }
    }

    onDomainDetailLoadingChanged: {
        if (domainDetailLoading) {
            resetAllPagedCardsToFirstPage()
            resetAuditDataLoading()
            domainData = emptyDomainDetail()
            return
        }
        auditDataLoaded = canRenderAuditEmptyState(domainData)
    }

    onDomainDataChanged: {
        if (domainData && domainData.name && domainData.name !== domainName) {
            domainName = domainData.name
        }
        if (domainData && domainData.pubKey && domainData.pubKey !== domainPubKey) {
            domainPubKey = domainData.pubKey
        }
        if (!auditDataLoaded && canRenderAuditEmptyState(domainData)) {
            auditDataLoaded = true
        }
    }

    Component.onCompleted: {
        auditDataLoaded = canRenderAuditEmptyState(domainData)
    }
    
    // removeUserState properties promoted to root for QML delegate scope access

    QtObject {
        id: visibleUserOperationState
        property bool busy: false
    }
    
    // Pending state for deactivating domain
    QtObject {
        id: deactivateDomainState
        property bool isPending: false
        property string pendingDomainPubKey: ""
        property string pendingDomainCode: ""
    }


    // Add Visible User Dialog
    AddVisibleUserDialog {
        id: addUserDialog
        
        property string pendingAccount: ""
        property var pendingVisibleUsers: []
        property string pendingDomainPubKey: ""  // 标识哪个域在等待更新
        property string pendingDomainCode: ""
        
        onAddClicked: function(account) {
            if (root.isDomainReadOnly) {
                return
            }

            var trimmed = account ? account.trim() : ""
            if (!trimmed) {
                return
            }

            if (root.isVisibleUserOperationInProgress()) {
                return
            }

            root.visibleUserOperationState_busy = true
            
            // Get current domain detail
            // 从 addUserDialog 获取用户详细信息
            var userInfo = addUserDialog.currentUserInfo || {}
            var userId = (userInfo.user_id || userInfo.authUserId || "").trim()
            var userName = (userInfo.user_name || userInfo.authUserName || "").trim()
            var newAccount = (userInfo.account || "").trim()
            var displayName = (userInfo.displayName || newAccount).trim()
            if (!newAccount || !userId || !userName) {
                root.visibleUserOperationState_busy = false
                return
            }
            
            // Create a copy of visible users list (don't modify original array)
            var existingUsers = (root.domainData && root.domainData.visibleUsers) || []
            
            // Check if user already exists (仅按 username/account，大小写敏感)
            var userExists = false
            for (var i = 0; i < existingUsers.length; i++) {
                if (newAccount && existingUsers[i] && existingUsers[i].account === newAccount) {
                    userExists = true
                    break
                }
            }
            
            if (!userExists) {
                var newUser = {
                    account: newAccount,
                    displayName: displayName,
                    authUserId: userId,
                    authUserName: userName
                }
                
                // Create new array with all users (existing + new)
                var updatedVisibleUsers = []
                for (var j = 0; j < existingUsers.length; j++) {
                    updatedVisibleUsers.push(existingUsers[j])
                }
                updatedVisibleUsers.push(newUser)
                
                var domainCode = root.currentDomainCode || ""
                if (!domainCode) {
                    root.visibleUserOperationState_busy = false
                    return
                }

                // 保存完整用户信息，供成功回调写入本地列表
                root.pendingAddUserFullInfo = newUser
                DsccBridge.addUserToDomain(domainCode, userId)
            } else {
                root.visibleUserOperationState_busy = false
            }
        }
    }


    // Encrypt File Dialog
    EncryptFileDialog {
        id: encryptFileDialog
        domainName: root.domainName
        domainPubKey: root.domainPubKey
    }
    
    // Deactivate Confirm Dialog
    DeactivateConfirmDialog {
        id: deactivateDialog
        domainName: root.domainData.name
        
        onConfirmClicked: {
            handleDeactivateDomain()
        }
    }
    
    // Export Detail Dialog
    ExportDetailDialog {
        id: exportDetailDialog
        isCreator: root.isCreator
        allowApproveReject: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending) return
            var _applyCode = exportDetailDialog.exportId || ""
            var _fileCode  = exportDetailDialog.fileCode || ""
            var _fileHash  = exportDetailDialog.fileHash || ""
            if (!_applyCode) { window.showError("缺少申请编号", "文件导出审核"); return }
            if (!_fileCode) { window.showError("缺少文件编号", "文件导出审核"); return }
            if (!_fileHash) { window.showError("缺少文件哈希", "文件导出审核"); return }
            root.auditRequestPending = true
            DsccBridge.auditRequest(_applyCode, _fileCode, true, _fileHash)
        }

        onRejectClicked: {
            if (root.auditRequestPending) return
            var _applyCode = exportDetailDialog.exportId || ""
            var _fileCode  = exportDetailDialog.fileCode || ""
            if (!_applyCode) { window.showError("缺少申请编号", "文件导出审核"); return }
            if (!_fileCode) { window.showError("缺少文件编号", "文件导出审核"); return }
            root.auditRequestPending = true
            DsccBridge.auditRequest(_applyCode, _fileCode, false, "")
        }
    }
    
    // Instance Detail Dialog (shared for all statuses, including pending)
    InstanceDetailDialog {
        id: instanceDetailDialog
        parent: Overlay.overlay  // Use application overlay as parent for proper sizing
        allowApproveReject: !root.isDomainReadOnly && !root.instanceAuditPending

        onApproveClicked: {
            if (root.instanceAuditPending) return
            var code = instanceDetailDialog.instanceId || ""
            if (!code) return
            root.instanceAuditPending = true
            DsccBridge.auditInstanceRequest(code, true)
        }

        onRejectClicked: {
            if (root.instanceAuditPending) return
            var code = instanceDetailDialog.instanceId || ""
            if (!code) return
            root.instanceAuditPending = true
            DsccBridge.auditInstanceRequest(code, false)
        }
    }

    // App Whitelist Audit Detail Dialog
    AppWhitelistDetailDialog {
        id: appWhitelistDetailDialog
        parent: Overlay.overlay
        showActionButtons: !root.isDomainReadOnly && !root.auditRequestPending

        onApproveClicked: {
            if (root.auditRequestPending) return
            var _applyCode = appWhitelistDetailDialog.applyCode || ""
            var _fileCode  = appWhitelistDetailDialog.fileCode || ""
            var _fileHash  = appWhitelistDetailDialog.fileHash || ""
            if (!_applyCode) { window.showError("缺少申请编号", "应用白名单审核"); return }
            if (!_fileCode) { window.showError("缺少文件编号", "应用白名单审核"); return }
            if (!_fileHash) { window.showError("缺少文件哈希", "应用白名单审核"); return }
            root.auditRequestPending = true
            DsccBridge.auditRequest(_applyCode, _fileCode, true, _fileHash)
        }

        onRejectClicked: {
            if (root.auditRequestPending) return
            var _applyCode = appWhitelistDetailDialog.applyCode || ""
            var _fileCode  = appWhitelistDetailDialog.fileCode || ""
            if (!_applyCode) { window.showError("缺少申请编号", "应用白名单审核"); return }
            if (!_fileCode) { window.showError("缺少文件编号", "应用白名单审核"); return }
            root.auditRequestPending = true
            DsccBridge.auditRequest(_applyCode, _fileCode, false, "")
        }
    }
    
    ScrollView {
        id: detailScrollView
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 64
        
        background: Rectangle {
            color: "#e8edf3"  // 稍微加深的灰色背景，增强与白色卡片的对比
        }

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        
        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 16  // reduce gap to tighten title上下留白
            
            // Header with title and buttons
            Item {
                width: parent.width
                height: 32  // tighten header vertical whitespace
                
                // Title
                Text {
                    id: headerTitleText
                    anchors.left: parent.left
                    anchors.right: headerButtonRow.left
                    anchors.rightMargin: 48  // 2 Chinese chars at 24px ≈ 48px
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.domainData.name
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    color: "#0f172b"
                    elide: Text.ElideRight

                    ToolTip.visible: truncated && headerTitleHover.containsMouse
                    ToolTip.text: root.domainData.name
                    ToolTip.delay: 500

                    HoverHandler {
                        id: headerTitleHover
                        enabled: headerTitleText.truncated
                    }
                }
                
                // Buttons on the right
                Row {
                    id: headerButtonRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // 查看功能介绍 — 文字链接
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: guideLinkText.implicitWidth + 12
                        height: 36
                        radius: 5
                        color: Qt.rgba(238/255, 244/255, 251/255, 0)

                        Text {
                            id: guideLinkText
                            anchors.centerIn: parent
                            text: qsTr("View Feature Guide")
                            font.pixelSize: 14
                            font.underline: true
                            color: guideArea.pressed ? Qt.darker(Theme.Colors.primary, 1.4)
                                   : guideArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.3)
                                   : Theme.Colors.primary
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: guideArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: onboardingGuide.show()
                        }
                    }

                    // Only visible to creator and when domain is active
                    Rectangle {
                        id: encryptFileButton
                        width: encryptRow.width + 24  // Dynamic width
                        height: 36
                        radius: 8
                        color: {
                            if (encryptMouseArea.pressed) return Qt.darker("#0f4c81", 1.2)
                            if (encryptMouseArea.containsMouse) return Qt.lighter("#0f4c81", 1.15)
                            return "#0f4c81"
                        }
                        visible: true
                        opacity: !root.isDomainReadOnly ? 1.0 : 0.5
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        Row {
                            id: encryptRow
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-encrypt-to-domain.svg")
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            // Text - positioned to match Figma design
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Encrypt Files to This Security Domain")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: "white"
                            }
                        }
                        
                        MouseArea {
                            id: encryptMouseArea
                            anchors.fill: parent
                            enabled: !root.isDomainReadOnly
                            hoverEnabled: true
                            cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: {
                                if (root.isDomainReadOnly) {
                                    return
                                }
                                if (!root.domainPubKey) {
                                    window.showError("未找到安全域公钥", "加密文件")
                                    return
                                }
                                encryptFileDialog.open()
                            }
                        }
                    }
                    Rectangle {
                        id: createInstanceButton
                        visible: true
                        width: instantiateRow.width + 24
                        height: 36
                        radius: 8
                        color: {
                            if (instantiateMouseArea.pressed) return "#dce8f5"
                            if (instantiateMouseArea.containsMouse) return "#eef4fb"
                            return "#ffffff"
                        }
                        border.color: instantiateMouseArea.containsMouse ? Theme.Colors.primary : Qt.lighter(Theme.Colors.primary, 1.4)
                        border.width: 1
                        opacity: !root.isDomainReadOnly ? 1.0 : 0.5
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        Row {
                            id: instantiateRow
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("icons/icon-domain-instance.svg")
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Create Security Domain Instance")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: instantiateMouseArea.containsMouse ? Qt.lighter(Theme.Colors.primary, 1.3) : Theme.Colors.primary
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                        
                        MouseArea {
                            id: instantiateMouseArea
                            anchors.fill: parent
                            enabled: !root.isDomainReadOnly
                            hoverEnabled: true
                            cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: {
                                if (root.isDomainReadOnly) {
                                    return
                                }
                                root.instantiateRequested()
                            }
                        }
                    }
                }
            }
            
            // Basic Info Card - dynamic height based on content
            Rectangle {
                id: basicInfoCard
                width: parent.width
                // Dynamic height: 48px (margins) + Column implicit height
                property int margins: 48  // Top and bottom margins (24px * 2)
                
                height: margins + basicInfoColumn.implicitHeight
                radius: 14
                color: Theme.Colors.backgroundWhite
                antialiasing: true
                
                Column {
                    id: basicInfoColumn
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24
                    
                    // Basic info grid
                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 24  // gap between columns
                        rowSpacing: 24
                        
                        // Name field
                        Column {
                            width: (parent.width - 24) / 2  // Half width minus spacing
                            spacing: 4
                            
                            SelectableText {
                                text: qsTr("Name")
                                font.pixelSize: 16
                                color: "#62748e"
                            }
                            
                            Text {
                                id: basicInfoNameText
                                width: parent.width
                                text: root.domainData.name
                                font.pixelSize: 16
                                color: "#0f172b"
                                elide: Text.ElideRight

                                ToolTip.visible: truncated && basicInfoNameHover.containsMouse
                                ToolTip.text: root.domainData.name
                                ToolTip.delay: 500

                                HoverHandler {
                                    id: basicInfoNameHover
                                    enabled: basicInfoNameText.truncated
                                }
                            }
                        }
                        
                        // Creator field
                        Column {
                            width: (parent.width - 24) / 2
                            spacing: 4
                            
                            SelectableText {
                                text: qsTr("Creator")
                                font.pixelSize: 16
                                color: "#62748e"
                            }
                            
                            SelectableText {
                                text: root.domainCreatorDisplayText(root.domainData)
                                font.pixelSize: 16
                                color: "#0f172b"
                            }
                        }
                        
                        // Status field
                        Column {
                            width: (parent.width - 24) / 2
                            spacing: 4
                            
                            SelectableText {
                                text: qsTr("Status")
                                font.pixelSize: 16
                                color: "#62748e"
                            }
                            
                            Rectangle {
                                width: {
                                    // Dynamic width based on status text length
                                    var statusText = root.domainData.status || ""
                                    return Math.max(60, statusText.length * 14 + 18)
                                }
                                height: 28
                                radius: 8
                                property var domainStatusStyle: Theme.Colors.getStatusColor(root.domainData.status || "运行中")
                                color: domainStatusStyle.bg
                                border.color: domainStatusStyle.border
                                border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: (root.domainData.status || "") === "运行中"
                                        ? "正常"
                                        : (window.translateStatus(root.domainData.status || "") || "")
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    color: parent.domainStatusStyle.text
                                }
                            }
                        }
                        
                        // Created time field
                        Column {
                            width: (parent.width - 24) / 2
                            spacing: 4

                            SelectableText {
                                text: qsTr("Creation Time")
                                font.pixelSize: 16
                                color: "#62748e"
                            }

                            SelectableText {
                                text: Theme.Utils.formatDateTime(root.domainData.createdAt)
                                font.pixelSize: 16
                                color: "#0f172b"
                            }
                        }
                        
                        // Payer field
                        Column {
                            width: (parent.width - 24) / 2
                            spacing: 4
                            
                            Row {
                                spacing: 4
                                
                                SelectableText {
                                    text: qsTr("Fee Payer")
                                    font.pixelSize: 16
                                    color: "#62748e"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Rectangle {
                                    width: 16
                                    height: 16
                                    color: "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Image {
                                        id: payerInfoIcon
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        source: "qrc:/icons/icon-info.svg"
                                        fillMode: Image.PreserveAspectFit
                                        visible: true
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onEntered: {
                                                payerTooltip.visible = true
                                            }
                                            onExited: {
                                                payerTooltip.visible = false
                                            }
                                        }
                                    }
                                    
                                    // Tooltip popup
                                    Rectangle {
                                        id: payerTooltip
                                        visible: false
                                        width: tooltipLabel.implicitWidth + 16
                                        height: tooltipLabel.implicitHeight + 10
                                        color: "#1e5a8e"
                                        radius: 4
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        z: 100
                                        
                                        // Tooltip arrow (pointing down, centered)
                                        Canvas {
                                            width: 12
                                            height: 6
                                            anchors.top: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.fillStyle = "#1e5a8e"
                                                ctx.beginPath()
                                                ctx.moveTo(0, 0)
                                                ctx.lineTo(6, 6)
                                                ctx.lineTo(12, 0)
                                                ctx.closePath()
                                                ctx.fill()
                                            }
                                        }
                                        
                                        Text {
                                            id: tooltipLabel
                                            anchors.centerIn: parent
                                            text: qsTr("Who pays the costs incurred after security domain instantiation?")
                                            font.pixelSize: 12
                                            color: "#ffffff"
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                }
                            }
                            
                            SelectableText {
                                text: root.formatPayerText(root.domainData.payer)
                                font.pixelSize: 14
                                color: "#0f172b"
                            }
                        }
                    }
                    
                    // Description field
                    Column {
                        width: parent.width
                        spacing: 8
                        
                        Item {
                            width: parent.width
                            height: 32
                            
                            // Description label
                            SelectableText {
                                id: descriptionLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                text: qsTr("Description")
                                font.pixelSize: 16
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
                                opacity: !root.isDomainReadOnly ? 1.0 : 0.5
                                property bool hovered: false
                                property bool pressed: false
                                // Hover: light blue, Pressed: darker blue
                                color: {
                                    if (pressed) return "#c1d9ef"
                                    if (hovered) return "#eaf2fb"
                                    return "transparent"
                                }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4  // Space between icon and text
                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        // Edit icon (non-editing state)
                                        Image {
                                            width: 16
                                            height: 16
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("icons/icon-edit.svg")
                                            fillMode: Image.PreserveAspectFit
                                            visible: !root.isEditingDescription
                                        }
                                        
                                        // Blue checkmark (editing/save state) - drawn with Canvas
                                        Canvas {
                                            width: 16
                                            height: 16
                                            anchors.centerIn: parent
                                            visible: root.isEditingDescription
                                            
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.strokeStyle = Theme.Colors.primary
                                                ctx.lineWidth = 2
                                                ctx.lineCap = "round"
                                                ctx.lineJoin = "round"
                                                
                                                // Draw checkmark
                                                ctx.beginPath()
                                                ctx.moveTo(3, 8)
                                                ctx.lineTo(6, 11)
                                                ctx.lineTo(13, 4)
                                                ctx.stroke()
                                            }
                                        }
                                    }
                                    
                                    // Text - positioned to match Figma design
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.isEditingDescription ? qsTr("Save") : qsTr("Edit")
                                        font.pixelSize: 16
                                        font.weight: Font.Medium
                                        color: Theme.Colors.primary
                                    }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.isDomainReadOnly && !root.isDescriptionSaving
                                    hoverEnabled: true
                                    cursorShape: (!root.isDomainReadOnly && !root.isDescriptionSaving) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    onEntered: parent.hovered = true
                                    onExited: parent.hovered = false
                                    onPressed: { parent.pressed = true; if (root.isEditingDescription) root._savingFromButton = true }
                                    onReleased: { parent.pressed = false; root._savingFromButton = false }
                                    onCanceled: { parent.pressed = false; root._savingFromButton = false }
                                    onClicked: {
                                        if (root.isDomainReadOnly || root.isDescriptionSaving) {
                                            return
                                        }
                                        if (root.isEditingDescription) {
                                            if ((root.editedDescription || "").length > root.descriptionMaxLength) {
                                                root.descriptionErrorMessage = "描述最多可输入500个字符"
                                                return
                                            }
                                            root.descriptionErrorMessage = ""

                                            var domainCode = root.currentDomainCode || ""
                                            if (!domainCode) {
                                                root.isEditingDescription = false
                                                return
                                            }
                                            root.isDescriptionSaving = true
                                            DsccBridge.updateDomainDesc(domainCode, root.editedDescription)
                                        } else {
                                            // Enter edit mode
                                            root._originalDescription = root.domainData.description || ""
                                            root.editedDescription = root._originalDescription
                                            root.descriptionErrorMessage = ""
                                            root.isEditingDescription = true
                                        }
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            id: descriptionBox
                            width: parent.width
                            visible: root.isEditingDescription || (root.domainData.description && root.domainData.description.length > 0)
                            // Dynamic height: minimum 57px, or based on content
                            property int minHeight: 57
                            property int padding: 32  // Top and bottom padding (16px * 2)
                            
                            // Calculate height based on content
                            height: {
                                if (root.isEditingDescription) {
                                    // In edit mode, use TextArea content height
                                    // Add extra padding to ensure last line is fully visible
                                    var textAreaHeight = descriptionTextArea.contentHeight > 0 ? descriptionTextArea.contentHeight : 25
                                    return Math.max(minHeight, textAreaHeight + padding + 4)  // +4 for extra bottom space
                                } else {
                                    // In display mode, use Text implicit height
                                    return Math.max(minHeight, descriptionText.implicitHeight + padding)
                                }
                            }
                            radius: 8
                            color: {
                                if (!root.isEditingDescription) return Theme.Colors.inputBackground
                                if (descriptionTextArea.activeFocus) return Theme.Colors.backgroundWhite
                                return descriptionHoverArea.containsMouse ? "#e9eef6" : Theme.Colors.backgroundWhite
                            }
                            border.color: "#cad5e2"
                            border.width: root.isEditingDescription ? 1 : 0
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            // Display mode: show SelectableText when not editing
                            SelectableText {
                                id: descriptionText
                                anchors.left: parent.left
                                anchors.leftMargin: 17
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                width: parent.width - 34
                                text: (root.domainData.description && root.domainData.description.length > 0) ? root.domainData.description : ""
                                font.pixelSize: 14
                                color: "#0f172b"
                                wrapMode: TextEdit.Wrap
                                visible: !root.isEditingDescription
                            }
                            
                            // Edit mode: show TextArea when editing
                            TextArea {
                                id: descriptionTextArea
                                anchors.left: parent.left
                                anchors.leftMargin: 17
                                anchors.right: parent.right
                                anchors.rightMargin: 17
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                // Don't use anchors.bottom, let height be determined by content
                                height: contentHeight > 0 ? contentHeight : 25  // Minimum height for one line
                                text: root.editedDescription
                                font.pixelSize: 14
                                color: "#0f172b"
                                selectedTextColor: "#0f172b"  // 选中文本颜色与普通文本一致
                                selectionColor: "#d4e4f1"  // 使用浅灰蓝色作为选中背景色
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                readOnly: root.isDomainReadOnly  // Read-only when domain is closed or current user isn't creator
                                // Remove default padding to ensure accurate height calculation
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                // background customization removed to avoid native style warnings
                                visible: root.isEditingDescription
                                
                                onTextChanged: {
                                    root.editedDescription = text
                                    if ((text || "").length > root.descriptionMaxLength) {
                                        root.descriptionErrorMessage = "描述最多可输入500个字符"
                                    } else {
                                        root.descriptionErrorMessage = ""
                                    }
                                }

                                Keys.onEscapePressed: {
                                    root.editedDescription = root._originalDescription
                                    root.descriptionErrorMessage = ""
                                    root.isEditingDescription = false
                                }

                                onActiveFocusChanged: {
                                    if (!activeFocus && root.isEditingDescription && !root._savingFromButton) {
                                        root.editedDescription = root._originalDescription
                                        root.descriptionErrorMessage = ""
                                        root.isEditingDescription = false
                                    }
                                }
                                
                                // Focus the TextArea when entering edit mode
                                Component.onCompleted: {
                                    if (root.isEditingDescription) {
                                        forceActiveFocus()
                                    }
                                }
                            }
                            
                            // Right-click context menu for description TextArea
                            InputContextMenu {
                                anchors.left: parent.left
                                anchors.leftMargin: 17
                                anchors.right: parent.right
                                anchors.rightMargin: 17
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                height: descriptionTextArea.contentHeight > 0 ? descriptionTextArea.contentHeight : 25
                                target: descriptionTextArea
                                visible: root.isEditingDescription
                                z: 1
                            }

                            MouseArea {
                                id: descriptionHoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                visible: root.isEditingDescription
                            }
                            
                            // Update TextArea focus when entering edit mode
                            Connections {
                                target: root
                                function onIsEditingDescriptionChanged() {
                                    if (root.isEditingDescription) {
                                        descriptionTextArea.forceActiveFocus()
                                        // Select all text for easy editing
                                        descriptionTextArea.selectAll()
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            visible: root.isEditingDescription

                            Item {
                                width: parent.width
                                height: 20

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.editedDescription || "").length + "/" + root.descriptionMaxLength
                                    font.pixelSize: 13
                                    color: (root.editedDescription || "").length > root.descriptionMaxLength ? "#e7000b" : "#64748b"
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 6
                            visible: root.isEditingDescription && root.descriptionErrorMessage !== ""

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
                                text: root.descriptionErrorMessage
                                font.pixelSize: 14
                                color: "#e7000b"
                            }
                        }
                    }
                }
            }
            
            // Visible Users Card - dynamic height based on user count
            Rectangle {
                id: visibleUsersCard
                visible: true  // Always show visible users card
                width: parent.width
                // Dynamic height calculation:
                property int headerHeight: 28  // Header with title and add button
                property int tableHeaderHeight: 32  // Table header
                property int rowHeight: 32  // Each user row height
                property int margins: 32  // Top and bottom margins (16px * 2)
                property int spacing: 12  // Spacing between header and table
                property int userCount: root.domainData.visibleUsers ? root.domainData.visibleUsers.length : 0

                // Pagination properties
                property int currentPage: 1
                property int itemsPerPage: 3
                property int totalPages: userCount > 0 ? Math.ceil(userCount * 1.0 / itemsPerPage) : 0
                readonly property int operationColumnWidth: 88
                readonly property int nameColumnWidth: Math.floor((width - 32 - operationColumnWidth) / 2)
                readonly property int accountColumnWidth: Math.max(0, width - 32 - nameColumnWidth - operationColumnWidth)

                function normalizeCurrentPage() {
                    var total = visibleUsersCard.totalPages
                    if (total <= 0) {
                        if (visibleUsersCard.currentPage !== 1) {
                            visibleUsersCard.currentPage = 1
                        }
                        return
                    }

                    if (visibleUsersCard.currentPage < 1) {
                        visibleUsersCard.currentPage = 1
                        return
                    }

                    if (visibleUsersCard.currentPage > total) {
                        visibleUsersCard.currentPage = total
                    }
                }

                onUserCountChanged: normalizeCurrentPage()
                onTotalPagesChanged: normalizeCurrentPage()

                function getPagedVisibleUsers() {
                    var users = root.domainData.visibleUsers || []
                    var start = (visibleUsersCard.currentPage - 1) * visibleUsersCard.itemsPerPage
                    return users.slice(start, Math.min(start + visibleUsersCard.itemsPerPage, users.length))
                }

                function getVisiblePages() {
                   var total = visibleUsersCard.totalPages
                   var current = visibleUsersCard.currentPage
                   var pages = []
                   if (total <= 7) {
                       for (var i = 1; i <= total; i++) pages.push(i)
                   } else {
                       if (current <= 4) {
                           for (var i = 1; i <= 5; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       } else if (current >= total - 3) {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = total - 4; i <= total; i++) pages.push(i)
                       } else {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = current - 1; i <= current + 1; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       }
                   }
                   return pages
                }
                
                height: margins + headerHeight + spacing + (userCount > 0 ? (tableHeaderHeight + (rowHeight * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
                radius: 14
                color: Theme.Colors.backgroundWhite
                antialiasing: true
                smooth: true
                clip: true
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Header with title and add button
                    Item {
                        width: parent.width
                        height: 28
                        
                        // Title
                        SelectableText {
                            id: visibleUsersTitle
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Visible Users")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                        
                        // Add button
                        // Only visible to creator and when domain is active
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 74
                            height: 32
                            radius: 8
                            property bool hovered: false
                            property bool pressed: false
                            // Hover: light blue, Pressed: darker blue
                            color: {
                                if (pressed) return "#c1d9ef"
                                if (hovered) return "#eaf2fb"
                                return "transparent"
                            }
                            visible: true
                            opacity: (!root.isDomainReadOnly && !root.visibleUserOperationState_busy) ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            Row {
                                id: addUserRow
                                anchors.right: parent.right
                                anchors.rightMargin: root.actionRightMargin
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                
                                // Icon
                                Image {
                                    width: 16
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Qt.resolvedUrl("icons/icon-add-user-blue.svg")
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                // Text
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Add")
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    color: Theme.Colors.primary
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.isDomainReadOnly && !root.visibleUserOperationState_busy
                                hoverEnabled: true
                                cursorShape: (!root.isDomainReadOnly && !root.visibleUserOperationState_busy) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onPressed: parent.pressed = true
                                onReleased: parent.pressed = false
                                onCanceled: parent.pressed = false
                                onClicked: {
                                    if (root.isDomainReadOnly || root.visibleUserOperationState_busy) {
                                        return
                                    }
                                    addUserDialog.domainCreator = root.domainData.creator || ""
                                    addUserDialog.open()
                                }
                            }
                        }
                    }
                    
                    // Users table or empty state
                    Column {
                        width: parent.width
                        spacing: 0
                        
                        // Empty state - show icon when user list is empty
                        Item {
                            width: parent.width
                            height: 30
                            visible: visibleUsersCard.userCount === 0
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 16
                                    height: 16
                                    source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                                    sourceSize: Qt.size(16, 16)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No Data")
                                    font.pixelSize: 11
                                    color: "#90A1B9"
                                }
                            }
                        }
                        
                        // Table header - only show when user list is not empty
                        Rectangle {
                            width: parent.width
                            height: 32
                            property bool hovered: false
                            color: hovered ? "#f2f7fd" : "transparent"
                            visible: visibleUsersCard.userCount > 0
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Colors.borderSlate
                            }
                            
                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: parent.hovered = hovered
                            }

                            Row {
                                anchors.fill: parent
                                
                                // Account column
                                Item {
                                    width: visibleUsersCard.accountColumnWidth
                                    height: parent.height
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Account")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                // Name column
                                Item {
                                    width: visibleUsersCard.nameColumnWidth
                                    height: parent.height

                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Name")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                // Operation column
                                // Only show for creator
                                Item {
                                    width: visibleUsersCard.operationColumnWidth
                                    height: parent.height
                                    visible: true

                                    SelectableText {
                                        anchors.right: parent.right
                                        anchors.rightMargin: root.actionRightMargin
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Actions")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                            }
                        }
                        
                        // Table body - only show when user list is not empty
                        Column {
                            width: parent.width
                            height: Math.max(96, 32 * Math.min(visibleUsersCard.itemsPerPage, Math.max(0, visibleUsersCard.userCount - (visibleUsersCard.currentPage - 1) * visibleUsersCard.itemsPerPage)))
                            spacing: 0
                            visible: visibleUsersCard.userCount > 0
                            
                            Repeater {
                                model: {
                                    var users = root.domainData.visibleUsers || []
                                    var start = (visibleUsersCard.currentPage - 1) * visibleUsersCard.itemsPerPage
                                    return users.slice(start, Math.min(start + visibleUsersCard.itemsPerPage, users.length))
                                }
                            
                                Rectangle {
                                    id: visibleUserDelegateRow
                                    width: parent.width
                                    height: 32
                                    property bool hovered: false
                                    color: hovered ? "#f2f7fd" : "transparent"
                                    property var _pageRoot: root
                                
                                HoverHandler {
                                    acceptedDevices: PointerDevice.Mouse
                                    onHoveredChanged: parent.hovered = hovered
                                }

                                Row {
                                    anchors.fill: parent
                                    
                                    // Account cell
                                    Item {
                                        width: visibleUsersCard.accountColumnWidth
                                        height: parent.height
                                        
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.authUserName || modelData.user_name || modelData.account || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 28
                                            boundsItem: visibleUsersCard
                                        }
                                    }

                                    // Name cell
                                    Item {
                                        width: visibleUsersCard.nameColumnWidth
                                        height: parent.height

                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.displayName || modelData.account || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 28
                                            boundsItem: visibleUsersCard
                                        }
                                    }

                                    // Operation cell
                                    // Only show for creator
                                    Item {
                                        width: visibleUsersCard.operationColumnWidth
                                        height: parent.height
                                        visible: true
                                        opacity: !root.isDomainReadOnly ? 1.0 : 0.5
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        
                                        Text {
                                            id: removeText
                                            anchors.right: parent.right
                                            anchors.rightMargin: root.actionRightMargin
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("Remove")
                                            font.pixelSize: root.actionTextPixelSize
                                            font.weight: root.actionTextWeight
                                            property bool hovered: false
                                            color: removeText.hovered ? "#d32f2f" : "#f44336"

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !root.isDomainReadOnly && !root.visibleUserOperationState_busy
                                                hoverEnabled: true
                                                cursorShape: (!root.isDomainReadOnly && !root.visibleUserOperationState_busy) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                                onEntered: removeText.hovered = true
                                                onExited: removeText.hovered = false
                                                onClicked: {
                                                var _r = visibleUserDelegateRow._pageRoot
                                                if (_r.isDomainReadOnly) {
                                                    return
                                                }
                                                if (_r.isVisibleUserOperationInProgress()) {
                                                    return
                                                }
                                                // Prevent duplicate clicks - check if already pending a remove operation
                                                if (_r.removeUserState_pendingRemovedAccount) {
                                                    return
                                                }

                                                _r.visibleUserOperationState_busy = true
                                                
                                                var domainCode = _r.currentDomainCode || ""
                                                if (!domainCode) {
                                                    _r.visibleUserOperationState_busy = false
                                                    return
                                                }

                                                var targetAccount = modelData.account || ""
                                                var pubKey = _r.domainPubKey || ""

                                                var targetAuthUserId = modelData.authUserId || ""
                                                if (!targetAuthUserId) {
                                                    _r.visibleUserOperationState_busy = false
                                                    return
                                                }

                                                _r.removeUserState_pendingRemovedAccount = targetAccount
                                                _r.removeUserState_pendingRemovedAuthUserId = targetAuthUserId
                                                _r.removeUserState_pendingDomainPubKey = pubKey
                                                _r.removeUserState_pendingDomainCode = domainCode
                                                DsccBridge.removeUserFromDomain(domainCode, targetAuthUserId)
                                            }
                                        }
                                    }
                                }
                            }
                            }
                        }
                        }
                        
                        // Pagination Control
                        Item {
                            width: parent.width
                            height: 36
                            visible: visibleUsersCard.totalPages > 1
                            
                            Component.onCompleted: {
                                visibleUsersCard.normalizeCurrentPage()
                            }

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 10
                                spacing: 6

                                // Previous
                                Text {
                                    text: "<"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (visibleUsersCard.currentPage <= 1) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: visibleUsersCard.currentPage > 1 && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: visibleUsersCard.currentPage > 1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: visibleUsersCard.currentPage--
                                    }
                                }

                                Repeater {
                                    model: visibleUsersCard.getVisiblePages()
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        property int pageNum: modelData
                                        property bool isEllipsis: pageNum === -1
                                        property bool hovered: false
                                        property bool pressed: false
                                        property bool isCurrent: pageNum === visibleUsersCard.currentPage
                                        color: {
                                            if (pressed && !isCurrent) return "#1b5fa8"
                                            if (hovered) return "#e3f2fd"
                                            return "white"
                                        }
                                        border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isEllipsis ? "..." : pageNum
                                            font.pixelSize: 12
                                            color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !isEllipsis
                                            cursorShape: !isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: { parent.hovered = false; parent.pressed = false }
                                            onPressed: if (!parent.isCurrent) parent.pressed = true
                                            onReleased: parent.pressed = false
                                            onClicked: if (!parent.isCurrent) visibleUsersCard.currentPage = pageNum
                                        }
                                    }
                                }

                                // Next
                                Text {
                                    text: ">"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (visibleUsersCard.currentPage >= visibleUsersCard.totalPages) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: visibleUsersCard.currentPage < visibleUsersCard.totalPages && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: visibleUsersCard.currentPage < visibleUsersCard.totalPages
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: visibleUsersCard.currentPage++
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Related Instances Card - dynamic height based on instance count
            Rectangle {
                id: relatedInstancesCard
                width: parent.width
                // Dynamic height calculation:
                // 48px (top + bottom margins) + 24px (title) + 16px (spacing) + (if has instances: 40px table header + 38px * instance count, else: just enough for "无" text)
                property int titleHeight: 28  // Title height
                property int tableHeaderHeight: 32  // Table header
                property int rowHeight: 32  // Each instance row height
                property int margins: 32  // Top and bottom margins (16px * 2)
                property int spacing: 12  // Spacing between title and table
                property int instanceCount: toJsArray(root.domainData.instances).length

                // Pagination properties
                property int currentPage: 1
                property int itemsPerPage: 3
                property int totalPages: instanceCount > 0 ? Math.ceil(instanceCount * 1.0 / itemsPerPage) : 0

                readonly property int firstColumnWidth: 140
                readonly property int lastColumnWidth: 78
                // 卡片宽度固定）778（主窗口固定 1050 - 侧边栏 208 - 内容区边距 64 = 778）
                // 中间可用宽= 778 - 32(卡片内边距 - 140 - 78 = 528，均分 3 列每列176
                readonly property int middleColumnWidth: 176

                function middleColumnWidthByIndex(index) {
                    return middleColumnWidth
                }

                function normalizeCurrentPage() {
                    var total = relatedInstancesCard.totalPages
                    if (total <= 0) {
                        if (relatedInstancesCard.currentPage !== 1) {
                            relatedInstancesCard.currentPage = 1
                        }
                        return
                    }

                    if (relatedInstancesCard.currentPage < 1) {
                        relatedInstancesCard.currentPage = 1
                        return
                    }

                    if (relatedInstancesCard.currentPage > total) {
                        relatedInstancesCard.currentPage = total
                    }
                }

                onInstanceCountChanged: normalizeCurrentPage()
                onTotalPagesChanged: normalizeCurrentPage()

                // 中间 3 个标题列（实例名称创建时间/状态）在各自列内的 leftMargin，
                // 使 5 个标题首字等间距（卡片宽固定下的预计算值）
                readonly property int hdrLM1: 43
                readonly property int hdrLM2: 43
                readonly property int hdrLM3: 54

                function getPagedInstances() {
                    var list = toJsArray(root.domainData.instances)
                    var start = (relatedInstancesCard.currentPage - 1) * relatedInstancesCard.itemsPerPage
                    return list.slice(start, Math.min(start + relatedInstancesCard.itemsPerPage, list.length))
                }

                function getVisiblePages() {
                   var total = relatedInstancesCard.totalPages
                   var current = relatedInstancesCard.currentPage
                   var pages = []
                   if (total <= 7) {
                       for (var i = 1; i <= total; i++) pages.push(i)
                   } else {
                       if (current <= 4) {
                           for (var i = 1; i <= 5; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       } else if (current >= total - 3) {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = total - 4; i <= total; i++) pages.push(i)
                       } else {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = current - 1; i <= current + 1; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       }
                   }
                   return pages
                }
                
                height: margins + titleHeight + spacing + (instanceCount > 0 ? (tableHeaderHeight + (rowHeight * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
                radius: 14
                color: Theme.Colors.backgroundWhite
                antialiasing: true
                smooth: true
                clip: true
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Header with title
                    Item {
                        width: parent.width
                        height: 28
                        
                        // Title
                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Related Security Domain Instances")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                    }
                    
                    // Instances table or empty state
                    Column {
                        width: parent.width
                        spacing: 0
                        
                        // Empty state - show icon when instance list is empty
                        Item {
                            width: parent.width
                            height: 30
                            visible: relatedInstancesCard.instanceCount === 0
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 16
                                    height: 16
                                    source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                                    sourceSize: Qt.size(16, 16)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No Data")
                                    font.pixelSize: 11
                                    color: "#90A1B9"
                                }
                            }
                        }
                        
                        // Table header - only show when instance list is not empty
                        Rectangle {
                            width: parent.width
                            height: 32
                            property bool hovered: false
                            color: hovered ? "#f2f7fd" : "transparent"
                            visible: relatedInstancesCard.instanceCount > 0
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Colors.borderSlate
                            }
                            
                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: parent.hovered = hovered
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // Applicant column
                                Item {
                                    Layout.preferredWidth: relatedInstancesCard.firstColumnWidth
                                    Layout.minimumWidth: relatedInstancesCard.firstColumnWidth
                                    Layout.maximumWidth: relatedInstancesCard.firstColumnWidth
                                    Layout.fillHeight: true
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Applicant")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                                
                                // Instance name column
                                Item {
                                    Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.fillHeight: true
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Instance Name")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                                
                                // Created time column (3rd column)
                                Item {
                                    Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.fillHeight: true
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Creation Time")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                                
                                // Status column (2nd from last)
                                Item {
                                    Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                    Layout.fillHeight: true
                                    
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 31
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Status")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                                
                                // Operation column (fixed at right)
                                Item {
                                    Layout.preferredWidth: relatedInstancesCard.lastColumnWidth
                                    Layout.minimumWidth: relatedInstancesCard.lastColumnWidth
                                    Layout.maximumWidth: relatedInstancesCard.lastColumnWidth
                                    Layout.fillHeight: true
                                    
                                    SelectableText {
                                        anchors.right: parent.right
                                        anchors.rightMargin: root.actionRightMargin
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Actions")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                            }
                        }
                        
                        // Table body - only show when instance list is not empty
                        Column {
                            width: parent.width
                            height: Math.max(96, 32 * Math.min(relatedInstancesCard.itemsPerPage, Math.max(0, relatedInstancesCard.instanceCount - (relatedInstancesCard.currentPage - 1) * relatedInstancesCard.itemsPerPage)))
                            spacing: 0
                            visible: relatedInstancesCard.instanceCount > 0
                            
                            Repeater {
                                model: relatedInstancesCard.getPagedInstances()
                            
                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    property bool hovered: false
                                    color: hovered ? "#f2f7fd" : "transparent"
                                
                                    HoverHandler {
                                    id: relatedInstanceHoverHandler
                                    acceptedDevices: PointerDevice.Mouse
                                    onHoveredChanged: parent.hovered = hovered
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    // Applicant cell
                                    Item {
                                        Layout.preferredWidth: relatedInstancesCard.firstColumnWidth
                                        Layout.fillHeight: true
                                        
                                        CenteredTooltipText {
                                            id: instanceApplicantText
                                            anchors.fill: parent
                                            value: resolveInstanceApplicantText(modelData)
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 6
                                            boundsItem: relatedInstancesCard
                                        }
                                    }
                                    
                                    // Instance name cell
                                    Item {
                                        Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.fillHeight: true
                                        
                                        CenteredTooltipText {
                                            id: instanceNameText
                                            anchors.fill: parent
                                            value: modelData.instanceName || modelData.name || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 6
                                            boundsItem: relatedInstancesCard
                                        }
                                    }
                                    
                                    // Applied time cell
                                    Item {
                                        Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.fillHeight: true

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Theme.Utils.formatDateTime(modelData.createdAt || modelData.appliedTime)
                                            font.pixelSize: 14
                                            color: Theme.Colors.textLabel
                                        }
                                    }
                                    
                                    // Status cell
                                    Item {
                                        Layout.preferredWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.minimumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.maximumWidth: relatedInstancesCard.middleColumnWidth
                                        Layout.fillHeight: true
                                        
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 31
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitWidth: instanceStatusText.implicitWidth + 12
                                            implicitHeight: 24
                                            radius: 6
                                            property var instanceStatusStyle: Theme.Colors.getStatusColor(modelData.status || "")
                                            color: instanceStatusStyle.bg
                                            border.color: instanceStatusStyle.border
                                            border.width: 1
                                            
                                            Text {
                                                id: instanceStatusText
                                                anchors.centerIn: parent
                                                text: getStatusText(modelData.status)
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                color: parent.instanceStatusStyle.text
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                    
                                    // Operation cell (fixed at right)
                                    Item {
                                        Layout.preferredWidth: relatedInstancesCard.lastColumnWidth
                                        Layout.minimumWidth: relatedInstancesCard.lastColumnWidth
                                        Layout.maximumWidth: relatedInstancesCard.lastColumnWidth
                                        Layout.fillHeight: true
                                        
                                        Text {
                                            id: instanceOperationText
                                            property bool hovered: false
                                            anchors.right: parent.right
                                            anchors.rightMargin: root.actionRightMargin
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("View")
                                            font.pixelSize: root.actionTextPixelSize
                                            font.weight: root.actionTextWeight
                                            font.underline: false
                                            color: Theme.Colors.primary

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onEntered: instanceOperationText.hovered = true
                                                onExited: instanceOperationText.hovered = false
                                                onClicked: {
                                                    // Populate instance dialog with data
                                                    instanceDetailDialog.instanceId = modelData.instanceCode || modelData.id || ""
                                                    instanceDetailDialog.status = modelData.status || ""
                                                    instanceDetailDialog.creator = resolveInstanceApplicantText(modelData)
                                                    var rawSizeBytes = Theme.Utils.normalizeVolumeToBytes(modelData.volumnSize !== undefined ? modelData.volumnSize : modelData.size)
                                                    instanceDetailDialog.instanceSize = Theme.Utils.formatSize(rawSizeBytes)
                                                    // Pass createdAt (updated to approval time) to details dialog
                                                    instanceDetailDialog.appliedTime = Theme.Utils.formatDateTime(modelData.createdAt || modelData.appliedTime)
                                                    instanceDetailDialog.instanceRemainingDays = formatRemainingDays(modelData)
                                                    instanceDetailDialog.instanceCost = modelData.cost || "15,500"  // Instance cost
                                                    
                                                    var whitelistData = []
                                                    instanceDetailDialog.whitelistApps = whitelistData

                                                    // Determine if current user should see approver view
                                                    // Logic: Check if the instance creator is in current user's visible user list
                                                    var isApprover = false
                                                    if (root.currentUser && isInstanceCreatorVisibleUser(modelData)) {
                                                        // Check if current user is the domain creator (has all visible users)
                                                        if (root.isCurrentUserDomainCreator(root.domainData)) {
                                                            isApprover = true
                                                        }
                                                    }
                                                    
                                                    // Set isApproverView based on whether user is approver
                                                    instanceDetailDialog.isApproverView = isApprover
                                                    
                                                    // Show action buttons only for pending status, when user is domain creator, and domain is not closed
                                                    instanceDetailDialog.showActionButtons = (modelData.status === "待审核" && !root.isDomainReadOnly)
                                                    
                                                    // Reset to first page
                                                    instanceDetailDialog.currentPage = 1
                                                    
                                                    instanceDetailDialog.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }

                        // Pagination Control
                        Item {
                            width: parent.width
                            height: 36
                            visible: relatedInstancesCard.totalPages > 1
                            
                            Component.onCompleted: {
                            }

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 10
                                spacing: 6

                                // Previous
                                Text {
                                    text: "<"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (relatedInstancesCard.currentPage <= 1) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: relatedInstancesCard.currentPage > 1 && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: relatedInstancesCard.currentPage > 1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: relatedInstancesCard.currentPage--
                                    }
                                }

                                Repeater {
                                    model: relatedInstancesCard.getVisiblePages()
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        property int pageNum: modelData
                                        property bool isEllipsis: pageNum === -1
                                        property bool hovered: false
                                        property bool pressed: false
                                        property bool isCurrent: pageNum === relatedInstancesCard.currentPage
                                        color: {
                                            if (pressed && !isCurrent) return "#1b5fa8"
                                            if (hovered) return "#e3f2fd"
                                            return "white"
                                        }
                                        border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isEllipsis ? "..." : pageNum
                                            font.pixelSize: 12
                                            color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !isEllipsis
                                            cursorShape: !isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: { parent.hovered = false; parent.pressed = false }
                                            onPressed: if (!parent.isCurrent) parent.pressed = true
                                            onReleased: parent.pressed = false
                                            onClicked: if (!parent.isCurrent) relatedInstancesCard.currentPage = pageNum
                                        }
                                    }
                                }

                                // Next
                                Text {
                                    text: ">"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (relatedInstancesCard.currentPage >= relatedInstancesCard.totalPages) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: relatedInstancesCard.currentPage < relatedInstancesCard.totalPages && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: relatedInstancesCard.currentPage < relatedInstancesCard.totalPages
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: relatedInstancesCard.currentPage++
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Application Whitelist Audit Card - dynamic height based on audit count
            Rectangle {
                id: appWhitelistAuditCard
                width: parent.width
                property int titleHeight: 28
                property int tableHeaderHeight: 32
                property int rowHeight: 32
                property int margins: 32
                property int spacing: 12
                property int auditCount: root.domainData.appWhitelistAudits ? root.domainData.appWhitelistAudits.length : 0

                property int currentPage: 1
                property int itemsPerPage: 3
                property int totalPages: auditCount > 0 ? Math.ceil(auditCount * 1.0 / itemsPerPage) : 0
                readonly property int colApplyCode: 100    // 申请编号 (固定)
                readonly property int colApplicant: 106     // 申请方 (均匀分布)
                readonly property int colAppName: 106      // 应用名称 (均匀分布)
                readonly property int colStatus: 106       // 状态 (均匀分布)
                readonly property int colTime: 106         // 申请时间 (均匀分布)
                readonly property int colInstance: 106     // 实例名称 (均匀分布)
                readonly property int colAction: 82        // 操作 (固定)

                function normalizeCurrentPage() {
                    var total = appWhitelistAuditCard.totalPages
                    if (total <= 0) {
                        if (appWhitelistAuditCard.currentPage !== 1) {
                            appWhitelistAuditCard.currentPage = 1
                        }
                        return
                    }
                    if (appWhitelistAuditCard.currentPage < 1) {
                        appWhitelistAuditCard.currentPage = 1
                        return
                    }
                    if (appWhitelistAuditCard.currentPage > total) {
                        appWhitelistAuditCard.currentPage = total
                    }
                }

                onAuditCountChanged: normalizeCurrentPage()
                onTotalPagesChanged: normalizeCurrentPage()
                
                function getPagedAudits() {
                    var list = root.domainData.appWhitelistAudits || []
                    var start = (appWhitelistAuditCard.currentPage - 1) * appWhitelistAuditCard.itemsPerPage
                    return list.slice(start, Math.min(start + appWhitelistAuditCard.itemsPerPage, list.length))
                }

                function getVisiblePages() {
                   var total = appWhitelistAuditCard.totalPages
                   var current = appWhitelistAuditCard.currentPage
                   var pages = []
                   if (total <= 7) {
                       for (var i = 1; i <= total; i++) pages.push(i)
                   } else {
                       if (current <= 4) {
                           for (var i = 1; i <= 5; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       } else if (current >= total - 3) {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = total - 4; i <= total; i++) pages.push(i)
                       } else {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = current - 1; i <= current + 1; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       }
                   }
                   return pages
                }
                
                height: margins + titleHeight + spacing + (auditCount > 0 ? (tableHeaderHeight + (rowHeight * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
                radius: 14
                color: Theme.Colors.backgroundWhite
                antialiasing: true
                smooth: true
                clip: true
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Header with title
                    Item {
                        width: parent.width
                        height: 28
                        
                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("App Whitelist Review")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                    }
                    
                    // Table or empty state
                    Column {
                        width: parent.width
                        spacing: 0
                        
                        // Empty state - show icon when audit list is empty
                        Item {
                            width: parent.width
                            height: 30
                            visible: appWhitelistAuditCard.auditCount === 0
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 16
                                    height: 16
                                    source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                                    sourceSize: Qt.size(16, 16)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No Data")
                                    font.pixelSize: 11
                                    color: "#90A1B9"
                                }
                            }
                        }
                        
                        // Table header
                        Rectangle {
                            width: parent.width
                            height: 32
                            property bool hovered: false
                            color: hovered ? "#f2f7fd" : "transparent"
                            visible: appWhitelistAuditCard.auditCount > 0
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Colors.borderSlate
                            }

                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: parent.hovered = hovered
                            }
                            
                            RowLayout {
                                id: appWhitelistHeaderRow
                                anchors.fill: parent
                                spacing: 0
                                property int titleGap: Math.max(6, appWhitelistAuditCard.colApplyCode - applicationIdText.implicitWidth)

                                Item {
                                    Layout.preferredWidth: appWhitelistAuditCard.colApplyCode
                                    Layout.fillHeight: true
                                    SelectableText {
                                        id: applicationIdText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Application ID")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Applicant")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("App Name")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Instance Name")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                // Application Time column
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Application Time")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                // Status column
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 54  // 向右移动1厘米 (约37.8像素)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Status")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: appWhitelistAuditCard.colAction
                                    Layout.fillHeight: true
                                    SelectableText {
                                        anchors.right: parent.right
                                        anchors.rightMargin: root.actionRightMargin
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Actions")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                            }
                        }
                        
                        // Table body
                        Column {
                            width: parent.width
                            height: Math.max(96, 32 * Math.min(appWhitelistAuditCard.itemsPerPage, Math.max(0, appWhitelistAuditCard.auditCount - (appWhitelistAuditCard.currentPage - 1) * appWhitelistAuditCard.itemsPerPage)))
                            spacing: 0
                            visible: appWhitelistAuditCard.auditCount > 0
                            
                            Repeater {
                                model: {
                                    var list = root.domainData.appWhitelistAudits || []
                                    var start = (appWhitelistAuditCard.currentPage - 1) * appWhitelistAuditCard.itemsPerPage
                                    return list.slice(start, Math.min(start + appWhitelistAuditCard.itemsPerPage, list.length))
                                }
                            
                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    property bool hovered: false
                                    color: hovered ? "#f2f7fd" : "transparent"
                                
                                    HoverHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onHoveredChanged: parent.hovered = hovered
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        // 申请编号
                                        Item {
                                            Layout.preferredWidth: appWhitelistAuditCard.colApplyCode
                                            Layout.fillHeight: true
                                            CenteredTooltipText {
                                                anchors.fill: parent
                                                value: modelData.applyCode || modelData.id || ""
                                                textPixelSize: 14
                                                textColor: Theme.Colors.textLabel
                                                leftMargin: 6
                                                rightMargin: 6
                                                beforeChars: 6
                                                afterChars: 4
                                                boundsItem: appWhitelistAuditCard
                                            }
                                        }

                                        // 申请方
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            CenteredTooltipText {
                                                anchors.fill: parent
                                                value: modelData.applicantUserName || modelData.applicant || ""
                                                textPixelSize: 14
                                                textColor: Theme.Colors.textLabel
                                                leftMargin: 6
                                                rightMargin: 6
                                                beforeChars: 6
                                                afterChars: 4
                                                boundsItem: appWhitelistAuditCard
                                            }
                                        }

                                        // 应用名称
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            CenteredTooltipText {
                                                anchors.fill: parent
                                                value: modelData.appName || ""
                                                textPixelSize: 14
                                                textColor: Theme.Colors.textLabel
                                                leftMargin: 6
                                                rightMargin: 6
                                                beforeChars: 6
                                                afterChars: 4
                                                boundsItem: appWhitelistAuditCard
                                            }
                                        }

                                        // 实例名称
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            CenteredTooltipText {
                                                anchors.fill: parent
                                                value: modelData.instanceName || ""
                                                textPixelSize: 14
                                                textColor: Theme.Colors.textLabel
                                                leftMargin: 6
                                                rightMargin: 6
                                                beforeChars: 6
                                                afterChars: 4
                                                boundsItem: appWhitelistAuditCard
                                            }
                                        }

                                        // 申请时间
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Theme.Utils.formatDateTime(modelData.applyTime || modelData.createdAt || "")
                                                font.pixelSize: 14
                                                color: Theme.Colors.textLabel
                                            }
                                        }

                                        // 状态
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 54
                                                anchors.verticalCenter: parent.verticalCenter
                                                implicitWidth: statusText.implicitWidth + 12
                                                implicitHeight: 24
                                                radius: 6
                                                property var auditStatusStyle: Theme.Colors.getStatusColor(modelData.status || "")
                                                color: auditStatusStyle.bg
                                                border.color: auditStatusStyle.border
                                                border.width: 1
                                                Text {
                                                    id: statusText
                                                    anchors.centerIn: parent
                                                    text: getStatusText(modelData.status)
                                                    font.pixelSize: 14
                                                    font.weight: Font.Medium
                                                    color: parent.auditStatusStyle.text
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }

                                        // 操作
                                        Item {
                                            Layout.preferredWidth: appWhitelistAuditCard.colAction
                                            Layout.fillHeight: true

                                            Text {
                                                id: appWhitelistOperationText
                                                property bool hovered: false
                                                anchors.right: parent.right
                                                anchors.rightMargin: root.actionRightMargin
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: qsTr("View")
                                                font.pixelSize: root.actionTextPixelSize
                                                font.weight: root.actionTextWeight
                                                font.underline: false
                                            color: Theme.Colors.primary

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onEntered: appWhitelistOperationText.hovered = true
                                                onExited: appWhitelistOperationText.hovered = false
                                                    onClicked: {
                                                        appWhitelistDetailDialog.instanceCode = modelData.applyCode || ""
                                                        appWhitelistDetailDialog.applyCode = modelData.applyCode || ""
                                                        appWhitelistDetailDialog.status = modelData.status || ""
                                                        appWhitelistDetailDialog.creator = modelData.applicantUserName || modelData.applicant || ""
                                                        appWhitelistDetailDialog.instanceName = modelData.instanceName || ""
                                                        appWhitelistDetailDialog.appliedTime = Theme.Utils.formatDateTime(modelData.applyTime || "")
                                                        appWhitelistDetailDialog.duration = modelData.duration ? (modelData.duration + "个月") : "-"
                                                        appWhitelistDetailDialog.cost = modelData.cost || ""
                                                        var whlProcs = resolveWhitelistProcessesByRow(modelData)
                                                        appWhitelistDetailDialog.appName = (whlProcs.length > 0 ? (whlProcs[0].masterFileName || "") : "") || "应用名称"
                                                        appWhitelistDetailDialog.processes = whlProcs
                                                        appWhitelistDetailDialog.selectedProcessIndex = 0
                                                        appWhitelistDetailDialog.fileCode = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileCode || "") : ""
                                                        appWhitelistDetailDialog.fileHash = (whlProcs.length > 0 && whlProcs[0]) ? (whlProcs[0].fileHash || "") : ""
                                                        appWhitelistDetailDialog.open()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Pagination Control
                        Item {
                            width: parent.width
                            height: 36
                            visible: appWhitelistAuditCard.auditCount > 0 && appWhitelistAuditCard.totalPages > 1

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 10
                                spacing: 6

                                // Previous
                                Text {
                                    text: "<"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (appWhitelistAuditCard.currentPage <= 1) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: appWhitelistAuditCard.currentPage > 1 && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: appWhitelistAuditCard.currentPage > 1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: appWhitelistAuditCard.currentPage--
                                    }
                                }

                                Repeater {
                                    model: appWhitelistAuditCard.getVisiblePages()
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        property int pageNum: modelData
                                        property bool isEllipsis: pageNum === -1
                                        property bool hovered: false
                                        property bool pressed: false
                                        property bool isCurrent: pageNum === appWhitelistAuditCard.currentPage
                                        color: {
                                            if (pressed && !isCurrent) return "#1b5fa8"
                                            if (hovered) return "#e3f2fd"
                                            return "white"
                                        }
                                        border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isEllipsis ? "..." : pageNum
                                            font.pixelSize: 12
                                            color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !isEllipsis
                                            cursorShape: !isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: { parent.hovered = false; parent.pressed = false }
                                            onPressed: if (!parent.isCurrent) parent.pressed = true
                                            onReleased: parent.pressed = false
                                            onClicked: if (!parent.isCurrent) appWhitelistAuditCard.currentPage = pageNum
                                        }
                                    }
                                }

                                // Next
                                Text {
                                    text: ">"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (appWhitelistAuditCard.currentPage >= appWhitelistAuditCard.totalPages) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: appWhitelistAuditCard.currentPage < appWhitelistAuditCard.totalPages && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: appWhitelistAuditCard.currentPage < appWhitelistAuditCard.totalPages
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: appWhitelistAuditCard.currentPage++
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Export Audit Card - dynamic height based on audit count
            Rectangle {
                id: exportAuditCard
                width: parent.width
                // Dynamic height calculation:
                // 48px (top + bottom margins) + 24px (title) + 16px (spacing) + (if has audits: 40px table header + 38px * audit count, else: just enough for "无" text)
                property int titleHeight: 28  // Title height
                property int tableHeaderHeight: 32  // Table header
                property int rowHeight: 32  // Each audit row height
                property int margins: 32  // Top and bottom margins (16px * 2)
                property int spacing: 12  // Spacing between title and table
                property int auditCount: root.domainData.exportAudits ? root.domainData.exportAudits.length : 0

                // Pagination properties
                property int currentPage: 1
                property int itemsPerPage: 3
                property int totalPages: auditCount > 0 ? Math.ceil(auditCount * 1.0 / itemsPerPage) : 0

                readonly property int colApplyCode: 95        // 申请编号
                readonly property int colApplicant: 80       // 申请人
                readonly property int colFileName: 80       // 文件名称
                readonly property int colFileSize: 70       // 文件大小
                readonly property int colInstance: 80       // 实例名称
                readonly property int colTime: 85           // 申请时间
                readonly property int colStatus: 70         // 状态
                readonly property int colAction: 82         // 操作 (确保显示)
                
                // 总宽度 = 95 + 80×4 + 85 + 70 + 82 = 632px (确保所有8列都能显示)

                function normalizeCurrentPage() {
                    var total = exportAuditCard.totalPages
                    if (total <= 0) {
                        if (exportAuditCard.currentPage !== 1) {
                            exportAuditCard.currentPage = 1
                        }
                        return
                    }

                    if (exportAuditCard.currentPage < 1) {
                        exportAuditCard.currentPage = 1
                        return
                    }

                    if (exportAuditCard.currentPage > total) {
                        exportAuditCard.currentPage = total
                    }
                }

                onAuditCountChanged: normalizeCurrentPage()
                onTotalPagesChanged: normalizeCurrentPage()
                
                function getPagedAudits() {
                    var list = root.domainData.exportAudits || []
                    var start = (exportAuditCard.currentPage - 1) * exportAuditCard.itemsPerPage
                    return list.slice(start, Math.min(start + exportAuditCard.itemsPerPage, list.length))
                }

                function getVisiblePages() {
                   var total = exportAuditCard.totalPages
                   var current = exportAuditCard.currentPage
                   var pages = []
                   if (total <= 7) {
                       for (var i = 1; i <= total; i++) pages.push(i)
                   } else {
                       if (current <= 4) {
                           for (var i = 1; i <= 5; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       } else if (current >= total - 3) {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = total - 4; i <= total; i++) pages.push(i)
                       } else {
                           pages.push(1)
                           pages.push(-1)
                           for (var i = current - 1; i <= current + 1; i++) pages.push(i)
                           pages.push(-1)
                           pages.push(total)
                       }
                   }
                   return pages
                }
                
                height: margins + titleHeight + spacing + (auditCount > 0 ? (tableHeaderHeight + (rowHeight * itemsPerPage) + (totalPages > 1 ? 36 : 0)) : 30)
                radius: 14
                color: Theme.Colors.backgroundWhite
                antialiasing: true
                smooth: true
                clip: true
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Header with title
                    Item {
                        width: parent.width
                        height: 28
                        
                        // Title
                        SelectableText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("File Export Review")
                            font.pixelSize: 14
                            color: "#62748e"
                        }
                    }
                    
                    // Export audit table or empty state
                    Column {
                        width: parent.width
                        spacing: 0
                        
                        // Empty state - show icon when audit list is empty
                        Item {
                            width: parent.width
                            height: 30
                            visible: exportAuditCard.auditCount === 0
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 16
                                    height: 16
                                    source: Qt.resolvedUrl("icons/icon-empty-state.svg")
                                    sourceSize: Qt.size(16, 16)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No Data")
                                    font.pixelSize: 11
                                    color: "#90A1B9"
                                }
                            }
                        }
                        
                        // Table header - only show when audit list is not empty
                        Rectangle {
                            width: parent.width
                            height: 32
                            property bool hovered: false
                            color: hovered ? "#f2f7fd" : "transparent"
                            visible: exportAuditCard.auditCount > 0
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Colors.borderSlate
                            }

                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: parent.hovered = hovered
                            }
                            
                            Row {
                                anchors.fill: parent

                                Item {
                                    width: exportAuditCard.colApplyCode
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Application ID")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    width: exportAuditCard.colApplicant
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Applicant")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    width: exportAuditCard.colFileName
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("文件名称")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    width: exportAuditCard.colFileSize
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("File Size")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    width: exportAuditCard.colInstance
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Instance Name")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                // Application Time column (3rd from last)
                                Item {
                                    width: exportAuditCard.colTime
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Application Time")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                        width: Math.max(0, parent.width - 12)
                                        elide: Text.ElideRight
                                    }
                                }

                                // Status column (2nd from last)
                                Item {
                                    width: exportAuditCard.colStatus
                                    height: parent.height
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("状态")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }

                                Item {
                                    width: exportAuditCard.colAction
                                    height: parent.height
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 0  // 向右移动，设置右边距为0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("操作")
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: Theme.Colors.textLabel
                                    }
                                }
                            }
                        }
                        
                        // Table body - only show when audit list is not empty
                        Column {
                            width: parent.width
                            height: Math.max(96, 32 * Math.min(exportAuditCard.itemsPerPage, Math.max(0, exportAuditCard.auditCount - (exportAuditCard.currentPage - 1) * exportAuditCard.itemsPerPage)))
                            spacing: 0
                            visible: exportAuditCard.auditCount > 0
                            
                            Repeater {
                                model: {
                                    var list = root.domainData.exportAudits || []
                                    var start = (exportAuditCard.currentPage - 1) * exportAuditCard.itemsPerPage
                                    return list.slice(start, Math.min(start + exportAuditCard.itemsPerPage, list.length))
                                }
                            
                                Rectangle {
                                    width: parent.width
                                    height: 32
                                property bool hovered: false
                                color: hovered ? "#f2f7fd" : "transparent"
                                
                                HoverHandler {
                                    acceptedDevices: PointerDevice.Mouse
                                    onHoveredChanged: parent.hovered = hovered
                                }
                                
                                Row {
                                    anchors.fill: parent

                                    // 申请编号
                                    Item {
                                        width: exportAuditCard.colApplyCode
                                        height: parent.height
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.applyCode || modelData.id || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 4
                                            boundsItem: exportAuditCard
                                        }
                                    }

                                    // 申请方
                                    Item {
                                        width: exportAuditCard.colApplicant
                                        height: parent.height
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.applicantUserName || modelData.applicant || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 4
                                            boundsItem: exportAuditCard
                                        }
                                    }

                                    // 文件名称
                                    Item {
                                        width: exportAuditCard.colFileName
                                        height: parent.height
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.fileName || modelData.file_name || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 4
                                            boundsItem: exportAuditCard
                                        }
                                    }

                                    // 文件大小
                                    Item {
                                        width: exportAuditCard.colFileSize
                                        height: parent.height
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: formatFileSizeLowercase(modelData.fileSize) || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 3
                                            boundsItem: exportAuditCard
                                        }
                                    }

                                    // 实例名称
                                    Item {
                                        width: exportAuditCard.colInstance
                                        height: parent.height
                                        CenteredTooltipText {
                                            anchors.fill: parent
                                            value: modelData.instanceName || ""
                                            textPixelSize: 14
                                            textColor: Theme.Colors.textLabel
                                            leftMargin: 6
                                            rightMargin: 6
                                            beforeChars: 6
                                            afterChars: 4
                                            boundsItem: exportAuditCard
                                        }
                                    }

                                    // 申请时间 (倒数第三列)
                                    Item {
                                        width: exportAuditCard.colTime
                                        height: parent.height
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Theme.Utils.formatDateTime(modelData.applyTime || modelData.createdAt || "")
                                            font.pixelSize: 14
                                            color: Theme.Colors.textLabel
                                        }
                                    }

                                    // 状态 (倒数第二列)
                                    Item {
                                        width: exportAuditCard.colStatus
                                        height: parent.height
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitWidth: exportStatusText.implicitWidth + 12
                                            implicitHeight: 24
                                            radius: 6
                                            property var auditStatusStyle: Theme.Colors.getStatusColor(modelData.status || "待审核")
                                            color: auditStatusStyle.bg
                                            border.color: auditStatusStyle.border
                                            border.width: 1
                                            Text {
                                                id: exportStatusText
                                                anchors.centerIn: parent
                                                text: window.translateStatus(modelData.status || "")
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                color: parent.auditStatusStyle.text
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }

                                    // 操作
                                    Item {
                                        width: exportAuditCard.colAction
                                        height: parent.height
                                        Text {
                                            id: exportOperationText
                                            anchors.right: parent.right
                                            anchors.rightMargin: root.actionRightMargin
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("View")
                                            font.pixelSize: root.actionTextPixelSize
                                            font.weight: root.actionTextWeight
                                            property bool hovered: false
                                            font.underline: false
                                            color: Theme.Colors.primary
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: exportOperationText.hovered = true
                                                onExited: exportOperationText.hovered = false
                                                onClicked: {
                                                    exportDetailDialog.exportId = modelData.applyCode || modelData.id || ""
                                                    exportDetailDialog.applicant = modelData.applicantUserName || modelData.applicant || ""
                                                    exportDetailDialog.fileSize = Number(modelData.fileSize) || 0
                                                    exportDetailDialog.status = modelData.status || "待审核"
                                                    exportDetailDialog.applyTime = modelData.applyTime || ""
                                                    exportDetailDialog.instanceName = modelData.instanceName || ""
                                                    exportDetailDialog.files = modelData.files || []
                                                    exportDetailDialog.reason = modelData.reason || ""
                                                    exportDetailDialog.fileCode = modelData.fileCode || ""
                                                    exportDetailDialog.fileHash = modelData.fileHash || ""
                                                    exportDetailDialog.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }

                        // Pagination Control
                        Item {
                            width: parent.width
                            height: 36
                            visible: exportAuditCard.auditCount > 0 && exportAuditCard.totalPages > 1

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 10
                                spacing: 6

                                // Previous
                                Text {
                                    text: "<"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (exportAuditCard.currentPage <= 1) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: exportAuditCard.currentPage > 1 && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: exportAuditCard.currentPage > 1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: exportAuditCard.currentPage--
                                    }
                                }

                                Repeater {
                                    model: exportAuditCard.getVisiblePages()
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        property int pageNum: modelData
                                        property bool isEllipsis: pageNum === -1
                                        property bool hovered: false
                                        property bool pressed: false
                                        property bool isCurrent: pageNum === exportAuditCard.currentPage
                                        color: {
                                            if (pressed && !isCurrent) return "#1b5fa8"
                                            if (hovered) return "#e3f2fd"
                                            return "white"
                                        }
                                        border.color: isCurrent ? "#1b5fa8" : "#dfe3e8"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: isEllipsis ? "..." : pageNum
                                            font.pixelSize: 12
                                            color: parent.pressed && !parent.isCurrent ? "white" : "#212b36"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !isEllipsis
                                            cursorShape: !isEllipsis ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: { parent.hovered = false; parent.pressed = false }
                                            onPressed: if (!parent.isCurrent) parent.pressed = true
                                            onReleased: parent.pressed = false
                                            onClicked: if (!parent.isCurrent) exportAuditCard.currentPage = pageNum
                                        }
                                    }
                                }

                                // Next
                                Text {
                                    text: ">"
                                    font.pixelSize: 14
                                    property bool hovered: false
                                    property bool pressed: false
                                    color: {
                                        if (exportAuditCard.currentPage >= exportAuditCard.totalPages) return "#919eab"
                                        if (pressed) return "white"
                                        if (hovered) return "#1b5fa8"
                                        return "#212b36"
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 3
                                        visible: exportAuditCard.currentPage < exportAuditCard.totalPages && (parent.hovered || parent.pressed)
                                        color: parent.pressed ? "#1b5fa8" : "#e3f2fd"
                                        z: -1
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: exportAuditCard.currentPage < exportAuditCard.totalPages
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: exportAuditCard.currentPage++
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Disable button - only show when status is not "已关闭" and user is creator
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
            visible: !root.isDomainReadOnly  // Show only when domain is active and current user is creator
            implicitWidth: disableText.implicitWidth + 40  // Auto-size to content with padding
                
                Text {
                    id: disableText
                    anchors.centerIn: parent
                    text: qsTr("Disable This Security Domain")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: parent.pressed ? "#900006" : (parent.hovered ? "#c50009" : "#e7000b")
                }
                
            MouseArea {
                anchors.fill: parent
                enabled: !root.isDomainReadOnly
                hoverEnabled: true
                cursorShape: (!root.isDomainReadOnly) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: {
                    deactivateDialog.open()
                }
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onPressed: parent.pressed = true
                onReleased: parent.pressed = false
            }
        }
        }
    }

    // Function to handle domain deactivation
    function handleDeactivateDomain() {
        if (root.isDomainReadOnly) {
            return
        }

        // Prevent duplicate clicks - check if already pending
        if (deactivateDomainState.isPending) {
            return
        }
        
        var domainCode = root.currentDomainCode || ""
        if (!domainCode) {
            return
        }

        var pubKey = root.domainPubKey || ""

        deactivateDomainState.isPending = true
        deactivateDomainState.pendingDomainPubKey = pubKey
        deactivateDomainState.pendingDomainCode = domainCode

        // 调用 DSCC 接口关闭安全域，结果在 main.qml 的 onDomainClosed / onDomainCloseFailed 中处理
        DsccBridge.closeDomain(domainCode)
    }
    
    function getStatusText(status) {
        return status || ""
    }

    function parseDateTime(value) {
        if (!value) {
            return null
        }
        if (value instanceof Date) {
            return value
        }
        var parsed = null
        if (typeof value === "string") {
            parsed = new Date(value.replace(" ", "T"))
            if (isNaN(parsed.getTime())) {
                parsed = new Date(value.replace(/-/g, "/"))
            }
        } else {
            parsed = new Date(value)
        }
        return isNaN(parsed.getTime()) ? null : parsed
    }

    function parseDurationMonths(durationValue) {
        if (durationValue === undefined || durationValue === null) {
            return 0
        }
        if (typeof durationValue === "number") {
            return durationValue
        }
        if (typeof durationValue === "string") {
            var match = durationValue.match(/(\d+)/)
            if (match) {
                return parseInt(match[1])
            }
        }
        return 0
    }

    function calculateInstanceExpiryDate(createdAt, durationValue) {
        if (!createdAt) {
            return null
        }
        var months = parseDurationMonths(durationValue)
        if (!months || months <= 0) {
            return null
        }

        var createdDate = parseDateTime(createdAt)
        if (!createdDate) {
            return null
        }

        // 按自然月计算到期时间，确保不出现2月30日等错误
        // 1月31日+ 1个月 = 2月28日（自然月）
        var expiryDate = new Date(createdDate.getTime())
        var targetMonth = expiryDate.getMonth() + months
        var yearsToAdd = Math.floor(targetMonth / 12)
        var newMonth = targetMonth % 12
        
        expiryDate.setFullYear(expiryDate.getFullYear() + yearsToAdd)
        
        // 处理月末溢出（如1月31日 + 1个月 = 2月28/29日）
        var originalDay = createdDate.getDate()
        expiryDate.setMonth(newMonth, 1) // 先设为目标月第1天
        
        // 获取目标月的最后一天
        var lastDayOfNewMonth = new Date(expiryDate.getFullYear(), newMonth + 1, 0).getDate()
        
        // 设为原日期或月末最后一天（取较小值）
        expiryDate.setDate(Math.min(originalDay, lastDayOfNewMonth))
        
        // 保留时间部分
        expiryDate.setHours(createdDate.getHours())
        expiryDate.setMinutes(createdDate.getMinutes())
        expiryDate.setSeconds(createdDate.getSeconds())
        
        return isNaN(expiryDate.getTime()) ? null : expiryDate
    }

    function formatRemainingDays(instance) {
        if (!instance) {
            return "-"
        }
        
        var status = instance.status || ""
        var durationMonths = parseDurationMonths(instance.duration)
        if (!durationMonths) {
            return "-"
        }

        // 待审核/已授权/运行中：统一按自然月计算到期时间，然后计算剩余天数
        // 待审核状态使用申请时间作为基准，审批后使用审批时间
        var startTime = instance.createdAt || instance.appliedTime

        var expiryDate = null
        if (instance.expiresAt) {
            expiryDate = parseDateTime(instance.expiresAt)
        }

        if (!expiryDate) {
            expiryDate = calculateInstanceExpiryDate(startTime, durationMonths)
        }

        if (!expiryDate || isNaN(expiryDate.getTime())) {
            return "-"
        }
        
        // 剩余时长 = 到期时间 - 当前时间（向上取整天数）
        var now = new Date()
        var diff = expiryDate.getTime() - now.getTime()
        if (diff <= 0) {
            return "0天"
        }
        var msPerDay = 24 * 60 * 60 * 1000
        var remainingDays = Math.ceil(diff / msPerDay)
        return remainingDays + "天"
    }

    function formatFileSizeLowercase(sizeInBytes) {
        var bytes = Number(sizeInBytes)
        if (isNaN(bytes) || bytes < 0) {
            return "-"
        }
        if (bytes === 0) {
            return "0.00 b"
        }

        var units = ["b", "kb", "mb", "gb", "tb", "pb"]
        var value = bytes
        var unitIndex = 0
        while (value >= 1024 && unitIndex < units.length - 1) {
            value = value / 1024
            unitIndex++
        }

        return value.toFixed(2) + " " + units[unitIndex]
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DsccBridge 数据加载信号：填充 domainData 各字段
    // ──────────────────────────────────────────────────────────────────────────
    Connections {
        target: DsccBridge
        ignoreUnknownSignals: true

        function onDomainSummaryLoaded(domainCode, summary) {
            if (domainCode !== root.currentDomainCode) return
            if (!summary || Object.keys(summary).length === 0) return
            var updated = Object.assign({}, root.domainData, summary)
            // 保持 visibleUsers / instances / appWhitelistAudits / exportAudits 不被覆盖
            if (root.domainData) {
                if (summary.visibleUsers === undefined && root.domainData.visibleUsers !== undefined)
                    updated.visibleUsers = root.domainData.visibleUsers
                if (root.domainData.instances !== undefined)
                    updated.instances = root.domainData.instances
                if (root.domainData.appWhitelistAudits !== undefined)
                    updated.appWhitelistAudits = root.domainData.appWhitelistAudits
                if (root.domainData.exportAudits !== undefined)
                    updated.exportAudits = root.domainData.exportAudits
            }
            root.domainData = updated
            if (summary.name && summary.name !== root.domainName) root.domainName = summary.name
            if (summary.pubKey && summary.pubKey !== root.domainPubKey) root.domainPubKey = summary.pubKey
        }

        function onInstancesLoaded(domainCode, instances) {
            if (domainCode !== root.currentDomainCode) return
            var updated = Object.assign({}, root.domainData)
            updated.instances = sortByTimeDesc(normalizeInstances(instances || []), "createdAt", "appliedTime")
            root.domainData = updated
        }

        function onAuditsLoaded(domainCode, applyType, audits) {
            if (domainCode !== root.currentDomainCode) return
            var updated = Object.assign({}, root.domainData)
            if (applyType === 1) {
                updated.appWhitelistAudits = sortByTimeDesc(dedupeWhitelistAudits(audits || []), "applyTime", "createdAt")
            } else if (applyType === 2) {
                updated.exportAudits = sortByTimeDesc(dedupeExportAudits(audits || []), "applyTime", "createdAt")
            }
            updated._syncedFromBackend = true
            root.domainData = updated
            auditDataLoaded = canRenderAuditEmptyState(root.domainData)
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DsccBridge 写操作结果信号：可见用户/描述/关闭安全域
    // 全部采用"成功后调用 loadXxx 局部刷新"的统一策略
    // ──────────────────────────────────────────────────────────────────────────
    Connections {
        target: DsccBridge

        function onAddUserToDomainSuccess(operationId, domainCode, userId) {
            if (domainCode !== root.currentDomainCode) return
            root.pendingAddUserFullInfo = null
            root.visibleUserOperationState_busy = false
            DsccBridge.loadDomainSummary(root.currentDomainCode)
        }

        function onAddUserToDomainFailed(operationId, domainCode, userId, notification) {
            if (domainCode !== root.currentDomainCode) return
            root.pendingAddUserFullInfo = null
            root.visibleUserOperationState_busy = false
            var errorMessage = DsccBridge.notificationMessage(notification, "添加用户失败")
            window.showError(errorMessage || "添加用户失败", "添加可见用户")
        }

        function onRemoveUserFromDomainSuccess(operationId, domainCode, userId) {
            if (domainCode !== root.currentDomainCode) return
            root.removeUserState_pendingRemovedAccount = ""
            root.removeUserState_pendingRemovedAuthUserId = ""
            root.removeUserState_pendingDomainPubKey = ""
            root.removeUserState_pendingDomainCode = ""
            root.visibleUserOperationState_busy = false
            DsccBridge.loadDomainSummary(root.currentDomainCode)
        }

        function onRemoveUserFromDomainFailed(operationId, domainCode, userId, notification) {
            if (domainCode !== root.currentDomainCode) return
            root.removeUserState_pendingRemovedAccount = ""
            root.removeUserState_pendingRemovedAuthUserId = ""
            root.removeUserState_pendingDomainPubKey = ""
            root.removeUserState_pendingDomainCode = ""
            root.visibleUserOperationState_busy = false
            var errorMessage = DsccBridge.notificationMessage(notification, "移除用户失败")
            window.showError(errorMessage || "移除用户失败", "移除可见用户")
        }

        function onDomainDescUpdated(operationId, domainCode) {
            if (domainCode !== root.currentDomainCode) return
            root.isEditingDescription = false
            root.isDescriptionSaving = false
            DsccBridge.loadDomainSummary(root.currentDomainCode)
        }

        function onDomainDescUpdateFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode) return
            root.isDescriptionSaving = false
            var errorMessage = DsccBridge.notificationMessage(notification, "保存描述失败")
            window.showError(errorMessage || "保存描述失败", "修改描述")
        }

        function onDomainCloseFailed(operationId, domainCode, notification) {
            if (domainCode !== root.currentDomainCode) return
            deactivateDomainState.isPending = false
            deactivateDomainState.pendingDomainPubKey = ""
            deactivateDomainState.pendingDomainCode = ""
            var errorMessage = DsccBridge.notificationMessage(notification, "停用安全域失败")
            window.showError(errorMessage || "停用安全域失败", "停用安全域")
        }
        // 注意：onDomainClosed 成功的导航/刷新由 main.qml 统一处理（切换至 home + 刷新列表）

        function onAuditInstanceRequestSuccess(operationId, instanceCode) {
            root.instanceAuditPending = false
            DsccBridge.loadInstances(root.currentDomainCode)
        }

        function onAuditInstanceRequestFailed(operationId, instanceCode, notification) {
            root.instanceAuditPending = false
            var errorMessage = DsccBridge.notificationMessage(notification, "实例审核失败")
            window.showError(errorMessage || "实例审核失败", "实例审核")
            DsccBridge.loadInstances(root.currentDomainCode)
        }

        function onAuditRequestSuccess(operationId, auditCode, fileCode) {
            root.auditRequestPending = false
            DsccBridge.loadAudits(root.currentDomainCode, 1)
            DsccBridge.loadAudits(root.currentDomainCode, 2)
        }

        function onAuditRequestFailed(operationId, auditCode, fileCode, notification) {
            root.auditRequestPending = false
            var errorMessage = DsccBridge.notificationMessage(notification, "审核操作失败")
            window.showError(errorMessage || "审核操作失败", "审核操作")
            DsccBridge.loadAudits(root.currentDomainCode, 1)
            DsccBridge.loadAudits(root.currentDomainCode, 2)
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // First-visit onboarding guide
    // ──────────────────────────────────────────────────────────────────────────
    OnboardingGuide {
        id: onboardingGuide
        anchors.fill: parent
        z: 100
        flickable: detailScrollView.contentItem

        steps: [
            {
                title: qsTr("Encrypt Files to This Security Domain"),
                desc:  qsTr("Encrypt files into security-domain-exclusive encrypted files usable only within this domain's instances. Ensures secure file transfer and usage."),
                targetItem: encryptFileButton
            },
            {
                title: qsTr("Create Security Domain Instance"),
                desc:  qsTr("Create an encrypted storage instance on your device. Requires review and approval by the security domain creator before use."),
                targetItem: createInstanceButton
            },
            {
                title: qsTr("Visible User Management"),
                desc:  qsTr("Manage who can view this security domain and apply for instances. Creator can add or remove users anytime."),
                targetItem: visibleUsersCard
            },
            {
                title: qsTr("Related Security Domain Instances"),
                desc:  qsTr("View all instances under this security domain. Creator can review and manage the full lifecycle of instance applications.\n\nStatus:\n- Pending Review: Awaiting creator's approval\n- Authorized: Ready to start\n- Running: Instance is active\n- Rejected: Application denied\n- Ended: Instance stopped"),
                targetItem: relatedInstancesCard
            },
            {
                title: qsTr("App Whitelist Review"),
                desc:  qsTr("Review process/app whitelist applications. Approved apps can read/write files in the instance. Unapproved apps cannot access encrypted data."),
                targetItem: appWhitelistAuditCard
            },
            {
                title: qsTr("File Export Review"),
                desc:  qsTr("Review file export applications. Creator can approve or reject. Only approved files can be exported, ensuring data security."),
                targetItem: exportAuditCard
            }
        ]

        // Show the guide only when user clicks "View Feature Guide" button.
    }
}
