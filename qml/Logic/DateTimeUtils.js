.pragma library

function parseDateTime(value) {
    if (!value) return null
    if (value instanceof Date) return value
    var parsed = null
    if (typeof value === "string") {
        var trimmed = value.trim()
        parsed = new Date(trimmed.replace(" ", "T"))
        if (isNaN(parsed.getTime())) parsed = new Date(trimmed.replace(/-/g, "/"))
    } else {
        parsed = new Date(value)
    }
    return (parsed && !isNaN(parsed.getTime())) ? parsed : null
}

function toSortableTime(value) {
    var text = (value || "").toString().trim()
    if (!text.length) return 0
    if (/([+-]\d{2}):$/.test(text)) text += "00"
    var normalized = text.indexOf("T") === -1 ? text.replace(" ", "T") : text
    var date = new Date(normalized)
    if (!isNaN(date.getTime())) return date.getTime()
    var fallback = text.match(/^(\d{4})-(\d{2})-(\d{2})[T\s]?(\d{2})?:?(\d{2})?:?(\d{2})?/)
    if (!fallback) return 0
    return Date.UTC(
        parseInt(fallback[1], 10), parseInt(fallback[2], 10) - 1,
        parseInt(fallback[3], 10), parseInt(fallback[4] || "0", 10),
        parseInt(fallback[5] || "0", 10), parseInt(fallback[6] || "0", 10)
    )
}

function parseDurationMonths(durationValue) {
    if (durationValue === undefined || durationValue === null) return 0
    if (typeof durationValue === "number") return durationValue
    if (typeof durationValue === "string") {
        var match = durationValue.match(/(\d+)/)
        if (match) return parseInt(match[1])
    }
    return 0
}

function calculateExpiryDate(createdAt, durationMonths) {
    if (!createdAt) return null
    var months = (typeof durationMonths === "number") ? durationMonths : parseDurationMonths(durationMonths)
    if (!months || months <= 0) return null

    var createdDate = parseDateTime(createdAt)
    if (!createdDate) return null

    var expiryDate = new Date(createdDate.getTime())
    var targetMonth = expiryDate.getMonth() + months
    var yearsToAdd = Math.floor(targetMonth / 12)
    var newMonth = targetMonth % 12

    expiryDate.setFullYear(expiryDate.getFullYear() + yearsToAdd)
    var originalDay = createdDate.getDate()
    expiryDate.setMonth(newMonth, 1)
    var lastDayOfNewMonth = new Date(expiryDate.getFullYear(), newMonth + 1, 0).getDate()
    expiryDate.setDate(Math.min(originalDay, lastDayOfNewMonth))
    expiryDate.setHours(createdDate.getHours())
    expiryDate.setMinutes(createdDate.getMinutes())
    expiryDate.setSeconds(createdDate.getSeconds())

    return isNaN(expiryDate.getTime()) ? null : expiryDate
}

function sortByTimeDesc(list, primaryField, secondaryField) {
    var source = list.slice ? list.slice() : []
    source.sort(function(a, b) {
        var ta = toSortableTime(a && a[primaryField] ? a[primaryField] : (secondaryField ? (a && a[secondaryField] ? a[secondaryField] : "") : ""))
        var tb = toSortableTime(b && b[primaryField] ? b[primaryField] : (secondaryField ? (b && b[secondaryField] ? b[secondaryField] : "") : ""))
        return tb - ta
    })
    return source
}

function resolveExpiryDate(instance) {
    if (!instance) return null
    if (instance.expiresAt) {
        var d = parseDateTime(instance.expiresAt)
        if (d) return d
    }
    return calculateExpiryDate(instance.createdAt, instance.duration)
}

function remainingDays(instance) {
    var status = instance ? (instance.status || "") : ""
    var durationMonths = parseDurationMonths(instance ? instance.duration : 0)
    if (!durationMonths) return -1

    var expiryDate = resolveExpiryDate(instance)
    if (!expiryDate || isNaN(expiryDate.getTime())) return -1

    var now = new Date()
    var diff = expiryDate.getTime() - now.getTime()
    if (diff <= 0) return 0
    return Math.ceil(diff / (24 * 60 * 60 * 1000))
}
