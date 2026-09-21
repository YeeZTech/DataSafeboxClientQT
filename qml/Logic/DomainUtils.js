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

// 细粒度（带命令行）白名单申请里，有一条"申请文件"其实是命令行本身。
//
// 后端的 instance_apply_file 只有 fileName/fileHash/fileSize/isMaster 四列，
// 审核签名也只覆盖 fileHash，所以整条命令行被放进 fileName、其规范化摘要放进
// fileHash——审核人对这一行签名，等于给命令行背书。因此这里必须把它认出来：
// 当成普通文件名展示的话，审核人看到的是"argv[exact]: ..."这么一串东西，而真正
// 需要他判断的"到底批了哪条命令行"反倒被埋在依赖库列表里。
var ARGV_DISPLAY_RE = /^argv\[(exact|prefix)\]:\s([\s\S]*)$/

function parseArgvDisplay(fileName) {
    var m = ARGV_DISPLAY_RE.exec(fileName || "")
    if (!m) return null
    return { matchMode: m[1], cmdline: m[2] }
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
            var argv = parseArgvDisplay(fn)
            out.push({
                fileName:       argv ? argv.cmdline : fn,
                masterFileName: e.masterFileName || (argv ? argv.cmdline : fn),
                filePath:       e.filePath || e.path || "",
                fileCode:       e.fileCode || "",
                fileHash:       e.fileHash || e.hash || "",
                status:         e.status || "",
                isCmdline:      !!argv,
                cmdline:        argv ? argv.cmdline : "",
                matchMode:      argv ? argv.matchMode : ""
            })
        }
        // 命令行那一条排到最前：它是这次审批真正要看的东西，不该混在 ldd 依赖里。
        out.sort(function (a, b) {
            return (b.isCmdline ? 1 : 0) - (a.isCmdline ? 1 : 0)
        })
        return out
    }
    var rowSrc = row.processes || row.rawFiles || row.filePaths || []
    return normProcs(rowSrc)
}

// 该申请授权的命令行（没有则返回空对象），供列表行与详情弹窗直接取用。
function whitelistCommandLine(procs) {
    if (!procs) return { cmdline: "", matchMode: "" }
    for (var i = 0; i < procs.length; i++) {
        if (procs[i] && procs[i].isCmdline) {
            return { cmdline: procs[i].cmdline, matchMode: procs[i].matchMode }
        }
    }
    return { cmdline: "", matchMode: "" }
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
