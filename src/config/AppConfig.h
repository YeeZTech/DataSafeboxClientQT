#ifndef APPCONFIG_H
#define APPCONFIG_H

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QString>
#include <QStringList>

// ── 敏感配置（密钥 / 令牌 / DSN）────────────────────────────
// 不在源码中硬编码：由 qmake 在编译期从 secrets.env 读取，注入为
// DSBOX_<KEY> 宏（见 datasafebox-qt-client.pro）。
// 本地开发：复制 .env.example 为 secrets.env 并填入真实值。
// CI：由 GitHub Secrets 在构建前写入。该文件已被 .gitignore 忽略。
#if !defined(DSBOX_SOKETI_APP_KEY) || !defined(DSBOX_CASDOOR_CLIENT_ID_TEST) ||                                        \
    !defined(DSBOX_CASDOOR_CLIENT_ID_PROD) || !defined(DSBOX_CUSTOMER_SERVICE_TOKEN) || !defined(DSBOX_SENTRY_DSN)
#error "敏感配置宏未注入：请确认 secrets.env 存在并由 qmake 注入。参见 .env.example。"
#endif

namespace AppCfg
{

// ── 服务器环境 Profile ──────────────────────────────────────
// 单一安装包同时内置测试/正式两套服务配置，登录前由用户在登录页选择。
// 选择持久化在环境隔离目录的上一级（所有环境共享，见 serverSelectionFilePath），
// 切换通过重启应用生效（数据目录/Sentry/WebEngine 缓存均按环境隔离）。
struct ServerProfile
{
    const char *id; // 持久化标识（"prod"/"test"），不可更改
    bool isTest;
    const char *apiBaseUrl;      // 后端 API 基础地址（同时传给 DSCC 作 domain manager）
    const char *soketiWsHost;    // Soketi 消息推送 WebSocket 主机
    const char *casdoorEndpoint; // Casdoor SSO（同时传给 DSCC 作用户查询服务）
    const char *casdoorClientId;
    const char *casdoorRedirectUri;
    const char *websiteUrl;
    const char *walletUrl;
    const char *userCenterUrl;
    const char *openbaoServiceUrl; // OpenBao KMS（传给 DSCC，加密安全域私钥）
    // 加密文件点对点传输的信令服务（file-transfer-go）根地址。只用于换取件码与
    // 交换 SDP/ICE，文件内容不经过它。为空表示该环境未部署，界面隐藏传输入口。
    const char *transferSignalUrl;
};

inline constexpr ServerProfile PROD_PROFILE = {
    "prod",
    false,
    "https://dsbox-api.dianshudata.com",
    "wss://dsbox-api.dianshudata.com",
    "https://sso.dianshudata.com",
    DSBOX_CASDOOR_CLIENT_ID_PROD,
    "https://account.dianshudata.com/callback/",
    "https://dsbox.dianshudata.com",
    "https://dsbox.dianshudata.com/wallet",
    "https://dianshudata.com/userCenter/userInfo",
    "https://kms.dianshudata.com",
    "https://file-transfer.dianshudata.com",
};

inline constexpr ServerProfile TEST_PROFILE = {
    "test",
    true,
    "https://test-dsbox.dianshudata.com",
    "ws://49.232.246.86:6001",
    "https://test-sso.dianshudata.com",
    DSBOX_CASDOOR_CLIENT_ID_TEST,
    "https://test-account.dianshudata.com/callback/",
    "https://test-dsbox.dianshudata.com",
    "https://test-dsbox.dianshudata.com/wallet",
    "https://test.dianshudata.com/userCenter/userInfo",
    "https://test-kms.dianshudata.com",
    "https://file-transfer.dianshudata.com",
};

// ── 共享配置（与环境无关）──────────────────────────────────
// 厂商官网 & 帮助文档
inline constexpr const char *VENDOR_URL = "https://yeez.tech/";
inline constexpr const char *VENDOR_COMPANY_NAME = "北京熠智科技有限公司";
inline constexpr const char *HELP_DOCS_URL = "https://help.yeez.tech/docs/dsbox";

// 客服聊天（Chatwoot）
inline constexpr const char *CUSTOMER_SERVICE_URL = "https://customersupport.dianshudata.com";

inline constexpr const char *SOKETI_APP_KEY = DSBOX_SOKETI_APP_KEY;
inline constexpr const char *CUSTOMER_SERVICE_TOKEN = DSBOX_CUSTOMER_SERVICE_TOKEN;
inline constexpr const char *SENTRY_DSN = DSBOX_SENTRY_DSN;

// ── 选择持久化 ──────────────────────────────────────────────
// 本地数据根目录的上一级（不含环境 hash 段），所有环境共享。
// 与 main.cpp 的启动路径推导保持一致。
inline QString localDataBaseDir()
{
    QString base;
#ifdef Q_OS_WIN
    const QString localAppData = qEnvironmentVariable("LOCALAPPDATA");
    if (!localAppData.isEmpty())
    {
        base = QDir(localAppData).filePath(QStringLiteral("yeeztech/datasafebox-client"));
    }
#endif
    if (base.isEmpty())
    {
        base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    }
    return base;
}

inline QString serverSelectionFilePath()
{
    return QDir(localDataBaseDir()).filePath(QStringLiteral("server.ini"));
}

// 当前环境：进程内只解析一次（启动早期即被读取，之后切换走"持久化+重启"）。
inline const ServerProfile &currentProfile()
{
    static const ServerProfile *const selected = [] {
        const QSettings settings(serverSelectionFilePath(), QSettings::IniFormat);
        const QString id = settings.value(QStringLiteral("server/profile")).toString().trimmed();
        return id == QLatin1String(TEST_PROFILE.id) ? &TEST_PROFILE : &PROD_PROFILE;
    }();
    return *selected;
}

inline void persistServerSelection(const QString &id)
{
    QSettings settings(serverSelectionFilePath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("server/profile"), id);
}

// ── 自有服务器地址检索 ──────────────────────────────────────
// 以后端 baseurl 检索内置 profile：归一化（去首尾空白与结尾斜杠，缺省
// scheme 按 https）后与各 profile 的 apiBaseUrl 大小写不敏感比较。
// 填入官方地址时返回 PROD_PROFILE，与选择官方服务器等价；无匹配返回 nullptr。
inline const ServerProfile *profileForBaseUrl(const QString &url)
{
    QString normalized = url.trimmed();
    while (normalized.endsWith(QLatin1Char('/')))
    {
        normalized.chop(1);
    }
    if (normalized.isEmpty())
    {
        return nullptr;
    }
    if (!normalized.contains(QLatin1String("://")))
    {
        normalized.prepend(QLatin1String("https://"));
    }
    for (const ServerProfile *profile : {&PROD_PROFILE, &TEST_PROFILE})
    {
        if (normalized.compare(QLatin1String(profile->apiBaseUrl), Qt::CaseInsensitive) == 0)
        {
            return profile;
        }
    }
    return nullptr;
}

// ── 环境隔离目录名 ──────────────────────────────────────────
// 本地数据根目录按后端环境隔离：%LOCALAPPDATA%/<组织名>/<应用名>/<ENV>，
// 其中 ENV = SHA-256(apiBaseUrl + soketiWsHost + casdoorEndpoint) 的十六进制串。
// 注意：哈希输入与单包改造前完全一致，保证老安装的数据目录无缝衔接。
inline QString environmentDirName()
{
    const ServerProfile &profile = currentProfile();
    return QString::fromLatin1(
        QCryptographicHash::hash(QByteArray(profile.apiBaseUrl) + profile.soketiWsHost + profile.casdoorEndpoint,
                                 QCryptographicHash::Sha256)
            .toHex());
}

// ============================================================
// 分页配置（与环境无关的统一配置）
// ============================================================
// 安全域模块（实例、白名单审核、导出审核）的分页大小
inline constexpr int SECURITY_DOMAIN_PAGE_SIZE = 5;

// 可见用户列表的分页大小
inline constexpr int VISIBLE_USERS_PAGE_SIZE = 5;

// 消息中心的分页大小
inline constexpr int MESSAGE_CENTER_PAGE_SIZE = 10;

// ===================== 详情页和缓存配置 =====================
// 详情Dialog最大宽度 (px)
inline constexpr int DETAIL_DIALOG_MAX_WIDTH = 900;

// 详情Dialog最大高度 (px)
inline constexpr int DETAIL_DIALOG_MAX_HEIGHT = 700;

// 详情缓存最大条数（超过时LRU清理）
inline constexpr int DETAIL_CACHE_MAX_SIZE = 50;

// 详情缓存TTL（秒，5分钟）
inline constexpr int DETAIL_CACHE_TTL_SECONDS = 300;

} // namespace AppCfg

// ============================================================
// QML 适配器 — 以 context property "AppConfig" 暴露给 QML
// ============================================================
class AppConfig : public QObject
{
    Q_OBJECT
  public:
    explicit AppConfig(QObject *parent = nullptr) : QObject(parent)
    {
    }

    Q_INVOKABLE QString apiBaseUrl() const
    {
        return QLatin1String(AppCfg::currentProfile().apiBaseUrl);
    }
    Q_INVOKABLE QString soketiWsHost() const
    {
        return QLatin1String(AppCfg::currentProfile().soketiWsHost);
    }
    Q_INVOKABLE QString soketiAppKey() const
    {
        return QLatin1String(AppCfg::SOKETI_APP_KEY);
    }
    Q_INVOKABLE QString casdoorEndpoint() const
    {
        return QLatin1String(AppCfg::currentProfile().casdoorEndpoint);
    }
    Q_INVOKABLE QString casdoorClientId() const
    {
        return QLatin1String(AppCfg::currentProfile().casdoorClientId);
    }
    Q_INVOKABLE QString casdoorRedirectUri() const
    {
        return QLatin1String(AppCfg::currentProfile().casdoorRedirectUri);
    }
    Q_INVOKABLE QString websiteUrl() const
    {
        return QLatin1String(AppCfg::currentProfile().websiteUrl);
    }
    Q_INVOKABLE QString walletUrl() const
    {
        return QLatin1String(AppCfg::currentProfile().walletUrl);
    }
    Q_INVOKABLE QString userCenterUrl() const
    {
        return QLatin1String(AppCfg::currentProfile().userCenterUrl);
    }
    Q_INVOKABLE QString vendorUrl() const
    {
        return QLatin1String(AppCfg::VENDOR_URL);
    }
    Q_INVOKABLE QString vendorCompanyName() const
    {
        return QString::fromUtf8(AppCfg::VENDOR_COMPANY_NAME);
    }
    Q_INVOKABLE QString helpDocsUrl() const
    {
        return QLatin1String(AppCfg::HELP_DOCS_URL);
    }
    Q_INVOKABLE QString customerServiceUrl() const
    {
        return QLatin1String(AppCfg::CUSTOMER_SERVICE_URL);
    }
    Q_INVOKABLE QString customerServiceToken() const
    {
        return QLatin1String(AppCfg::CUSTOMER_SERVICE_TOKEN);
    }

    // 加密文件点对点传输的信令服务地址。为空时 QML 隐藏"发送到命令行客户端"入口。
    Q_INVOKABLE QString transferSignalUrl() const
    {
        return QLatin1String(AppCfg::currentProfile().transferSignalUrl);
    }

    // 环境标识：仅在测试环境为 true，用于 QML 端在测试环境下放宽 SSL 校验等场景
    Q_INVOKABLE bool isTestEnv() const
    {
        return AppCfg::currentProfile().isTest;
    }

    // ── 服务器环境选择（登录前"选择服务器"弹窗）───────────
    Q_INVOKABLE QString currentServerId() const
    {
        return QLatin1String(AppCfg::currentProfile().id);
    }
    // 自有服务器地址 → 内置 Profile 检索（见 AppCfg::profileForBaseUrl）。无匹配返回空串。
    Q_INVOKABLE QString serverIdForBaseUrl(const QString &url) const
    {
        const AppCfg::ServerProfile *profile = AppCfg::profileForBaseUrl(url);
        return profile ? QString(QLatin1String(profile->id)) : QString();
    }
    // 本次启动是否由"切换服务器后重启"拉起（见 main.cpp），用于跳过重复弹窗
    Q_INVOKABLE bool startedAfterServerSwitch() const
    {
        return QCoreApplication::arguments().contains(QStringLiteral("--server-switched"));
    }
    // 持久化选择并请求重启（重启由 main.cpp 响应 restartRequested 完成）
    Q_INVOKABLE void selectServer(const QString &serverId)
    {
        if (serverId == currentServerId())
        {
            return;
        }
        AppCfg::persistServerSelection(serverId);
        emit restartRequested();
    }

    // 分页配置访问方法
    Q_INVOKABLE int securityDomainPageSize() const
    {
        return AppCfg::SECURITY_DOMAIN_PAGE_SIZE;
    }
    Q_INVOKABLE int visibleUsersPageSize() const
    {
        return AppCfg::VISIBLE_USERS_PAGE_SIZE;
    }
    Q_INVOKABLE int messageCenterPageSize() const
    {
        return AppCfg::MESSAGE_CENTER_PAGE_SIZE;
    }

    // 详情页和缓存配置访问方法
    Q_INVOKABLE int detailDialogMaxWidth() const
    {
        return AppCfg::DETAIL_DIALOG_MAX_WIDTH;
    }
    Q_INVOKABLE int detailDialogMaxHeight() const
    {
        return AppCfg::DETAIL_DIALOG_MAX_HEIGHT;
    }
    Q_INVOKABLE int detailCacheMaxSize() const
    {
        return AppCfg::DETAIL_CACHE_MAX_SIZE;
    }
    Q_INVOKABLE int detailCacheTtlSeconds() const
    {
        return AppCfg::DETAIL_CACHE_TTL_SECONDS;
    }

  signals:
    void restartRequested();
};

#endif // APPCONFIG_H
