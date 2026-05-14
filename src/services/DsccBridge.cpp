#include "DsccBridge.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QMetaType>
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

namespace {
void registerDsccBridgeMetaTypes()
{
    static const bool registered = [] {
        qRegisterMetaType<dscc::Notification>("dscc::Notification");
        qRegisterMetaType<dscc::Notification>("Notification");
        return true;
    }();
    Q_UNUSED(registered);
}
}  // namespace

DsccBridge::DsccBridge(const QString &metaDbPath,
                       const QString &dsccDataRoot,
                       const QString &serverUrl,
                       const QString &credential,
                       QObject *parent)
    : QObject(parent)
    , m_metaDbPath(metaDbPath)
    , m_dsccDataRoot(QDir::cleanPath(dsccDataRoot))
    , m_serverUrl(serverUrl)
    , m_credential(credential)
{
    registerDsccBridgeMetaTypes();
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
        m_assets.reset();
    }
    m_currentUserId.clear();
}

void DsccBridge::setCurrentUser(const QString &userId,
                                const QString &userName,
                                const QString &accessToken,
                                const QString &refreshToken)
{
    Q_UNUSED(userName);

    const QString trimmedUserId = userId.trimmed();
    if (trimmedUserId.isEmpty() || accessToken.isEmpty()) {
        qWarning() << "DsccBridge refusing to initialize UserAssets without user id or access token";
        clearCurrentUser();
        return;
    }

    if (m_assets) {
        m_assets->Shutdown();
        m_assets.reset();
    }

    const QString domainDbPath = userDomainDbPath(trimmedUserId);
    QDir().mkpath(QFileInfo(domainDbPath).absolutePath());

    m_assets = std::make_unique<dscc::UserAssets>(domainDbPath, m_credential);
    connectAssetSignals();
    m_currentUserId = trimmedUserId;
    m_assets->SetCurrentUser(userId, accessToken, refreshToken);
    m_assets->Initialize();
}

void DsccBridge::clearCurrentUser()
{
    if (m_assets) {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_currentUserId.clear();
    emit domainListLoaded(QVariantList());
    emit domainSummaryLoaded(QString(), QVariantMap());
}

void DsccBridge::connectAssetSignals()
{
    if (!m_assets) {
        return;
    }

    connect(m_assets.get(), &dscc::UserAssets::DomainCreated,
            this, &DsccBridge::DomainCreated);

    connect(m_assets.get(), &dscc::UserAssets::DomainCreateFailed,
            this, &DsccBridge::DomainCreateFailed);
}

QString DsccBridge::userDomainDbPath(const QString &userId) const
{
    const QByteArray digest = QCryptographicHash::hash(userId.toUtf8(),
                                                       QCryptographicHash::Sha256)
                                  .toHex();
    return QDir(QDir(m_dsccDataRoot).filePath(QStringLiteral("users")))
        .filePath(QString::fromLatin1(digest) + QStringLiteral("/domain.db"));
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
    if (!m_assets) {
        emit domainListLoaded(QVariantList());
        return;
    }

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
    if (m_assets && !trimmedDomainCode.isEmpty()) {
        const auto info = m_assets->DetailDomainInfo(trimmedDomainCode);
        if (info.has_value()) {
            summary = domainInfoToSummary(*info);
        }
    }
    emit domainSummaryLoaded(domainCode, summary);
}

void DsccBridge::createDomain(const QVariantMap &info)
{
    if (!m_assets) {
        emit DomainCreateFailed(0, dscc::Notification());
        return;
    }

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

    m_assets->CreateDomain(domainInfo);
}
