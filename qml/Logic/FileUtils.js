.pragma library

function getFileName(filePath) {
    if (!filePath) return ""
    var parts = filePath.split(/[/\\]/)
    return parts[parts.length - 1]
}

function getFileDir(filePath) {
    if (!filePath) return ""
    var parts = filePath.replace(/\\/g, "/").split("/")
    parts.pop()
    return parts.join("/")
}

function urlToLocalPath(fileUrl, platformOs) {
    if (fileUrl && typeof fileUrl.toLocalFile === "function") {
        return fileUrl.toLocalFile()
    }
    var urlString = fileUrl ? fileUrl.toString() : ""
    if (urlString.indexOf("file:///") === 0) {
        var path = urlString.substring(8)
        if (platformOs === "windows" && path.length > 0 && path[0] === "/") {
            path = path.substring(1)
        }
        return path
    }
    if (urlString.indexOf("file://") === 0) {
        return urlString.substring(7)
    }
    if (urlString.indexOf("file:/") === 0) {
        var p2 = urlString.substring(6)
        if (platformOs === "windows" && p2.length > 0 && p2[0] === "/") {
            p2 = p2.substring(1)
        }
        return p2
    }
    return urlString
}

function isDirectory(path) {
    return false
}

function listFilesRecursive(dirPath) {
    return []
}

function formatEncryptFailure(notification, fallback, notificationResolver) {
    if (notificationResolver) {
        var message = notificationResolver(notification, fallback)
        if (message) return message
    }
    return fallback
}
