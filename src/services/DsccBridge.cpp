#include "DsccBridge.h"

#include <QDateTime>
#include <algorithm>

#include "dscc/core/db/organization.h"
#include "dscc/core/interface/global.h"
#include "dscc/core/interface/organization.h"

namespace {
constexpr uint32_t kDomainStatusClosed = 1;

QString timestampToIsoString(uint64_t timestamp)
{
    if (timestamp == 0) {
        return QString();
    }

    const qint64 value = static_cast<qint64>(timestamp);
    const QDateTime dateTime = timestamp > 100000000000ULL
                                   ? QDateTime::fromMSecsSinceEpoch(value)
                                   : QDateTime::fromSecsSinceEpoch(value);
    return dateTime.toString(Qt::ISODate);
}
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
    connect(m_assets.get(), &dscc::UserAssets::DomainCreated,
            this, [this](uint32_t operationId, QString domainCode) {
                const auto info = m_assets->DetailDomainInfo(domainCode);
                emit domainCreated(operationId,
                                   domainCode,
                                   info.has_value() ? info->domain_name : QString());
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainCreateFailed,
            this, [this](uint32_t operationId, dscc::Notification notification) {
                emit domainCreateFailed(operationId, notificationToString(notification));
            });
}

DsccBridge::~DsccBridge()
{
    shutdown();
}

void DsccBridge::initialize()
{
    dscc::LoadSetting().Call(m_metaDbPath.toStdString());

    dscc::db::Organization org;
    org.server_url = m_serverUrl.toStdString();
    org.info = "{}";
    dscc::SaveOfficialOrg(org);
}

void DsccBridge::shutdown()
{
    if (m_assets) {
        m_assets->Shutdown();
    }
}

void DsccBridge::setCurrentUser(const QString &userId,
                                const QString &userName,
                                const QString &accessToken,
                                const QString &refreshToken)
{
    Q_UNUSED(userName);

    m_assets->SetCurrentUser(userId, accessToken, refreshToken);
    m_assets->Initialize();
}

QString DsccBridge::notificationToString(const dscc::Notification &notification) const
{
    QString msg = notification.DefaultText();
    for (auto it = notification.params.cbegin(); it != notification.params.cend(); ++it) {
        msg.replace(QStringLiteral("{") + it.key() + QStringLiteral("}"),
                    it.value().toString());
    }
    return msg;
}

QVariantMap DsccBridge::domainInfoToSummary(const dscc::DomainInfo &info) const
{
    QVariantMap summary;
    summary.insert(QStringLiteral("domainCode"), info.domain_code);
    summary.insert(QStringLiteral("name"), info.domain_name);
    summary.insert(QStringLiteral("pubKey"), info.domain_pub_key);
    summary.insert(QStringLiteral("description"), info.remarks);
    summary.insert(QStringLiteral("payer"),
                   info.pay_type == 2 ? QStringLiteral("使用者") : QStringLiteral("创建者"));
    summary.insert(QStringLiteral("status"),
                   info.domain_status == kDomainStatusClosed ? QStringLiteral("已关闭")
                                                             : QStringLiteral("运行中"));
    summary.insert(QStringLiteral("creator"),
                   info.creator_user_name.isEmpty() ? info.creator_user_id
                                                    : info.creator_user_name);
    summary.insert(QStringLiteral("createdAt"), timestampToIsoString(info.created_at));
    summary.insert(QStringLiteral("updatedAt"), timestampToIsoString(info.updated_at));
    return summary;
}

void DsccBridge::loadDomainList()
{
    QList<dscc::DomainInfo> domains = m_assets->ListDomains();
    std::sort(domains.begin(), domains.end(), [](const dscc::DomainInfo &a,
                                                 const dscc::DomainInfo &b) {
        return a.created_at > b.created_at;
    });

    QVariantList list;
    list.reserve(domains.size());
    for (const dscc::DomainInfo &domain : domains) {
        list.append(domainInfoToSummary(domain));
    }
    emit domainListLoaded(list);
}

void DsccBridge::loadDomainSummary(const QString &domainCode)
{
    QVariantMap summary;
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!trimmedDomainCode.isEmpty()) {
        const auto info = m_assets->DetailDomainInfo(trimmedDomainCode);
        if (info.has_value()) {
            summary = domainInfoToSummary(*info);
        }
    }
    emit domainSummaryLoaded(domainCode, summary);
}

void DsccBridge::createDomain(const QVariantMap &info)
{
    dscc::DomainInfo domainInfo;
    domainInfo.domain_name = info.value("domainName").toString();

    const QString remarks = info.value("remarks").toString().trimmed();
    domainInfo.remarks = remarks.isEmpty() ? domainInfo.domain_name : remarks;

    const QString payer = info.value("payer").toString();
    domainInfo.pay_type = (payer == QStringLiteral("使用者")) ? 2 : 1;

    const QVariantList visibleUsers = info.value("visibleUsers").toList();
    for (const QVariant &v : visibleUsers) {
        const QVariantMap u = v.toMap();
        dscc::VisibleUserInfo user;
        user.account = u.value("account").toString();
        user.auth_user_id = u.value("authUserId").toString();
        user.auth_user_name = u.value("authUserName").toString();
        user.display_name = u.value("displayName").toString();
        if (!user.account.isEmpty() && !user.auth_user_id.isEmpty()) {
            domainInfo.visible_users.append(user);
        }
    }

    auto handle = m_assets->CreateDomain(domainInfo);
    Q_UNUSED(handle);
}
