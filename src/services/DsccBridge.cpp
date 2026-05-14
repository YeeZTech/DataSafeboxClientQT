#include "DsccBridge.h"

#include <QDateTime>
#include <algorithm>

#include "dscc/core/db/organization.h"
#include "dscc/core/interface/global.h"
#include "dscc/core/interface/organization.h"

namespace {
static constexpr uint32_t kDomainStatusClosed = 1;
}  // namespace

DsccBridge::DsccBridge(const QString &metaDbPath,
                       const QString &dbPath,
                       const QString &serverUrl,
                       const QString &credential,
                       QObject *parent)
    : QObject(parent)
    , m_assets(std::make_unique<dscc::UserAssets>(dbPath, credential))
    , m_metaDbPath(metaDbPath)
    , m_serverUrl(serverUrl)
{
    // ── 安全域写操作回调 ──────────────────────────────────────────────────────
    connect(m_assets.get(), &dscc::UserAssets::DomainCreated,
            this, [this](uint32_t operationId, QString domainCode) {
                dscc::DomainInfo info = m_pendingCreateDomain.take(operationId);
                if (!domainCode.isEmpty()) {
                    m_createdDomainCache.insert(domainCode, info);
                }
                emit domainCreated(operationId, domainCode, info.domain_name);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainCreateFailed,
            this, [this](uint32_t operationId, dscc::Notification notification) {
                m_pendingCreateDomain.remove(operationId);
                emit domainCreateFailed(operationId, notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode) {
                emit domainClosed(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainFailed,
            this, [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                emit domainCloseFailed(operationId, domainCode, notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdated,
            this, [this](uint32_t operationId, QString domainCode) {
                emit domainDescUpdated(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdateFailed,
            this, [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                emit domainDescUpdateFailed(operationId, domainCode, notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode, QString userId) {
                emit addUserToDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainFailed,
            this, [this](uint32_t operationId, QString domainCode, QString userId,
                         dscc::Notification notification) {
                emit addUserToDomainFailed(operationId, domainCode, userId,
                                           notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode, QString userId) {
                emit removeUserFromDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainFailed,
            this, [this](uint32_t operationId, QString domainCode, QString userId,
                         dscc::Notification notification) {
                emit removeUserFromDomainFailed(operationId, domainCode, userId,
                                                notificationToString(notification));
            });

    // ── 实例写操作回调 ────────────────────────────────────────────────────────
    connect(m_assets.get(), &dscc::UserAssets::InstanceStarted,
            this, [this](uint32_t operationId, QString instanceCode) {
                emit instanceStarted(operationId, instanceCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::InstanceStartFailed,
            this, [this](uint32_t operationId, QString instanceCode,
                         dscc::Notification notification) {
                emit instanceStartFailed(operationId, instanceCode,
                                         notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::InstanceDeleted,
            this, [this](uint32_t operationId, QString instanceCode) {
                emit instanceDeleted(operationId, instanceCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::InstanceDeleteFailed,
            this, [this](uint32_t operationId, QString instanceCode,
                         dscc::Notification notification) {
                emit instanceDeleteFailed(operationId, instanceCode,
                                          notificationToString(notification));
            });

    // ── 白名单写操作回调 ──────────────────────────────────────────────────────
    connect(m_assets.get(), &dscc::UserAssets::AddWhitelistToInstanceSuccess,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath) {
                emit whitelistAdded(operationId, instanceCode, filePath);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddWhitelistToInstanceFailed,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath,
                         dscc::Notification notification) {
                emit whitelistAddFailed(operationId, instanceCode, filePath,
                                        notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveWhitelistFromInstanceSuccess,
            this, [this](uint32_t operationId, QString instanceCode, QString fileCode) {
                emit whitelistRemoved(operationId, instanceCode, fileCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveWhitelistFromInstanceFailed,
            this, [this](uint32_t operationId, QString instanceCode, QString fileCode,
                         dscc::Notification notification) {
                emit whitelistRemoveFailed(operationId, instanceCode, fileCode,
                                           notificationToString(notification));
            });

    // ── 文件操作回调 ──────────────────────────────────────────────────────────
    connect(m_assets.get(), &dscc::UserAssets::ImportFileToInstanceSuccess,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath) {
                emit fileImported(operationId, instanceCode, filePath);
            });

    connect(m_assets.get(), &dscc::UserAssets::ImportFileToInstanceFailed,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath,
                         dscc::Notification notification) {
                emit fileImportFailed(operationId, instanceCode, filePath,
                                      notificationToString(notification));
            });

    connect(m_assets.get(), &dscc::UserAssets::ImportFileToInstanceProgress,
            this, [this](uint32_t operationId, QString instanceCode, QString /*filePath*/,
                         uint64_t processedBytes, uint64_t totalBytes) {
                emit fileImportProgress(operationId, instanceCode,
                                        static_cast<quint64>(processedBytes),
                                        static_cast<quint64>(totalBytes));
            });

    connect(m_assets.get(), &dscc::UserAssets::ExportFileFromInstanceSuccess,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath) {
                emit fileExported(operationId, instanceCode, filePath);
            });

    connect(m_assets.get(), &dscc::UserAssets::ExportFileFromInstanceFailed,
            this, [this](uint32_t operationId, QString instanceCode, QString filePath,
                         dscc::Notification notification) {
                emit fileExportFailed(operationId, instanceCode, filePath,
                                      notificationToString(notification));
            });
}

DsccBridge::~DsccBridge()
{
    shutdown();
}

// ── 初始化 / 关闭 ──────────────────────────────────────────────────────────────

void DsccBridge::initialize()
{
    // 只做 DSCC 全局配置，不启动 UserAssets。
    // 根据测试（gtest_user_assets_contract.cpp），正确顺序为：
    //   SetCurrentUser → Initialize → CreateDomain
    // 因此 Initialize() 延迟到 setCurrentUser() 中调用。

    // 1. 初始化 DSCC Setting 单例（meta DB 路径）
    dscc::LoadSetting().Call(m_metaDbPath.toStdString());

    // 2. 将服务器 URL 写入 meta DB
    dscc::db::Organization org;
    org.server_url = m_serverUrl.toStdString();
    org.info       = "{}";
    dscc::SaveOfficialOrg(org);
}

void DsccBridge::shutdown()
{
    m_assets->Shutdown();
}

// ── 用户设置 ──────────────────────────────────────────────────────────────────

void DsccBridge::setCurrentUser(const QString &userId,
                                const QString &userName,
                                const QString &accessToken,
                                const QString &refreshToken)
{
    m_currentUserName = userName;
    // 先设置用户凭证，再调用 Initialize()。
    // Initialize() 会把此时的 token 写入 HTTP 认证上下文；
    // 如果顺序反了（Initialize 先于 SetCurrentUser）服务端会收到空 token 返回 401。
    m_assets->SetCurrentUser(userId, accessToken, refreshToken);
    m_assets->Initialize();  // 幂等：重复调用无副作用
}

// ── 内部辅助 ──────────────────────────────────────────────────────────────────

QString DsccBridge::notificationToString(const dscc::Notification &n) const
{
    return n.Localized();
}

// ── 读操作实现 ────────────────────────────────────────────────────────────────

// DSCC 提供的 DomainInfo 转换为 QML QVariantMap
// DomainInfo 字段：domain_code/domain_name/domain_pub_key/remarks/pay_type/
//             visible_users/domain_status/creator_user_id/creator_user_name/
//             creator_display_name/created_at
// created_at 是 Unix 秒级时间戳，转换为 ISO 字符串供 QML formatDateTime 使用
static QString unixSecondsToIso(uint64_t seconds)
{
    if (seconds == 0) return QString();
    QDateTime dt = QDateTime::fromSecsSinceEpoch(static_cast<qint64>(seconds));
    return dt.toString(Qt::ISODate);
}

static QVariantMap domainInfoToVariant(const dscc::DomainInfo &d)
{
    QVariantMap m;
    m["domainCode"]  = d.domain_code;
    m["name"]        = d.domain_name;
    m["pubKey"]      = d.domain_pub_key;
    m["status"]      = (d.domain_status == kDomainStatusClosed)
                           ? QStringLiteral("已关闭")
                           : QStringLiteral("运行中");
    m["creator"]     = d.creator_display_name.isEmpty()
                           ? d.creator_user_name
                           : d.creator_display_name;
    // pay_type: 1=创建方  2=使用方
    m["payer"]       = (d.pay_type == 2) ? QStringLiteral("使用方")
                                         : QStringLiteral("创建方");
    // 备注即描述
    m["description"] = d.remarks;
    m["createdAt"]   = unixSecondsToIso(d.created_at);
    return m;
}

static QVariantList visibleUsersToVariant(const QList<dscc::VisibleUserInfo> &users)
{
    QVariantList list;
    for (const dscc::VisibleUserInfo &vu : users) {
        QVariantMap u;
        u["account"]      = vu.account;
        u["authUserId"]   = vu.auth_user_id;
        u["authUserName"] = vu.auth_user_name;
        u["displayName"]  = vu.display_name.isEmpty() ? vu.auth_user_name
                                                      : vu.display_name;
        list.append(u);
    }
    return list;
}

void DsccBridge::loadDomainList()
{
    // 使用 DSCC 公开接口 ListDomains()
    QList<dscc::DomainInfo> domains = m_assets->ListDomains();
    std::sort(domains.begin(), domains.end(),
              [](const dscc::DomainInfo &a, const dscc::DomainInfo &b) {
                  return a.created_at > b.created_at;
              });

    QVariantList list;
    for (const dscc::DomainInfo &d : domains) {
        list.append(domainInfoToVariant(d));
    }
    emit domainListLoaded(list);
}

void DsccBridge::loadDomainSummary(const QString &domainCode)
{
    QVariantMap summary;
    auto opt = m_assets->DetailDomainInfo(domainCode);
    if (opt.has_value()) {
        summary = domainInfoToVariant(opt.value());
    }
    // 兑底：DSCC 尚未把 creator 同步到本地时，用本会话创建表单或当前用户补齐
    if (summary.value("creator").toString().isEmpty()) {
        if (m_createdDomainCache.contains(domainCode)) {
            summary["creator"] = m_currentUserName;
        }
    }
    emit domainSummaryLoaded(domainCode, summary);
}

void DsccBridge::loadVisibleUsers(const QString &domainCode)
{
    QVariantList list;
    auto opt = m_assets->DetailDomainInfo(domainCode);
    if (opt.has_value()) {
        list = visibleUsersToVariant(opt.value().visible_users);
    }
    emit visibleUsersLoaded(domainCode, list);
}

void DsccBridge::loadInstances(const QString &domainCode)
{
    // ⚠️ stub：DSCC 尚未提供 ListInstances(domainCode) 公开接口
    emit instancesLoaded(domainCode, QVariantList());
}

void DsccBridge::loadAudits(const QString &domainCode, int applyType)
{
    // ⚠️ stub：DSCC 尚未提供 ListAudits(domainCode, applyType) 公开接口
    emit auditsLoaded(domainCode, applyType, QVariantList());
}

// ── 写操作实现 ────────────────────────────────────────────────────────────────

void DsccBridge::createDomain(const QVariantMap &info)
{
    dscc::DomainInfo domainInfo;
    domainInfo.domain_name = info.value("domainName").toString();
    // DSCC 要求 remarks 非空（kCreateDomainEmptyRemark），若用户未填则回退到域名
    const QString remarks = info.value("remarks").toString().trimmed();
    domainInfo.remarks = remarks.isEmpty() ? domainInfo.domain_name : remarks;

    // 将 QML 表单的 payer 字段映射到 pay_type
    // 服务端内部验证：1 = 安全域创建方支付（kOwnerPay），2 = 安全域使用方支付（kUserPay）
    const QString payer = info.value("payer").toString();
    domainInfo.pay_type = (payer == QStringLiteral("使用者")) ? 2 : 1;

    // 将 QML 表单中收集的可见用户填入 DomainInfo
    const QVariantList visibleUsers = info.value("visibleUsers").toList();
    for (const QVariant &v : visibleUsers) {
        const QVariantMap u = v.toMap();
        dscc::VisibleUserInfo vui;
        vui.account        = u.value("account").toString();
        vui.auth_user_id   = u.value("authUserId").toString();
        vui.auth_user_name = u.value("authUserName").toString();
        vui.display_name   = u.value("displayName").toString();
        if (!vui.account.isEmpty() && !vui.auth_user_id.isEmpty())
            domainInfo.visible_users.append(vui);
    }

    // ⚠️ 公私钥不再由客户端生成，改由 DSCC 动态库内部生成。
    // domain_pub_key / domain_pri_key 会在服务端创建后同步回本地。
    auto handle = m_assets->CreateDomain(domainInfo);
    // operationId 关联本次提交的 DomainInfo，回调时用来取 domain_name
    m_pendingCreateDomain.insert(handle.GetOperationId(), domainInfo);
    // DSCC Handle starts automatically when it leaves scope.
}

void DsccBridge::closeDomain(const QString &domainCode)
{
    auto handle = m_assets->CloseDomain(domainCode);
    Q_UNUSED(handle);
}

void DsccBridge::updateDomainDesc(const QString &domainCode, const QString &desc)
{
    auto handle = m_assets->UpdateDomainDesc(domainCode, desc);
    Q_UNUSED(handle);
}

void DsccBridge::addUserToDomain(const QString &domainCode, const QString &userId)
{
    auto handle = m_assets->AddUserToDomain(domainCode, userId);
    Q_UNUSED(handle);
}

void DsccBridge::removeUserFromDomain(const QString &domainCode, const QString &userId)
{
    auto handle = m_assets->RemoveUserFromDomain(domainCode, userId);
    Q_UNUSED(handle);
}

void DsccBridge::startInstance(const QString &instanceCode)
{
    auto handle = m_assets->StartInstance(instanceCode);
    Q_UNUSED(handle);
}

void DsccBridge::deleteInstance(const QString &instanceCode)
{
    auto handle = m_assets->DeleteInstance(instanceCode);
    Q_UNUSED(handle);
}

void DsccBridge::addWhitelistToInstance(const QString &instanceCode, const QString &filePath)
{
    auto handle = m_assets->AddWhitelistToInstance(instanceCode, filePath);
    Q_UNUSED(handle);
}

void DsccBridge::removeWhitelistFromInstance(const QString &instanceCode, const QString &fileCode)
{
    auto handle = m_assets->RemoveWhitelistFromInstance(instanceCode, fileCode);
    Q_UNUSED(handle);
}

void DsccBridge::importFileToInstance(const QString &instanceCode, const QString &filePath)
{
    auto handle = m_assets->ImportFileToInstance(instanceCode, filePath);
    Q_UNUSED(handle);
}

void DsccBridge::exportFileFromInstance(const QString &instanceCode, const QString &filePath)
{
    auto handle = m_assets->ExportFileFromInstance(instanceCode, filePath);
    Q_UNUSED(handle);
}
