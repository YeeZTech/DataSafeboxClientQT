pragma Singleton
import QtQuick 2.15

QtObject {
    /**
     * Normalize volume size to bytes with automatic unit detection.
     *
     * This function handles backward compatibility between different data sources:
     * - Legacy/local values: stored in MB units
     * - Backend-synced values: stored in bytes (in some environments)
     *
     * Logic:
     * - If value >= 1GB (1073741824 bytes), treats input as bytes (no conversion)
     * - If value < 1GB, treats input as MB and converts to bytes
     *
     * @param sizeValue - Number representing size (in bytes or MB, auto-detected)
     * @returns Size in bytes, or 0 if invalid
     *
     * Example:
     * - normalizeVolumeToBytes(100) → 104857600 (100 MB → bytes)
     * - normalizeVolumeToBytes(2147483648) → 2147483648 (2GB, already in bytes)
     */
    function normalizeVolumeToBytes(sizeValue) {
        if ((!sizeValue && sizeValue !== 0) || isNaN(Number(sizeValue))) {
            return 0
        }

        var value = Number(sizeValue)
        if (value <= 0) {
            return 0
        }

        var ONE_GB_IN_BYTES = 1024 * 1024 * 1024
        // Large values are treated as bytes to avoid MB->bytes double conversion.
        if (value >= ONE_GB_IN_BYTES) {
            return value
        }

        // Small values are treated as MB.
        return value * 1024 * 1024
    }

    /**
     * Format byte size into human-readable string.
     *
     * Converts byte values to appropriate units (B, KB, MB, GB, TB, PB)
     * with 2 decimal places for units >= KB.
     *
     * @param sizeValue - Size in bytes
     * @returns Formatted string (e.g., "1.50 GB"), or "-" if invalid
     */
    function formatSize(sizeValue) {
        if ((!sizeValue && sizeValue !== 0) || isNaN(Number(sizeValue))) {
            return "-"
        }

        var bytes = Number(sizeValue)
        if (bytes < 0) {
            return "-"
        }

        var KB = 1024
        var MB = KB * 1024
        var GB = MB * 1024
        var TB = GB * 1024
        var PB = TB * 1024

        if (bytes >= PB) {
            return (bytes / PB).toFixed(2) + " PB"
        }
        if (bytes >= TB) {
            return (bytes / TB).toFixed(2) + " TB"
        }
        if (bytes >= GB) {
            return (bytes / GB).toFixed(2) + " GB"
        }
        if (bytes >= MB) {
            return (bytes / MB).toFixed(2) + " MB"
        }
        if (bytes >= KB) {
            return (bytes / KB).toFixed(2) + " KB"
        }
        return bytes + " B"
    }

    /**
     * Format date/time value into standardized string.
     *
     * Accepts multiple input formats:
     * - Date object
     * - Timestamp (milliseconds since epoch)
     * - String (ISO format or space-separated)
     *
     * @param value - Date/time value to format
     * @returns Formatted string "YYYY-MM-DD HH:mm", or "-" if invalid
     */
    function formatDateTime(value) {
        if (!value && value !== 0) {
            return "-"
        }

        var date
        if (value instanceof Date) {
            date = value
        } else if (typeof value === "number") {
            date = new Date(value)
        } else if (typeof value === "string") {
            var normalized = value.replace(" ", "T")
            date = new Date(normalized)
        }

        if (!date || isNaN(date.getTime())) {
            return value || "-"
        }

        function pad(num) {
            num = Math.floor(num)
            return num < 10 ? "0" + num : "" + num
        }

        var year = date.getFullYear()
        var month = pad(date.getMonth() + 1)
        var day = pad(date.getDate())
        var hours = pad(date.getHours())
        var minutes = pad(date.getMinutes())

        return year + "-" + month + "-" + day + " " + hours + ":" + minutes
    }

    /**
     * Compute display width of string, accounting for CJK characters.
     *
     * CJK (Chinese, Japanese, Korean) and full-width characters count as 2 units,
     * while ASCII and other characters count as 1 unit.
     *
     * @param str - String to measure
     * @returns Display width in units (1 per ASCII char, 2 per CJK char)
     *
     * Example:
     * - displayWidth("abc") → 3
     * - displayWidth("你好") → 4
     * - displayWidth("a你b好") → 6
     */
    function displayWidth(str) {
        var w = 0
        for (var i = 0; i < str.length; i++) {
            var c = str.charCodeAt(i)
            // CJK Unified Ideographs, CJK Symbols, Fullwidth Forms, Hiragana, Katakana
            if ((c >= 0x1100 && c <= 0x115F) ||
                (c >= 0x2E80 && c <= 0x303F) ||
                (c >= 0x3040 && c <= 0xA4CF) ||
                (c >= 0xAC00 && c <= 0xD7AF) ||
                (c >= 0xF900 && c <= 0xFAFF) ||
                (c >= 0xFE10 && c <= 0xFE1F) ||
                (c >= 0xFE30 && c <= 0xFE4F) ||
                (c >= 0xFF00 && c <= 0xFF60) ||
                (c >= 0xFFE0 && c <= 0xFFE6)) {
                w += 2
            } else {
                w += 1
            }
        }
        return w
    }

    /**
     * Truncate text using display-width units for fair CJK/ASCII handling.
     *
     * Uses display-width calculation where CJK chars = 2 units, ASCII = 1 unit.
     * This ensures fair truncation regardless of character type.
     *
     * @param text - Text to truncate
     * @param maxLen - Maximum total display-width (in units)
     * @param headLen - Display-width of head portion to keep
     * @param tailLen - Display-width of tail portion to keep
     * @returns Truncated string with "..." between head and tail, or original if short enough
     *
     * Example:
     * - truncateText("这是一个测试文本", 10, 4, 4) → "这是...文本"
     * - truncateText("ShortText", 20, 5, 5) → "ShortText"
     */
    function truncateText(text, maxLen, headLen, tailLen) {
        if (!text) return ""
        var str = text.toString()
        if (displayWidth(str) <= maxLen) return str
        // Build head substring up to headLen display-width units
        var head = "", hw = 0
        for (var i = 0; i < str.length && hw < headLen; i++) {
            var cw = displayWidth(str.charAt(i))
            if (hw + cw > headLen) break
            head += str.charAt(i)
            hw += cw
        }
        // Build tail substring up to tailLen display-width units (from the end)
        var tail = "", tw = 0
        for (var j = str.length - 1; j >= 0 && tw < tailLen; j--) {
            var tcw = displayWidth(str.charAt(j))
            if (tw + tcw > tailLen) break
            tail = str.charAt(j) + tail
            tw += tcw
        }
        return head + "..." + tail
    }
}
