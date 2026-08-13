.pragma library

function trimText(value) {
    if (value === undefined || value === null) return ""
    return ("" + value).trim()
}

function toJsArray(value) {
    if (!value) return []
    if (Array.isArray(value)) return value.slice()
    if (typeof value === "string" || typeof value !== "object") return []
    var length = Number(value.length)
    if (isNaN(length) || length < 0) return []
    var result = []
    for (var i = 0; i < length; i++) result.push(value[i])
    return result
}

function normalizeInstanceId(value) {
    if (!value && value !== 0) return ""
    var normalized = ("" + value).trim()
    if (!normalized) return ""
    if (normalized[0] !== "I") normalized = "I" + normalized
    return normalized
}

function normalizeInstanceStatus(statusValue) {
    if (statusValue === undefined || statusValue === null) return ""
    var statusText = ("" + statusValue).trim()
    if (!statusText) return ""
    if (statusText === "0") return "待审核"
    if (statusText === "1") return "已授权"
    if (statusText === "2") return "已拒绝"
    if (statusText === "3") return "运行中"
    if (statusText === "4") return "已结束"
    if (statusText === "5") return "已暂停"
    if (statusText === "6") return "已过期"
    // 后端再扩状态码时，宁可显示一句看得懂的兜底，也不要把裸数字甩到状态列里
    // （"5"/"6" 就是这么漏出去过的）。已经是文案的值原样返回。
    if (/^\d+$/.test(statusText)) return "未知状态(" + statusText + ")"
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
    for (var i = 0; i < source.length; i++) normalized.push(normalizeInstance(source[i]))
    return normalized
}

function visibleUserMatchesInstance(visibleUser, instance) {
    if (!visibleUser || !instance) return false
    var userKeys = [
        visibleUser.authUserId, visibleUser.account, visibleUser.authUserName,
        visibleUser.displayName, visibleUser.user_id, visibleUser.user_name
    ]
    var instanceKeys = [
        instance.creatorUserId, instance.creatorUserName, instance.authUserId,
        instance.applicantAccount, instance.applicantUserId, instance.applicantUserName,
        instance.user
    ]
    for (var i = 0; i < userKeys.length; i++) {
        var userKey = (userKeys[i] || "").toString().trim()
        if (!userKey) continue
        for (var j = 0; j < instanceKeys.length; j++) {
            var instanceKey = (instanceKeys[j] || "").toString().trim()
            if (instanceKey && instanceKey === userKey) return true
        }
    }
    return false
}

function visibleUserText(visibleUser, fallback) {
    if (!visibleUser) return fallback || ""
    var authUserName = (visibleUser.authUserName || visibleUser.user_name || "").toString().trim()
    return authUserName || fallback || ""
}

function resolveInstanceApplicantText(instance, visibleUsers) {
    var fallback = (instance && (instance.creatorUserName || instance.applicantUserName || instance.creatorUserId || instance.authUserId || instance.applicantUserId || instance.user))
        ? (instance.creatorUserName || instance.applicantUserName || instance.creatorUserId || instance.authUserId || instance.applicantUserId || instance.user).toString().trim()
        : ""
    var users = toJsArray(visibleUsers)
    for (var i = 0; i < users.length; i++) {
        if (visibleUserMatchesInstance(users[i] || {}, instance)) {
            return visibleUserText(users[i], fallback)
        }
    }
    return fallback
}

function isInstanceCreatorVisibleUser(instance, visibleUsers) {
    var users = toJsArray(visibleUsers)
    for (var i = 0; i < users.length; i++) {
        if (visibleUserMatchesInstance(users[i], instance)) return true
    }
    return false
}

function resolveWhitelistProcessesByRow(row) {
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
    var rowSrc = row.processes || row.rawFiles || row.filePaths || []
    return normProcs(rowSrc)
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
        var key = applyCode ? ("AC|" + applyCode) : ["IX", instanceId, appName].join("|")
        if (!key || seen[key]) continue
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
        var key = applyCode ? ("AC|" + applyCode + "|" + fileCode) : ["IX", instanceId, fileCode, fileHash].join("|")
        if (!key || seen[key]) continue
        seen[key] = true
        deduped.push(row)
    }
    return deduped
}

function isDomainInactiveStatus(statusText) {
    var s = (statusText || "").trim()
    return s === "已关闭" || s === "创建失败" || s === "停用" || s === "已停用" || s === "停用中"
}

function isCurrentUserDomainCreator(currentUser, detail) {
    if (!currentUser || !detail) return false
    var userKeys = [trimText(currentUser.userName), trimText(currentUser.authUserId)]
    var creatorKeys = [
        trimText(detail.creatorUserId), trimText(detail.authUserId),
        trimText(detail.userId), trimText(detail.creatorUserName),
        trimText(detail.creator)
    ]
    for (var i = 0; i < userKeys.length; i++) {
        if (!userKeys[i]) continue
        for (var j = 0; j < creatorKeys.length; j++) {
            if (creatorKeys[j] && userKeys[i] === creatorKeys[j]) return true
        }
    }
    return false
}

function domainCreatorDisplayText(detail) {
    var d = detail || {}
    return trimText(d.creatorUserName) || trimText(d.creator)
        || trimText(d.creatorUserId || d.authUserId || d.userId)
}

function emptyDomainDetail(domainName, domainPubKey) {
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

function canRenderAuditEmptyState(detail) {
    var d = detail || {}
    if (!d) return false
    if (d._syncedFromBackend) return true
    if (Array.isArray(d.appWhitelistAudits) || Array.isArray(d.exportAudits)) return true

    var hasWhitelist = !!(d.appWhitelistAudits && d.appWhitelistAudits.length > 0)
    var hasExport = !!(d.exportAudits && d.exportAudits.length > 0)
    return hasWhitelist || hasExport
}

function formatPayerText(payerValue, creatorLabel, userLabel, emptyLabel) {
    var text = trimText(payerValue)
    if (!text) return emptyLabel || "-"
    if (text === "创建方" || text === "安全域创建方" || text === "创建者") return creatorLabel || "Creator"
    if (text === "使用方" || text === "安全域使用方" || text === "使用者") return userLabel || "User"
    return text
}
