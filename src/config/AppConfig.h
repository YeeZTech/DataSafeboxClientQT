#ifndef APPCONFIG_H
#define APPCONFIG_H

#include <QObject>

#ifndef USE_TEST_ENV
#error "USE_TEST_ENV is not defined. Pass USE_TEST_ENV=0 or USE_TEST_ENV=1 on the qmake command line."
#endif
static_assert(USE_TEST_ENV == 0 || USE_TEST_ENV == 1, "USE_TEST_ENV must be 0 (production) or 1 (test).");
namespace AppCfg
{

#if USE_TEST_ENV

// ── 测试环境 ──────────────────────────────────────────────
// 后端 API 基础地址
inline constexpr const char *API_BASE_URL = "https://test-dsbox.dianshudata.com";

// Soketi 消息推送 WebSocket 主机
inline constexpr const char *SOKETI_WS_HOST = "ws://49.232.246.86:6001";
// Soketi App Key（与正式环境相同）
inline constexpr const char *SOKETI_APP_KEY = "5f7accca692f298f15458113e4a84dca";

// Casdoor SSO 配置
inline constexpr const char *CASDOOR_ENDPOINT = "https://test-sso.dianshudata.com";
inline constexpr const char *CASDOOR_CLIENT_ID = "2ca9e76c06266f8be002";
inline constexpr const char *CASDOOR_REDIRECT_URI = "https://test-account.dianshudata.com/callback/";

// 官网 & 钱包
inline constexpr const char *WEBSITE_URL = "https://test-dsbox.dianshudata.com";
inline constexpr const char *WALLET_URL = "https://test-dsbox.dianshudata.com/wallet";

// 用户中心
inline constexpr const char *USER_CENTER_URL = "https://test.dianshudata.com/userCenter/userInfo";

// 厂商官网 & 帮助文档（与正式环境相同）
inline constexpr const char *VENDOR_URL = "https://yeez.tech/";
inline constexpr const char *VENDOR_COMPANY_NAME = "北京熠智科技有限公司";
inline constexpr const char *HELP_DOCS_URL = "https://help.yeez.tech/docs/dsbox";

// 客服聊天（Chatwoot，测试环境复用正式）
inline constexpr const char *CUSTOMER_SERVICE_URL = "https://customersupport.dianshudata.com";
inline constexpr const char *CUSTOMER_SERVICE_TOKEN = "d86Jao4VKH8Qtd1Kh7er5Qg3";

// Sentry 错误监控 DSN（测试环境复用正式）
inline constexpr const char *SENTRY_DSN = "https://0d04b662f5452d324fa2c4e49e47748c@trace.dianshudata.com/19";

#else

// ── 正式环境 ──────────────────────────────────────────────
// 后端 API 基础地址
inline constexpr const char *API_BASE_URL = "https://dsbox-api.dianshudata.com";

// Soketi 消息推送 WebSocket 主机
inline constexpr const char *SOKETI_WS_HOST = "wss://dsbox-api.dianshudata.com";
// Soketi App Key
inline constexpr const char *SOKETI_APP_KEY = "5f7accca692f298f15458113e4a84dca";

// Casdoor SSO 配置
inline constexpr const char *CASDOOR_ENDPOINT = "https://sso.dianshudata.com";
inline constexpr const char *CASDOOR_CLIENT_ID = "fcdfeb6531b13151851f";
inline constexpr const char *CASDOOR_REDIRECT_URI = "https://account.dianshudata.com/callback/";

// 官网 & 钱包
inline constexpr const char *WEBSITE_URL = "https://dsbox.dianshudata.com";
inline constexpr const char *WALLET_URL = "https://dsbox.dianshudata.com/wallet";

// 用户中心
inline constexpr const char *USER_CENTER_URL = "https://dianshudata.com/userCenter/userInfo";

// 厂商官网 & 帮助文档
inline constexpr const char *VENDOR_URL = "https://yeez.tech/";
inline constexpr const char *VENDOR_COMPANY_NAME = "北京熠智科技有限公司";
inline constexpr const char *HELP_DOCS_URL = "https://help.yeez.tech/docs/dsbox";

// 客服聊天（Chatwoot）
inline constexpr const char *CUSTOMER_SERVICE_URL = "https://customersupport.dianshudata.com";
inline constexpr const char *CUSTOMER_SERVICE_TOKEN = "d86Jao4VKH8Qtd1Kh7er5Qg3";

// Sentry 错误监控 DSN
inline constexpr const char *SENTRY_DSN = "https://0d04b662f5452d324fa2c4e49e47748c@trace.dianshudata.com/19";

#endif // USE_TEST_ENV

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
        return QLatin1String(AppCfg::API_BASE_URL);
    }
    Q_INVOKABLE QString soketiWsHost() const
    {
        return QLatin1String(AppCfg::SOKETI_WS_HOST);
    }
    Q_INVOKABLE QString soketiAppKey() const
    {
        return QLatin1String(AppCfg::SOKETI_APP_KEY);
    }
    Q_INVOKABLE QString casdoorEndpoint() const
    {
        return QLatin1String(AppCfg::CASDOOR_ENDPOINT);
    }
    Q_INVOKABLE QString casdoorClientId() const
    {
        return QLatin1String(AppCfg::CASDOOR_CLIENT_ID);
    }
    Q_INVOKABLE QString casdoorRedirectUri() const
    {
        return QLatin1String(AppCfg::CASDOOR_REDIRECT_URI);
    }
    Q_INVOKABLE QString websiteUrl() const
    {
        return QLatin1String(AppCfg::WEBSITE_URL);
    }
    Q_INVOKABLE QString walletUrl() const
    {
        return QLatin1String(AppCfg::WALLET_URL);
    }
    Q_INVOKABLE QString userCenterUrl() const
    {
        return QLatin1String(AppCfg::USER_CENTER_URL);
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

    // 环境标识：仅在测试环境为 true，用于 QML 端在测试环境下放宽 SSL 校验等场景
    Q_INVOKABLE bool isTestEnv() const
    {
#if USE_TEST_ENV
        return true;
#else
        return false;
#endif
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
};

#endif // APPCONFIG_H
