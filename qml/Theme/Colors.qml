pragma Singleton
import QtQuick 2.15
import QtQml

QtObject {
    // Theme colors
    readonly property color primary: "#0F4C81"
    readonly property color primaryText: "#FFFFFF"
    readonly property color secondary: "#E8F1F8"
    readonly property color muted: "#F5F8FB"
    readonly property color accent: "#D4E4F1"

    // Backend status value constants (Chinese strings from API)
    readonly property string statusNormal: "正常"
    readonly property string statusRunning: "运行中"
    readonly property string statusClosed: "已关闭"
    readonly property string statusCreationFailed: "创建失败"
    readonly property string statusSuspended: "停用"
    readonly property string statusPendingReview: "待审核"
    readonly property string statusAuthorized: "已授权"
    readonly property string statusRejected: "已拒绝"
    readonly property string statusEnded: "已结束"

    // Status colors
    readonly property var statusColors: ({
            "待审核": {
                bg: "#fef3c6",
                border: "#fee685",
                text: "#bb4d00",
                dot: "#F0B100"
            },
            "已授权": {
                bg: "#dcfce7",
                border: "#b9f8cf",
                text: "#008236",
                dot: "#00C950"
            },
            "已拒绝": {
                bg: "#ffe2e2",
                border: "#ffc9c9",
                text: "#c10007",
                dot: "#D4183D"
            },
            "创建失败": {
                bg: "#ffe2e2",
                border: "#ffc9c9",
                text: "#c10007",
                dot: "#D4183D"
            },
            "正常": {
                bg: "#dcfce7",
                border: "#b9f8cf",
                text: "#008236",
                dot: "#00C950"
            },
            "运行中": {
                bg: "#dcfce7",
                border: "#b9f8cf",
                text: "#008236",
                dot: "#00C950"
            },
            "已关闭": {
                bg: "#f1f5f9",
                border: "#e2e8f0",
                text: "#314158",
                dot: "#90A1B9"
            },
            "停用": {
                bg: "#ffe2e2",
                border: "#ffc9c9",
                text: "#c10007",
                dot: "#D4183D"
            },
            "已停用": {
                bg: "#ffe2e2",
                border: "#ffc9c9",
                text: "#c10007",
                dot: "#D4183D"
            },
            "已结束": {
                bg: "#f1f5f9",
                border: "#e2e8f0",
                text: "#314158",
                dot: "#90A1B9"
            }
        })
    readonly property var defaultStatusColor: ({
            bg: "#f1f5f9",
            border: "#e2e8f0",
            text: "#314158",
            dot: "#90A1B9"
        })

    // Neutral colors
    readonly property color textPrimary: "#030213"
    readonly property color textSecondary: "#5A7C9B"
    readonly property color textLabel: "#314158"
    readonly property color textTitle: "#1d293d"
    readonly property color border: "#E6E6E6"
    readonly property color borderInput: "#E6E6E6"  // Same as border per spec
    readonly property color inputBackground: "#FFFFFF"
    readonly property color backgroundWhite: "#FFFFFF"
    readonly property color backgroundGray: "#f8fafc"
    readonly property color backgroundSidebar: "#f5f8fb"

    // Form specific colors
    readonly property color requiredMarker: "#fb2c36"
    readonly property color textCounter: "#90a1b9"
    readonly property color buttonDisabled: "#E6E6E6"  // Use border color per spec

    // Border colors (alias for consistency)
    readonly property color borderSlate: "#E6E6E6"  // Same as border per spec

    // Heading / form colors heavily used in detail pages
    readonly property color textHeading: "#0f172b"
    readonly property color borderField: "#cad5e2"
    readonly property color textCaption: "#62748e"
    readonly property color textMenu: "#334155"
    readonly property color textError: "#e7000b"
    readonly property color tooltipBackground: "#1e5a8e"
    readonly property color borderSeparator: "#e2e8f0"

    function getStatusColor(status) {
        if (!statusColors || !status) {
            return defaultStatusColor;
        }
        return statusColors[status] || defaultStatusColor;
    }

    // Translate status from Chinese backend value to current-language display text
    function translateStatus(status) {
        var s = (status || "").trim();
        if (s === "正常")
            return qsTr("Normal");
        if (s === "运行中")
            return qsTr("Running");
        if (s === "已关闭")
            return qsTr("Closed");
        if (s === "创建失败")
            return qsTr("Creation Failed");
        if (s === "停用" || s === "已停用" || s === "停用中")
            return qsTr("Suspended");
        if (s === "待审核")
            return qsTr("Pending Review");
        if (s === "已授权")
            return qsTr("Authorized");
        if (s === "已拒绝")
            return qsTr("Rejected");
        if (s === "已结束")
            return qsTr("Ended");
        return s;
    }
}
