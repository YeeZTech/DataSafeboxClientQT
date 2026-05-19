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
    
    // Status colors
    readonly property var statusColors: ({
        "待审核": { bg: "#fef3c6", border: "#fee685", text: "#bb4d00", dot: "#F0B100" },
        "已授权": { bg: "#dcfce7", border: "#b9f8cf", text: "#008236", dot: "#00C950" },
        "已拒绝": { bg: "#ffe2e2", border: "#ffc9c9", text: "#c10007", dot: "#D4183D" },
        "创建失败": { bg: "#ffe2e2", border: "#ffc9c9", text: "#c10007", dot: "#D4183D" },
        "运行中": { bg: "#dcfce7", border: "#b9f8cf", text: "#008236", dot: "#00C950" },
        "已结束": { bg: "#f1f5f9", border: "#e2e8f0", text: "#314158", dot: "#90A1B9" }
    })
    readonly property var defaultStatusColor: ({
        bg: "#f1f5f9",
        border: "#e2e8f0",
        text: "#314158",
        dot: "#90A1B9"
    })
    
    // Status translation mapping (Chinese -> English)
    readonly property var statusTranslations: ({
        "待审核": "Pending Review",
        "已授权": "Approved",
        "已拒绝": "Rejected",
        "创建失败": "Creation Failed",
        "运行中": "Running",
        "已结束": "Ended"
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

    // Heading / form colors heavily used in detail pages — kept as separate
    // semantic tokens; do not collapse with textPrimary/borderInput which
    // currently target a different visual style.
    readonly property color textHeading: "#0f172b"
    readonly property color borderField: "#cad5e2"

    function getStatusColor(status) {
        if (!statusColors || !status) {
            return defaultStatusColor
        }
        return statusColors[status] || defaultStatusColor
    }
    
    // Translate status from Chinese to display text (respects current language)
    function translateStatus(chineseStatus) {
        if (!chineseStatus) return ""
        // Map Chinese status to English translation key
        var translationKey = statusTranslations[chineseStatus]
        if (!translationKey) return chineseStatus
        // Use qsTr to get translation
        return qsTr(translationKey)
    }
}

