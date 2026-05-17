#include "DsccBridge.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QMetaType>
#include <QStandardPaths>
#include <QStringList>
#include <algorithm>

#include "AppConfig.h"
#include "dscc/core/common/logger.h"
#include "dscc/core/db/domain_ops.h"
#include "dscc/core/interface/app_assets.h"

namespace {
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

QString logHash(const QString &value)
{
    const QString trimmed = value.trimmed();
    if (trimmed.isEmpty()) {
        return QStringLiteral("<empty>");
    }

    return QString::fromLatin1(QCryptographicHash::hash(trimmed.toUtf8(),
                                                        QCryptographicHash::Sha256)
                                   .toHex()
                                   .left(12));
}

QString notificationParamsText(const dscc::Notification &notification)
{
    QStringList parts;
    for (auto it = notification.params.cbegin(); it != notification.params.cend(); ++it) {
        parts.append(QStringLiteral("%1=%2").arg(it.key(), it.value().toString()));
    }
    return QStringLiteral("{%1}").arg(parts.join(QStringLiteral(", ")));
}

void logNotification(const QString &prefix, const dscc::Notification &notification)
{
    qWarning().noquote()
        << QStringLiteral("[DsccBridge] %1 code=%2 type=%3 localized=\"%4\" default=\"%5\" params=%6")
               .arg(prefix)
               .arg(static_cast<int>(notification.code))
               .arg(static_cast<int>(notification.type))
               .arg(notification.Localized())
               .arg(notification.DefaultText())
               .arg(notificationParamsText(notification));
}

QString notificationDisplayText(const dscc::Notification &notification,
                                const QString &fallback)
{
    QString message = notification.Localized().trimmed();
    if (message.isEmpty()) {
        message = notification.DefaultText().trimmed();
    }
    return message.isEmpty() ? fallback : message;
}

bool isTemporaryDomainCode(const QString &domainCode)
{
    return domainCode.startsWith(QStringLiteral("TMP_D"));
}

bool isDomainCreateFailed(const dscc::DomainInfo &info)
{
    return info.sync_status == dscc::db::kDomainSyncStatusFailed
           && isTemporaryDomainCode(info.domain_code);
}

bool isDomainInactive(const dscc::DomainInfo &info)
{
    return info.domain_status == dscc::db::kDomainStatusClosed
           || isDomainCreateFailed(info);
}

QString variantMapText(const QVariantMap &map)
{
    QStringList keys = map.keys();
    std::sort(keys.begin(), keys.end());

    QStringList parts;
    for (const QString &key : keys) {
        parts.append(QStringLiteral("%1=\"%2\"").arg(key, map.value(key).toString()));
    }
    return QStringLiteral("{%1}").arg(parts.join(QStringLiteral(", ")));
}

QVariantList visibleUsersToVariantList(const QList<dscc::VisibleUserInfo> &visibleUsers)
{
    QVariantList list;
    list.reserve(visibleUsers.size());
    for (const dscc::VisibleUserInfo &visibleUser : visibleUsers) {
        QVariantMap user;
        user.insert(QStringLiteral("account"), visibleUser.account);
        user.insert(QStringLiteral("authUserId"), visibleUser.auth_user_id);
        user.insert(QStringLiteral("authUserName"), visibleUser.auth_user_name);
        user.insert(QStringLiteral("displayName"), visibleUser.display_name);
        list.append(user);
    }
    return list;
}

void logDomainInfoSummarySource(const QString &domainCode, const dscc::DomainInfo &info)
{
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] loadDomainSummary raw domainCode=\"%1\" foundDomainCode=\"%2\" domainName=\"%3\" pubKeyLength=%4 pubKeyHash=%5 remarks=\"%6\" payType=%7 domainStatus=%8 syncStatus=%9 creatorUserId=\"%10\" creatorUserName=\"%11\" creatorDisplayName=\"%12\" createdAt=%13 createdAtIso=\"%14\" updatedAt=%15 updatedAtIso=\"%16\" visibleUsers=%17")
               .arg(domainCode)
               .arg(info.domain_code)
               .arg(info.domain_name)
               .arg(info.domain_pub_key.size())
               .arg(logHash(info.domain_pub_key))
               .arg(info.remarks)
               .arg(info.pay_type)
               .arg(info.domain_status)
               .arg(info.sync_status)
               .arg(info.creator_user_id)
               .arg(info.creator_user_name)
               .arg(info.creator_display_name)
               .arg(info.created_at)
               .arg(timestampToIsoString(info.created_at))
               .arg(info.updated_at)
               .arg(timestampToIsoString(info.updated_at))
               .arg(info.visible_users.size());
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
    , m_serverUrl(serverUrl.trimmed().isEmpty()
                      ? QString::fromLatin1(AppCfg::API_BASE_URL)
                      : serverUrl.trimmed())
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
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] initialize metaDbPath=\"%1\" dsccDataRoot=\"%2\" serverUrl=\"%3\"")
               .arg(m_metaDbPath, m_dsccDataRoot, m_serverUrl);

    const QString localDataDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(localDataDir);
    const QString coreLogPath = QDir(localDataDir).filePath(QStringLiteral("dscc-core.log"));
    dscc::detail::SetLoggerFilePath(coreLogPath);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] corelib log file: \"%1\"").arg(coreLogPath);

    dscc::AppAssets appAssets(m_metaDbPath);
    appAssets.AddTrustedServer(m_serverUrl, QStringLiteral("{}"));
}

void DsccBridge::shutdown()
{
    if (m_assets) {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_domainCreateFailureMessages.clear();
    m_currentUserId.clear();
    m_currentUserName.clear();
}

void DsccBridge::setCurrentUser(const QString &userId,
                                const QString &userName,
                                const QString &accessToken,
                                const QString &refreshToken)
{
    const QString trimmedUserId = userId.trimmed();
    const QString trimmedUserName = userName.trimmed();
    if (trimmedUserId.isEmpty() || accessToken.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] setCurrentUser refused userHash=%1 accessTokenLength=%2")
                   .arg(logHash(trimmedUserId))
                   .arg(accessToken.size());
        clearCurrentUser();
        return;
    }

    if (m_assets) {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_domainCreateFailureMessages.clear();

    const QString domainDbPath = userDomainDbPath(trimmedUserId);
    QDir().mkpath(QFileInfo(domainDbPath).absolutePath());

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] setCurrentUser userHash=%1 userName=\"%2\" domainDbPath=\"%3\" accessTokenLength=%4 refreshTokenLength=%5")
               .arg(logHash(trimmedUserId), trimmedUserName, domainDbPath)
               .arg(accessToken.size())
               .arg(refreshToken.size());

    m_assets = std::make_unique<dscc::UserAssets>(domainDbPath, m_credential);
    connectAssetSignals();
    m_currentUserId = trimmedUserId;
    m_currentUserName = trimmedUserName;
    m_assets->SetCurrentUser(trimmedUserId, m_serverUrl, accessToken, refreshToken);
    m_assets->Initialize();
}

void DsccBridge::clearCurrentUser()
{
    if (m_assets) {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_domainCreateFailureMessages.clear();
    m_currentUserId.clear();
    m_currentUserName.clear();
    emit domainListLoaded(QVariantList());
    emit domainSummaryLoaded(QString(), QVariantMap());
}

void DsccBridge::connectAssetSignals()
{
    if (!m_assets) {
        return;
    }

    connect(m_assets.get(), &dscc::UserAssets::DomainCreated,
            this, [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote()
                    << QStringLiteral("[DsccBridge] corelib DomainCreated operationId=%1 domainCode=\"%2\"")
                           .arg(operationId)
                           .arg(domainCode);
                emit domainCreated(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainCreateFailed,
            this, [this](uint32_t operationId, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib DomainCreateFailed operationId=%1")
                                    .arg(operationId),
                                notification);
                m_domainCreateFailureMessages.insert(
                    operationId,
                    notificationDisplayText(notification, QStringLiteral("安全域创建失败")));
                emit domainCreateFailed(operationId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdated,
            this, [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote()
                    << QStringLiteral("[DsccBridge] corelib DomainUpdated operationId=%1 domainCode=\"%2\"")
                           .arg(operationId)
                           .arg(domainCode);
                emit domainDescUpdated(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdateFailed,
            this, [this](uint32_t operationId,
                         QString domainCode,
                         dscc::Notification notification) {
                logNotification(QStringLiteral("corelib DomainUpdateFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainDescUpdateFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote()
                    << QStringLiteral("[DsccBridge] corelib CloseDomainSuccess operationId=%1 domainCode=\"%2\"")
                           .arg(operationId)
                           .arg(domainCode);
                emit domainClosed(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainFailed,
            this, [this](uint32_t operationId,
                         QString domainCode,
                         dscc::Notification notification) {
                logNotification(QStringLiteral("corelib CloseDomainFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainCloseFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode, QString userId) {
                qInfo().noquote()
                    << QStringLiteral("[DsccBridge] corelib AddUserToDomainSuccess operationId=%1 domainCode=\"%2\" userIdHash=%3")
                           .arg(operationId)
                           .arg(domainCode)
                           .arg(logHash(userId));
                emit addUserToDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainFailed,
            this, [this](uint32_t operationId,
                         QString domainCode,
                         QString userId,
                         dscc::Notification notification) {
                logNotification(QStringLiteral("corelib AddUserToDomainFailed operationId=%1 domainCode=\"%2\" userIdHash=%3")
                                    .arg(operationId)
                                    .arg(domainCode)
                                    .arg(logHash(userId)),
                                notification);
                emit addUserToDomainFailed(operationId, domainCode, userId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainSuccess,
            this, [this](uint32_t operationId, QString domainCode, QString userId) {
                qInfo().noquote()
                    << QStringLiteral("[DsccBridge] corelib RemoveUserFromDomainSuccess operationId=%1 domainCode=\"%2\" userIdHash=%3")
                           .arg(operationId)
                           .arg(domainCode)
                           .arg(logHash(userId));
                emit removeUserFromDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainFailed,
            this, [this](uint32_t operationId,
                         QString domainCode,
                         QString userId,
                         dscc::Notification notification) {
                logNotification(QStringLiteral("corelib RemoveUserFromDomainFailed operationId=%1 domainCode=\"%2\" userIdHash=%3")
                                    .arg(operationId)
                                    .arg(domainCode)
                                    .arg(logHash(userId)),
                                notification);
                emit removeUserFromDomainFailed(operationId, domainCode, userId, notification);
            });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()),
            &dscc::ActiveNotify::MessageReceived,
            this,
            [](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib MessageReceived"), notification);
            });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()),
            &dscc::ActiveNotify::WarningOccurred,
            this,
            [](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib WarningOccurred"), notification);
            });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()),
            &dscc::ActiveNotify::ErrorOccurred,
            this,
            [](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib ErrorOccurred"), notification);
            });
}

QString DsccBridge::userDomainDbPath(const QString &userId) const
{
    const QByteArray digest = QCryptographicHash::hash(userId.toUtf8(),
                                                       QCryptographicHash::Sha256)
                                  .toHex();
    return QDir(QDir(m_dsccDataRoot).filePath(QStringLiteral("users")))
        .filePath(QString::fromLatin1(digest) + QStringLiteral("/domain.db"));
}

bool DsccBridge::isDomainInactiveForOperation(const QString &domainCode) const
{
    if (!m_assets) {
        return false;
    }

    const auto info = m_assets->DetailDomainInfo(domainCode);
    if (!info.has_value()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] inactive domain check skipped because domain was not found domainCode=\"%1\"")
                   .arg(domainCode);
        return false;
    }

    return isDomainInactive(*info);
}

QVariantMap DsccBridge::domainInfoToSummary(const dscc::DomainInfo &info) const
{
    QVariantMap summary;
    const bool domainCreateFailed = isDomainCreateFailed(info);
    summary.insert(QStringLiteral("domainCode"), info.domain_code);
    summary.insert(QStringLiteral("name"), info.domain_name);
    summary.insert(QStringLiteral("pubKey"), info.domain_pub_key);
    summary.insert(QStringLiteral("description"), info.remarks);
    summary.insert(QStringLiteral("payer"),
                   info.pay_type == 2 ? QStringLiteral("使用者") : QStringLiteral("创建者"));
    QString statusText = info.domain_status == dscc::db::kDomainStatusClosed
                             ? QStringLiteral("已关闭")
                             : QStringLiteral("运行中");
    if (domainCreateFailed) {
        statusText = QStringLiteral("创建失败");
    }
    summary.insert(QStringLiteral("status"), statusText);
    summary.insert(QStringLiteral("isInactive"), isDomainInactive(info));
    summary.insert(QStringLiteral("creator"),
                   info.creator_user_name.isEmpty() ? info.creator_user_id
                                                    : info.creator_user_name);
    summary.insert(QStringLiteral("createdAt"), timestampToIsoString(info.created_at));
    summary.insert(QStringLiteral("updatedAt"), timestampToIsoString(info.updated_at));
    return summary;
}

QVariantMap DsccBridge::instanceInfoToVariant(const dscc::InstanceInfo &info) const
{
    QVariantMap map;
    map.insert(QStringLiteral("instanceCode"), info.instance_code);
    map.insert(QStringLiteral("domainCode"), info.domain_code);
    map.insert(QStringLiteral("instanceName"), info.instance_name);
    map.insert(QStringLiteral("totalRunTime"), info.total_run_time);
    map.insert(QStringLiteral("volumnId"), info.volumn_id);
    map.insert(QStringLiteral("volumnSize"), quint64(info.volumn_size));
    map.insert(QStringLiteral("diskPartition"), info.disk_partition);
    map.insert(QStringLiteral("creatorUserId"), info.creator_user_id);
    map.insert(QStringLiteral("instanceStatus"), info.instance_status);
    map.insert(QStringLiteral("syncStatus"), info.sync_status);
    map.insert(QStringLiteral("createdAt"), timestampToIsoString(info.created_at));
    return map;
}

QString DsccBridge::domainCreateFailureMessage(uint32_t operationId,
                                               const QString &fallback) const
{
    const QString message = m_domainCreateFailureMessages.value(operationId).trimmed();
    if (!message.isEmpty()) {
        return message;
    }

    const QString trimmedFallback = fallback.trimmed();
    return trimmedFallback.isEmpty() ? QStringLiteral("安全域创建失败") : trimmedFallback;
}

QString DsccBridge::notificationMessage(const QVariant &notification,
                                        const QString &fallback) const
{
    if (notification.canConvert<dscc::Notification>()) {
        return notificationDisplayText(notification.value<dscc::Notification>(), fallback);
    }

    const QString directMessage = notification.toString().trimmed();
    if (!directMessage.isEmpty()) {
        return directMessage;
    }

    return fallback.trimmed();
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

void DsccBridge::loadInstances(const QString &domainCode)
{
    if (!m_assets) {
        emit instancesLoaded(domainCode, QVariantList());
        return;
    }

    QList<dscc::InstanceInfo> instances = m_assets->ListInstances(domainCode);
    std::sort(instances.begin(), instances.end(),
              [](const dscc::InstanceInfo &a, const dscc::InstanceInfo &b) {
                  return a.created_at > b.created_at;
              });

    QVariantList list;
    list.reserve(instances.size());
    for (const dscc::InstanceInfo &inst : instances) {
        list.append(instanceInfoToVariant(inst));
    }
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] loadInstances domainCode=\"%1\" count=%2")
               .arg(domainCode)
               .arg(list.size());
    emit instancesLoaded(domainCode, list);
}

void DsccBridge::loadDomainSummary(const QString &domainCode)
{
    QVariantMap summary;
    const QString trimmedDomainCode = domainCode.trimmed();
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] loadDomainSummary request domainCode=\"%1\" trimmed=\"%2\" hasAssets=%3 currentUserHash=%4")
               .arg(domainCode)
               .arg(trimmedDomainCode)
               .arg(m_assets != nullptr)
               .arg(logHash(m_currentUserId));

    if (m_assets && !trimmedDomainCode.isEmpty()) {
        const auto info = m_assets->DetailDomainInfo(trimmedDomainCode);
        if (info.has_value()) {
            logDomainInfoSummarySource(trimmedDomainCode, *info);
            summary = domainInfoToSummary(*info);
            summary.insert(QStringLiteral("visibleUsers"),
                           visibleUsersToVariantList(info->visible_users));
        } else {
            qWarning().noquote()
                << QStringLiteral("[DsccBridge] loadDomainSummary DetailDomainInfo returned empty for domainCode=\"%1\"")
                       .arg(trimmedDomainCode);
        }
    } else if (!m_assets) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] loadDomainSummary skipped because UserAssets is not initialized");
    } else {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] loadDomainSummary skipped because domainCode is empty");
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] loadDomainSummary emit domainCode=\"%1\" summarySize=%2 summary=%3")
               .arg(domainCode)
               .arg(summary.size())
               .arg(variantMapText(summary));
    emit domainSummaryLoaded(domainCode, summary);
}

void DsccBridge::createDomain(const QVariantMap &info)
{
    if (!m_assets) {
        qWarning().noquote() << QStringLiteral("[DsccBridge] createDomain rejected because UserAssets is not initialized");
        m_domainCreateFailureMessages.insert(0, QStringLiteral("安全域创建失败"));
        emit domainCreateFailed(0, dscc::Notification());
        return;
    }

    dscc::DomainInfo domainInfo;
    domainInfo.domain_name = info.value("domainName").toString().trimmed();
    const QString creatorDisplay = m_currentUserName.isEmpty() ? m_currentUserId : m_currentUserName;
    domainInfo.creator_user_id = m_currentUserId;
    domainInfo.creator_user_name = creatorDisplay;
    domainInfo.creator_display_name = creatorDisplay;

    const QString remarks = info.value("remarks").toString().trimmed();
    domainInfo.remarks = remarks.isEmpty() ? domainInfo.domain_name : remarks;

    const QString payer = info.value("payer").toString().trimmed();
    domainInfo.pay_type = (payer == QStringLiteral("使用者")) ? 2 : 1;

    const QVariantList visibleUsers = info.value("visibleUsers").toList();
    int visibleUserIndex = 0;
    for (const QVariant &v : visibleUsers) {
        const QVariantMap u = v.toMap();
        dscc::VisibleUserInfo user;
        user.account = u.value("account").toString().trimmed();
        user.auth_user_id = u.value("authUserId").toString().trimmed();
        user.auth_user_name = u.value("authUserName").toString().trimmed();
        user.display_name = u.value("displayName").toString().trimmed();
        if (user.display_name.isEmpty()) {
            user.display_name = user.auth_user_name.isEmpty() ? user.account : user.auth_user_name;
        }
        if (user.auth_user_name.isEmpty()) {
            user.auth_user_name = user.display_name.isEmpty() ? user.account : user.display_name;
        }
        if (!user.account.isEmpty() && !user.auth_user_id.isEmpty()) {
            domainInfo.visible_users.append(user);
            qInfo().noquote()
                << QStringLiteral("[DsccBridge] createDomain visibleUser[%1] accepted account=\"%2\" authUserIdHash=%3 authUserName=\"%4\" displayName=\"%5\"")
                       .arg(visibleUserIndex)
                       .arg(user.account, logHash(user.auth_user_id), user.auth_user_name, user.display_name);
        } else {
            qWarning().noquote()
                << QStringLiteral("[DsccBridge] createDomain visibleUser[%1] skipped account=\"%2\" authUserIdHash=%3 authUserName=\"%4\" displayName=\"%5\"")
                       .arg(visibleUserIndex)
                       .arg(user.account, logHash(user.auth_user_id), user.auth_user_name, user.display_name);
        }
        ++visibleUserIndex;
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] createDomain request domainName=\"%1\" nameLength=%2 remarksLength=%3 remarksAutoFilled=%4 payerRaw=\"%5\" payType=%6 visibleUsersInput=%7 visibleUsersAccepted=%8 currentUserHash=%9 creatorUserIdHash=%10 creatorUserName=\"%11\" creatorDisplayName=\"%12\" bridgePubKeyEmpty=%13 bridgePriKeyEmpty=%14")
               .arg(domainInfo.domain_name)
               .arg(domainInfo.domain_name.size())
               .arg(domainInfo.remarks.size())
               .arg(remarks.isEmpty())
               .arg(payer)
               .arg(domainInfo.pay_type)
               .arg(visibleUsers.size())
               .arg(domainInfo.visible_users.size())
               .arg(logHash(m_currentUserId))
               .arg(logHash(domainInfo.creator_user_id))
               .arg(domainInfo.creator_user_name)
               .arg(domainInfo.creator_display_name)
               .arg(domainInfo.domain_pub_key.isEmpty())
               .arg(domainInfo.domain_pri_key.isEmpty());

    const dscc::Handle handle = m_assets->CreateDomain(domainInfo);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] createDomain submitted operationId=%1")
               .arg(handle.GetOperationId());
    Q_UNUSED(handle);
}

void DsccBridge::updateDomainDesc(const QString &domainCode, const QString &desc)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedDesc = desc.trimmed();
    if (!m_assets) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] updateDomainDesc rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainDescUpdateFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] updateDomainDesc rejected because domainCode is empty");
        emit domainDescUpdateFailed(
            0,
            QString(),
            dscc::Notification(dscc::Notification::kUpdateDomainDescEmptyDomainCode,
                               dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode)) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] updateDomainDesc rejected because domain is inactive domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainDescUpdateFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] updateDomainDesc request domainCode=\"%1\" descLength=%2 currentUserHash=%3")
               .arg(trimmedDomainCode)
               .arg(trimmedDesc.size())
               .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->UpdateDomainDesc(trimmedDomainCode, trimmedDesc);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] updateDomainDesc submitted operationId=%1 domainCode=\"%2\"")
               .arg(handle.GetOperationId())
               .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::addUserToDomain(const QString &domainCode, const QString &userId)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedUserId = userId.trimmed();
    if (!m_assets) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] addUserToDomain rejected because UserAssets is not initialized domainCode=\"%1\" userIdHash=%2")
                   .arg(trimmedDomainCode)
                   .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] addUserToDomain rejected because domainCode is empty userIdHash=%1")
                   .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(
            0,
            QString(),
            trimmedUserId,
            dscc::Notification(dscc::Notification::kAddUserToDomainEmptyDomainCode,
                               dscc::Notification::kError));
        return;
    }

    if (trimmedUserId.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] addUserToDomain rejected because userId is empty domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit addUserToDomainFailed(
            0,
            trimmedDomainCode,
            QString(),
            dscc::Notification(dscc::Notification::kAddUserToDomainEmptyUserId,
                               dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode)) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] addUserToDomain rejected because domain is inactive domainCode=\"%1\" userIdHash=%2")
                   .arg(trimmedDomainCode)
                   .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] addUserToDomain request domainCode=\"%1\" userIdHash=%2 currentUserHash=%3")
               .arg(trimmedDomainCode)
               .arg(logHash(trimmedUserId))
               .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->AddUserToDomain(trimmedDomainCode, trimmedUserId);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] addUserToDomain submitted operationId=%1 domainCode=\"%2\" userIdHash=%3")
               .arg(handle.GetOperationId())
               .arg(trimmedDomainCode)
               .arg(logHash(trimmedUserId));
    Q_UNUSED(handle);
}

void DsccBridge::removeUserFromDomain(const QString &domainCode, const QString &userId)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedUserId = userId.trimmed();
    if (!m_assets) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because UserAssets is not initialized domainCode=\"%1\" userIdHash=%2")
                   .arg(trimmedDomainCode)
                   .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because domainCode is empty userIdHash=%1")
                   .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(
            0,
            QString(),
            trimmedUserId,
            dscc::Notification(dscc::Notification::kRemoveUserFromDomainEmptyDomainCode,
                               dscc::Notification::kError));
        return;
    }

    if (trimmedUserId.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because userId is empty domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit removeUserFromDomainFailed(
            0,
            trimmedDomainCode,
            QString(),
            dscc::Notification(dscc::Notification::kRemoveUserFromDomainEmptyUserId,
                               dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode)) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because domain is inactive domainCode=\"%1\" userIdHash=%2")
                   .arg(trimmedDomainCode)
                   .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] removeUserFromDomain request domainCode=\"%1\" userIdHash=%2 currentUserHash=%3")
               .arg(trimmedDomainCode)
               .arg(logHash(trimmedUserId))
               .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->RemoveUserFromDomain(trimmedDomainCode, trimmedUserId);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] removeUserFromDomain submitted operationId=%1 domainCode=\"%2\" userIdHash=%3")
               .arg(handle.GetOperationId())
               .arg(trimmedDomainCode)
               .arg(logHash(trimmedUserId));
    Q_UNUSED(handle);
}

void DsccBridge::closeDomain(const QString &domainCode)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] closeDomain rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainCloseFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty()) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] closeDomain rejected because domainCode is empty");
        emit domainCloseFailed(
            0,
            QString(),
            dscc::Notification(dscc::Notification::kCloseDomainEmptyDomainCode,
                               dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode)) {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] closeDomain rejected because domain is inactive domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainCloseFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    qInfo().noquote()
        << QStringLiteral("[DsccBridge] closeDomain request domainCode=\"%1\" currentUserHash=%2")
               .arg(trimmedDomainCode)
               .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->CloseDomain(trimmedDomainCode);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] closeDomain submitted operationId=%1 domainCode=\"%2\"")
               .arg(handle.GetOperationId())
               .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}
