pragma Singleton
import QtQuick 2.15

/**
 * DataManager - 数据管理器
 *
 * 职责：管理当前登录用户状态。
 * 业务数据（安全域、实例、消息等）由动态库提供，UI 层不直接操作数据库。
 */
QtObject {
    id: root

    // 当前登录用户
    property var currentUser: null

    // 最新欠费概览数据（来自 /api/user/arrears/overview）
    property var arrearsOverviewData: ({})

    // 登录状态
    readonly property bool isLoggedIn: currentUser !== null

    // 登出用户
    function logoutUser() {
        root.currentUser = null;
        root.userLoggedOut();
    }

    // 用户登出信号
    signal userLoggedOut
}
