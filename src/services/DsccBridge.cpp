#include "DsccBridge.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QMetaType>
#include <QStandardPaths>
#include <QStringList>
#include <QTimer>
#include <algorithm>

#include "AppConfig.h"
#include "SentryBridge.h"
#include "dscc/core/common/logger.h"
#include "dscc/core/db/table/domain_ops.h"
#include "dscc/core/interface/app_assets.h"

namespace
{
// Interval for the session-scoped auto-refresh that keeps the console in sync
// with domains/audits/messages created on other endpoints (e.g. the CLI).
constexpr int kSyncTimerIntervalMs = 15 * 1000;
} // namespace

// Notifications logged under this category are reported to Sentry explicitly (with
// structured tags/extra) by logNotification() below, so sentryMessageHandler (main.cpp)
// skips them to avoid double-reporting the same notification as a flattened string.
Q_LOGGING_CATEGORY(dsccBridgeLog, "dscc")

namespace
{
QString timestampToIsoString(uint64_t timestamp)
{
    if (timestamp == 0)
    {
        return QString();
    }

    const qint64 value = static_cast<qint64>(timestamp);
    const QDateTime dateTime =
        timestamp > 100000000000ULL ? QDateTime::fromMSecsSinceEpoch(value) : QDateTime::fromSecsSinceEpoch(value);
    return dateTime.toString(Qt::ISODate);
}

QString logHash(const QString &value)
{
    const QString trimmed = value.trimmed();
    if (trimmed.isEmpty())
    {
        return QStringLiteral("<empty>");
    }

    return QString::fromLatin1(QCryptographicHash::hash(trimmed.toUtf8(), QCryptographicHash::Sha256).toHex().left(12));
}

QString notificationParamsText(const dscc::Notification &notification)
{
    QStringList parts;
    for (auto it = notification.params.cbegin(); it != notification.params.cend(); ++it)
    {
        parts.append(QStringLiteral("%1=%2").arg(it.key(), it.value().toString()));
    }
    return QStringLiteral("{%1}").arg(parts.join(QStringLiteral(", ")));
}

QVariantMap notificationParamsToVariantMap(const dscc::Notification &notification)
{
    QVariantMap map;
    for (auto it = notification.params.cbegin(); it != notification.params.cend(); ++it)
    {
        map.insert(it.key(), it.value());
    }
    return map;
}

void logNotification(const QString &prefix, const dscc::Notification &notification)
{
    qCWarning(dsccBridgeLog).noquote()
        << QStringLiteral("[DsccBridge] %1 code=%2 type=%3 localized=\"%4\" default=\"%5\" params=%6")
               .arg(prefix)
               .arg(static_cast<int>(notification.code))
               .arg(static_cast<int>(notification.type))
               .arg(notification.Localized())
               .arg(notification.DefaultText())
               .arg(notificationParamsText(notification));

    const QString message = notification.Localized().trimmed().isEmpty() ? notification.DefaultText().trimmed()
                                                                         : notification.Localized().trimmed();
    QVariantMap data = notificationParamsToVariantMap(notification);
    data.insert(QStringLiteral("dscc_code"), static_cast<int>(notification.code));

    if (notification.type == dscc::Notification::kError)
    {
        QVariantMap tags;
        tags.insert(QStringLiteral("dscc_code"), static_cast<int>(notification.code));
        SentryBridge::captureError(QStringLiteral("dscc"), QStringLiteral("%1: %2").arg(prefix, message), tags, data);
    }
    else
    {
        const QString level =
            notification.type == dscc::Notification::kWarning ? QStringLiteral("warning") : QStringLiteral("info");
        SentryBridge::addBreadcrumb(QStringLiteral("dscc"), level, QStringLiteral("%1: %2").arg(prefix, message), data);
    }
}

QString notificationDisplayText(const dscc::Notification &notification, const QString &fallback)
{
    QString message = notification.Localized().trimmed();
    if (message.isEmpty())
    {
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
    return info.sync_status == dscc::db::kDomainSyncStatusFailed && isTemporaryDomainCode(info.domain_code);
}

bool isDomainInactive(const dscc::DomainInfo &info)
{
    return info.domain_status == dscc::db::kDomainStatusClosed || isDomainCreateFailed(info);
}

QString variantMapText(const QVariantMap &map)
{
    QStringList keys = map.keys();
    std::sort(keys.begin(), keys.end());

    QStringList parts;
    for (const QString &key : keys)
    {
        parts.append(QStringLiteral("%1=\"%2\"").arg(key, map.value(key).toString()));
    }
    return QStringLiteral("{%1}").arg(parts.join(QStringLiteral(", ")));
}

QVariantList visibleUsersToVariantList(const QList<dscc::VisibleUserInfo> &visibleUsers)
{
    QVariantList list;
    list.reserve(visibleUsers.size());
    for (const dscc::VisibleUserInfo &visibleUser : visibleUsers)
    {
        QVariantMap user;
        user.insert(QStringLiteral("account"), visibleUser.account);
        user.insert(QStringLiteral("authUserId"), visibleUser.auth_user_id);
        user.insert(QStringLiteral("authUserName"), visibleUser.auth_user_name);
        user.insert(QStringLiteral("displayName"), visibleUser.display_name);
        list.append(user);
    }
    return list;
}

void insertUserNameLookup(QHash<QString, QString> *lookup, const QString &userId, const QString &userName)
{
    if (!lookup)
    {
        return;
    }

    const QString trimmedUserId = userId.trimmed();
    const QString trimmedUserName = userName.trimmed();
    if (!trimmedUserId.isEmpty() && !trimmedUserName.isEmpty())
    {
        lookup->insert(trimmedUserId, trimmedUserName);
    }
}

QHash<QString, QString> buildUserNameLookup(const QList<dscc::VisibleUserInfo> &visibleUsers,
                                            const QString &currentUserId, const QString &currentUserName)
{
    QHash<QString, QString> lookup;
    insertUserNameLookup(&lookup, currentUserId, currentUserName);
    for (const dscc::VisibleUserInfo &visibleUser : visibleUsers)
    {
        insertUserNameLookup(&lookup, visibleUser.auth_user_id, visibleUser.auth_user_name);
    }
    return lookup;
}

void logDomainInfoSummarySource(const QString &domainCode, const dscc::DomainInfo &info)
{
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] loadDomainSummary raw domainCode=\"%1\" foundDomainCode=\"%2\" "
                          "domainName=\"%3\" pubKeyLength=%4 pubKeyHash=%5 remarks=\"%6\" payType=%7 domainStatus=%8 "
                          "syncStatus=%9 creatorUserId=\"%10\" creatorUserName=\"%11\" creatorDisplayName=\"%12\" "
                          "createdAt=%13 createdAtIso=\"%14\" updatedAt=%15 updatedAtIso=\"%16\" visibleUsers=%17")
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
} // namespace

namespace
{
void registerDsccBridgeMetaTypes()
{
    static const bool registered = [] {
        qRegisterMetaType<dscc::Notification>("dscc::Notification");
        qRegisterMetaType<dscc::Notification>("Notification");
        qRegisterMetaType<quint64>("quint64");
        qRegisterMetaType<uint64_t>("uint64_t");
        return true;
    }();
    Q_UNUSED(registered);
}
} // namespace

DsccBridge::DsccBridge(const QString &metaDbPath, const QString &dsccDataRoot, const QString &serverUrl,
                       const QString &credential, QObject *parent)
    : QObject(parent), m_metaDbPath(metaDbPath), m_dsccDataRoot(QDir::cleanPath(dsccDataRoot)),
      m_serverUrl(serverUrl.trimmed().isEmpty() ? QString::fromLatin1(AppCfg::currentProfile().apiBaseUrl)
                                                : serverUrl.trimmed()),
      m_credential(credential)
{
    registerDsccBridgeMetaTypes();

    m_syncTimer = new QTimer(this);
    m_syncTimer->setInterval(kSyncTimerIntervalMs);
    connect(m_syncTimer, &QTimer::timeout, this, [this]() { triggerSyncData(); });
}

DsccBridge::~DsccBridge()
{
    shutdown();
}

void DsccBridge::initialize()
{
    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] initialize metaDbPath=\"%1\" dsccDataRoot=\"%2\" serverUrl=\"%3\"")
                             .arg(m_metaDbPath, m_dsccDataRoot, m_serverUrl);

    const QString localDataDir = QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation))
                                     .filePath(AppCfg::environmentDirName());
    QDir().mkpath(localDataDir);
    const QString coreLogPath = QDir(localDataDir).filePath(QStringLiteral("dscc-core.log"));
    dscc::detail::SetLoggerFilePath(coreLogPath);
    qInfo().noquote() << QStringLiteral("[DsccBridge] corelib log file: \"%1\"").arg(coreLogPath);

    dscc::AppAssets appAssets(m_metaDbPath);
    appAssets.AddTrustedServer(m_serverUrl, QStringLiteral("{}"));
}

void DsccBridge::shutdown()
{
    stopSyncTimer();
    if (m_assets)
    {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_initializingUserAssets = false;
    m_userAssetsInitializationError = dscc::Notification();
    m_domainCreateFailureMessages.clear();
    m_encryptFileOperations.clear();
    m_domainVisibleUsersCache.clear();
    m_userNameCache.clear();
    m_currentUserId.clear();
    m_currentUserName.clear();
}

void DsccBridge::setCurrentUser(const QString &userId, const QString &userName, const QString &accessToken,
                                const QString &refreshToken)
{
    const QString trimmedUserId = userId.trimmed();
    const QString trimmedUserName = userName.trimmed();
    if (trimmedUserId.isEmpty() || accessToken.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] setCurrentUser refused userHash=%1 accessTokenLength=%2")
                                    .arg(logHash(trimmedUserId))
                                    .arg(accessToken.size());
        clearCurrentUser();
        return;
    }

    stopSyncTimer();
    if (m_assets)
    {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_initializingUserAssets = false;
    m_userAssetsInitializationError = dscc::Notification();
    m_domainCreateFailureMessages.clear();
    m_encryptFileOperations.clear();
    m_domainVisibleUsersCache.clear();
    m_userNameCache.clear();

    const QString domainDbPath = userDomainDbPath(trimmedUserId);
    QDir().mkpath(QFileInfo(domainDbPath).absolutePath());

    qInfo().noquote() << QStringLiteral("[DsccBridge] setCurrentUser userHash=%1 userName=\"%2\" domainDbPath=\"%3\" "
                                        "accessTokenLength=%4 refreshTokenLength=%5")
                             .arg(logHash(trimmedUserId), trimmedUserName, domainDbPath)
                             .arg(accessToken.size())
                             .arg(refreshToken.size());

    m_assets = std::make_unique<dscc::UserAssets>(domainDbPath, m_credential);
    connectAssetSignals();
    m_assets->SetMetaDbPath(m_metaDbPath);
    m_currentUserId = trimmedUserId;
    m_currentUserName = trimmedUserName;
    m_assets->SetCurrentUser(trimmedUserId, trimmedUserName, m_serverUrl, accessToken, refreshToken);
    m_initializingUserAssets = true;
    m_userAssetsInitializationError = dscc::Notification();
    const bool domainDbExistedBeforeInitialize = QFileInfo::exists(domainDbPath);
    m_assets->Initialize();
    m_initializingUserAssets = false;

    if (m_userAssetsInitializationError.IsEmpty() && !domainDbExistedBeforeInitialize &&
        !QFileInfo::exists(domainDbPath))
    {
        m_userAssetsInitializationError =
            dscc::Notification(dscc::Notification::kDbNotInitialized, dscc::Notification::kError);
    }

    if (!m_userAssetsInitializationError.IsEmpty())
    {
        const dscc::Notification notification = m_userAssetsInitializationError;
        logNotification(QStringLiteral("corelib UserAssets initialization failed"), notification);
        if (m_assets)
        {
            m_assets->Shutdown();
            m_assets.reset();
        }
        m_currentUserId.clear();
        m_currentUserName.clear();
        m_domainCreateFailureMessages.clear();
        m_encryptFileOperations.clear();
        m_domainVisibleUsersCache.clear();
        m_userNameCache.clear();
        emit coreErrorOccurred(notification);
        emit domainListLoaded(QVariantList());
        emit domainSummaryLoaded(QString(), QVariantMap());
        emit messageListLoaded(QVariantList());
    }
    else if (m_assets)
    {
        // Pull server state immediately after login so the lists aren't empty
        // while the corelib daemon waits ~10s for its first periodic poll, then
        // keep them fresh for multi-endpoint sync via the session timer.
        triggerSyncData();
        startSyncTimer();
    }
}

void DsccBridge::clearCurrentUser()
{
    stopSyncTimer();
    if (m_assets)
    {
        m_assets->Shutdown();
        m_assets.reset();
    }
    m_initializingUserAssets = false;
    m_userAssetsInitializationError = dscc::Notification();
    m_domainCreateFailureMessages.clear();
    m_encryptFileOperations.clear();
    m_domainVisibleUsersCache.clear();
    m_userNameCache.clear();
    m_currentUserId.clear();
    m_currentUserName.clear();
    emit domainListLoaded(QVariantList());
    emit domainSummaryLoaded(QString(), QVariantMap());
    emit messageListLoaded(QVariantList());
}

void DsccBridge::connectAssetSignals()
{
    if (!m_assets)
    {
        return;
    }

    connect(m_assets.get(), &dscc::UserAssets::DomainCreated, this, [this](uint32_t operationId, QString domainCode) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib DomainCreated operationId=%1 domainCode=\"%2\"")
                                 .arg(operationId)
                                 .arg(domainCode);
        emit domainCreated(operationId, domainCode);
    });

    connect(m_assets.get(), &dscc::UserAssets::DomainCreateFailed, this,
            [this](uint32_t operationId, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib DomainCreateFailed operationId=%1").arg(operationId),
                                notification);
                m_domainCreateFailureMessages.insert(
                    operationId, notificationDisplayText(notification, tr("Security domain creation failed")));
                emit domainCreateFailed(operationId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdated, this, [this](uint32_t operationId, QString domainCode) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib DomainUpdated operationId=%1 domainCode=\"%2\"")
                                 .arg(operationId)
                                 .arg(domainCode);
        emit domainDescUpdated(operationId, domainCode);
    });

    connect(m_assets.get(), &dscc::UserAssets::DomainUpdateFailed, this,
            [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib DomainUpdateFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainDescUpdateFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote() << QStringLiteral(
                                         "[DsccBridge] corelib CloseDomainSuccess operationId=%1 domainCode=\"%2\"")
                                         .arg(operationId)
                                         .arg(domainCode);
                emit domainClosed(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::CloseDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib CloseDomainFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainCloseFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::DeleteDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote() << QStringLiteral(
                                         "[DsccBridge] corelib DeleteDomainSuccess operationId=%1 domainCode=\"%2\"")
                                         .arg(operationId)
                                         .arg(domainCode);
                emit domainDeleted(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::DeleteDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib DeleteDomainFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainDeleteFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::ArchiveDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote() << QStringLiteral(
                                         "[DsccBridge] corelib ArchiveDomainSuccess operationId=%1 domainCode=\"%2\"")
                                         .arg(operationId)
                                         .arg(domainCode);
                emit domainArchived(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::ArchiveDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib ArchiveDomainFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainArchiveFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::UnarchiveDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode) {
                qInfo().noquote() << QStringLiteral(
                                         "[DsccBridge] corelib UnarchiveDomainSuccess operationId=%1 domainCode=\"%2\"")
                                         .arg(operationId)
                                         .arg(domainCode);
                emit domainUnarchived(operationId, domainCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::UnarchiveDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib UnarchiveDomainFailed operationId=%1 domainCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(domainCode),
                                notification);
                emit domainUnarchiveFailed(operationId, domainCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode, QString userId) {
                qInfo().noquote()
                    << QStringLiteral(
                           "[DsccBridge] corelib AddUserToDomainSuccess operationId=%1 domainCode=\"%2\" userIdHash=%3")
                           .arg(operationId)
                           .arg(domainCode)
                           .arg(logHash(userId));
                emit addUserToDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::AddUserToDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, QString userId, dscc::Notification notification) {
                logNotification(
                    QStringLiteral("corelib AddUserToDomainFailed operationId=%1 domainCode=\"%2\" userIdHash=%3")
                        .arg(operationId)
                        .arg(domainCode)
                        .arg(logHash(userId)),
                    notification);
                emit addUserToDomainFailed(operationId, domainCode, userId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainSuccess, this,
            [this](uint32_t operationId, QString domainCode, QString userId) {
                qInfo().noquote() << QStringLiteral("[DsccBridge] corelib RemoveUserFromDomainSuccess operationId=%1 "
                                                    "domainCode=\"%2\" userIdHash=%3")
                                         .arg(operationId)
                                         .arg(domainCode)
                                         .arg(logHash(userId));
                emit removeUserFromDomainSuccess(operationId, domainCode, userId);
            });

    connect(m_assets.get(), &dscc::UserAssets::RemoveUserFromDomainFailed, this,
            [this](uint32_t operationId, QString domainCode, QString userId, dscc::Notification notification) {
                logNotification(
                    QStringLiteral("corelib RemoveUserFromDomainFailed operationId=%1 domainCode=\"%2\" userIdHash=%3")
                        .arg(operationId)
                        .arg(domainCode)
                        .arg(logHash(userId)),
                    notification);
                emit removeUserFromDomainFailed(operationId, domainCode, userId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::AuditRequestSuccess, this,
            [this](uint32_t operationId, QString auditCode, QString fileCode) {
                qInfo().noquote()
                    << QStringLiteral(
                           "[DsccBridge] corelib AuditRequestSuccess operationId=%1 auditCode=\"%2\" fileCode=\"%3\"")
                           .arg(operationId)
                           .arg(auditCode)
                           .arg(fileCode);
                emit auditRequestSuccess(operationId, auditCode, fileCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::AuditRequestFailed, this,
            [this](uint32_t operationId, QString auditCode, QString fileCode, dscc::Notification notification) {
                logNotification(
                    QStringLiteral("corelib AuditRequestFailed operationId=%1 auditCode=\"%2\" fileCode=\"%3\"")
                        .arg(operationId)
                        .arg(auditCode)
                        .arg(fileCode),
                    notification);
                emit auditRequestFailed(operationId, auditCode, fileCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::AuditInstanceRequestSuccess, this,
            [this](uint32_t operationId, QString instanceCode) {
                qInfo().noquote()
                    << QStringLiteral(
                           "[DsccBridge] corelib AuditInstanceRequestSuccess operationId=%1 instanceCode=\"%2\"")
                           .arg(operationId)
                           .arg(instanceCode);
                emit auditInstanceRequestSuccess(operationId, instanceCode);
            });

    connect(m_assets.get(), &dscc::UserAssets::AuditInstanceRequestFailed, this,
            [this](uint32_t operationId, QString instanceCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib AuditInstanceRequestFailed operationId=%1 instanceCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(instanceCode),
                                notification);
                emit auditInstanceRequestFailed(operationId, instanceCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::MessageRead, this, [this](uint32_t operationId, QString messageCode) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib MessageRead operationId=%1 messageCode=\"%2\"")
                                 .arg(operationId)
                                 .arg(messageCode);
        emit messageRead(operationId, messageCode);
        loadMessageList();
    });

    connect(m_assets.get(), &dscc::UserAssets::MessageReadFailed, this,
            [this](uint32_t operationId, QString messageCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib MessageReadFailed operationId=%1 messageCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(messageCode),
                                notification);
                emit messageReadFailed(operationId, messageCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::AllMessagesRead, this, [this](uint32_t operationId) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib AllMessagesRead operationId=%1").arg(operationId);
        emit allMessagesRead(operationId);
        loadMessageList();
    });

    connect(m_assets.get(), &dscc::UserAssets::AllMessagesReadFailed, this,
            [this](uint32_t operationId, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib AllMessagesReadFailed operationId=%1").arg(operationId),
                                notification);
                emit allMessagesReadFailed(operationId, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::MessageDeleted, this, [this](uint32_t operationId, QString messageCode) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib MessageDeleted operationId=%1 messageCode=\"%2\"")
                                 .arg(operationId)
                                 .arg(messageCode);
        emit messageDeleted(operationId, messageCode);
        loadMessageList();
    });

    connect(m_assets.get(), &dscc::UserAssets::MessageDeleteFailed, this,
            [this](uint32_t operationId, QString messageCode, dscc::Notification notification) {
                logNotification(QStringLiteral("corelib MessageDeleteFailed operationId=%1 messageCode=\"%2\"")
                                    .arg(operationId)
                                    .arg(messageCode),
                                notification);
                emit messageDeleteFailed(operationId, messageCode, notification);
            });

    connect(m_assets.get(), &dscc::UserAssets::CryptoOperationStart, this, [this](uint32_t operationId) {
        if (!m_encryptFileOperations.contains(operationId))
        {
            return;
        }

        const FileCryptoOperation op = m_encryptFileOperations.value(operationId);
        qInfo().noquote() << QStringLiteral(
                                 "[DsccBridge] corelib CryptoOperationStart operationId=%1 source=\"%2\" target=\"%3\"")
                                 .arg(operationId)
                                 .arg(op.sourceFile, op.targetFile);
        emit encryptFileStarted(operationId, op.sourceFile, op.targetFile);
    });

    connect(m_assets.get(), &dscc::UserAssets::CryptoOperationProgress, this,
            [this](uint32_t operationId, uint64_t processedBytes, uint64_t totalBytes) {
                if (!m_encryptFileOperations.contains(operationId))
                {
                    return;
                }

                const FileCryptoOperation op = m_encryptFileOperations.value(operationId);
                emit encryptFileProgress(operationId, op.sourceFile, op.targetFile, quint64(processedBytes),
                                         quint64(totalBytes));
            });

    connect(m_assets.get(), &dscc::UserAssets::CryptoOperationFinish, this, [this](uint32_t operationId) {
        if (!m_encryptFileOperations.contains(operationId))
        {
            return;
        }

        const FileCryptoOperation op = m_encryptFileOperations.take(operationId);
        if (QFileInfo(op.targetFile).isFile())
        {
            qInfo().noquote()
                << QStringLiteral(
                       "[DsccBridge] corelib CryptoOperationFinish success operationId=%1 source=\"%2\" target=\"%3\"")
                       .arg(operationId)
                       .arg(op.sourceFile, op.targetFile);
            emit encryptFileSucceeded(operationId, op.sourceFile, op.targetFile);
        }
        else
        {
            qWarning().noquote() << QStringLiteral("[DsccBridge] corelib CryptoOperationFinish without target file "
                                                   "operationId=%1 source=\"%2\" target=\"%3\"")
                                        .arg(operationId)
                                        .arg(op.sourceFile, op.targetFile);
            emit encryptFileFailed(operationId, op.sourceFile, op.targetFile, dscc::Notification());
        }
    });

    connect(m_assets.get(), &dscc::UserAssets::CryptoOperationCanceled, this, [this](uint32_t operationId) {
        if (!m_encryptFileOperations.contains(operationId))
        {
            return;
        }

        const FileCryptoOperation op = m_encryptFileOperations.take(operationId);
        qInfo().noquote()
            << QStringLiteral("[DsccBridge] corelib CryptoOperationCanceled operationId=%1 source=\"%2\" target=\"%3\"")
                   .arg(operationId)
                   .arg(op.sourceFile, op.targetFile);
        emit encryptFileCanceled(operationId, op.sourceFile, op.targetFile);
    });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()), &dscc::ActiveNotify::MessageReceived, this,
            [this](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib MessageReceived"), notification);
                loadMessageList();
            });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()), &dscc::ActiveNotify::WarningOccurred, this,
            [](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib WarningOccurred"), notification);
            });

    connect(static_cast<dscc::ActiveNotify *>(m_assets.get()), &dscc::ActiveNotify::ErrorOccurred, this,
            [this](dscc::Notification notification) {
                logNotification(QStringLiteral("corelib ErrorOccurred"), notification);
                if (m_initializingUserAssets && m_userAssetsInitializationError.IsEmpty())
                {
                    m_userAssetsInitializationError = notification;
                }
            });

    connect(m_assets.get(), &dscc::UserAssets::DataSyncFinished, this, [this](uint32_t operationId) {
        qInfo().noquote() << QStringLiteral("[DsccBridge] corelib DataSyncFinished operationId=%1").arg(operationId);
        // A sync round merged the latest server state into the local cache;
        // re-read the lists so multi-endpoint changes surface in the UI.
        loadDomainList();
        loadMessageList();
        emit dataSynced();
    });
}

QString DsccBridge::userDomainDbPath(const QString &userId) const
{
    const QByteArray digest = QCryptographicHash::hash(userId.toUtf8(), QCryptographicHash::Sha256).toHex();
    return QDir(QDir(m_dsccDataRoot).filePath(QStringLiteral("users")))
        .filePath(QString::fromLatin1(digest) + QStringLiteral("/domain.db"));
}

bool DsccBridge::isDomainInactiveForOperation(const QString &domainCode) const
{
    if (!m_assets)
    {
        return false;
    }

    const auto info = m_assets->DetailDomainInfo(domainCode);
    if (!info.has_value())
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] inactive domain check skipped because domain was not found domainCode=\"%1\"")
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
    // 安全域类型(1-用户安全域 2-典枢安全域)；两类都展示，仅供 UI 区分/标注。
    summary.insert(QStringLiteral("domainType"), info.domain_type);
    summary.insert(QStringLiteral("pubKey"), info.domain_pub_key);
    summary.insert(QStringLiteral("description"), info.remarks);
    summary.insert(QStringLiteral("payer"), info.pay_type == 2 ? QStringLiteral("使用者") : QStringLiteral("创建者"));
    QString statusText =
        info.domain_status == dscc::db::kDomainStatusClosed ? QStringLiteral("已关闭") : QStringLiteral("正常");
    if (domainCreateFailed)
    {
        statusText = QStringLiteral("创建失败");
    }
    summary.insert(QStringLiteral("status"), statusText);
    summary.insert(QStringLiteral("isInactive"), isDomainInactive(info));
    // 归档是与状态无关的视图划分：归档/恢复不改变安全域状态 (PRD 3.1)。
    summary.insert(QStringLiteral("isArchived"), info.is_archived != 0);
    const QString creatorUserId = info.creator_user_id.trimmed();
    QString creatorUserName = info.creator_user_name.trimmed();
    if (creatorUserName.isEmpty() && !creatorUserId.isEmpty() && creatorUserId == m_currentUserId.trimmed())
    {
        creatorUserName = m_currentUserName.trimmed();
    }
    if (creatorUserName.isEmpty())
    {
        const QHash<QString, QString> userNameLookup = buildUserNameLookup(info.visible_users, QString(), QString());
        creatorUserName = userNameLookup.value(creatorUserId).trimmed();
    }
    if (creatorUserName.isEmpty())
    {
        creatorUserName = creatorUserId;
    }
    summary.insert(QStringLiteral("creator"), creatorUserName);
    summary.insert(QStringLiteral("creatorUserId"), creatorUserId);
    summary.insert(QStringLiteral("creatorUserName"), creatorUserName);
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
    // 原始 epoch 毫秒，0 表示永久授权；不走 timestampToIsoString，否则永久与无数据无法区分
    map.insert(QStringLiteral("expireAt"), quint64(info.expire_at));
    return map;
}

QVariantMap DsccBridge::messageInfoToVariant(const dscc::MessageInfo &info) const
{
    QVariantMap map;
    map.insert(QStringLiteral("messageCode"), info.message_code);
    map.insert(QStringLiteral("message"), info.content);
    map.insert(QStringLiteral("content"), info.content);
    map.insert(QStringLiteral("recipient"), info.recipient);
    map.insert(QStringLiteral("type"), info.type);
    map.insert(QStringLiteral("isRead"), info.read_status);
    map.insert(QStringLiteral("readStatus"), info.read_status);

    const uint64_t ts = info.created_at > 0 ? info.created_at : info.time;
    const QString isoTime = timestampToIsoString(ts);
    map.insert(QStringLiteral("createTime"), isoTime);
    map.insert(QStringLiteral("createdAt"), isoTime);
    map.insert(QStringLiteral("rawTime"), quint64(ts));
    return map;
}

void DsccBridge::loadMessageList()
{
    if (!m_assets)
    {
        emit messageListLoaded(QVariantList());
        return;
    }

    QList<dscc::MessageInfo> messages = m_assets->ListMessages();
    std::sort(messages.begin(), messages.end(), [](const dscc::MessageInfo &a, const dscc::MessageInfo &b) {
        const uint64_t tsA = a.created_at > 0 ? a.created_at : a.time;
        const uint64_t tsB = b.created_at > 0 ? b.created_at : b.time;
        return tsA > tsB;
    });

    QVariantList list;
    list.reserve(messages.size());
    for (const dscc::MessageInfo &msg : messages)
    {
        list.append(messageInfoToVariant(msg));
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] loadMessageList count=%1").arg(list.size());
    emit messageListLoaded(list);
}

void DsccBridge::readMessage(const QString &messageCode)
{
    const QString trimmedCode = messageCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] readMessage rejected because UserAssets is not initialized messageCode=\"%1\"")
                   .arg(trimmedCode);
        emit messageReadFailed(0, trimmedCode, dscc::Notification());
        return;
    }

    if (trimmedCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] readMessage rejected because messageCode is empty");
        emit messageReadFailed(0, QString(), dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] readMessage request messageCode=\"%1\"").arg(trimmedCode);

    const dscc::Handle handle = m_assets->ReadMessage(trimmedCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] readMessage submitted operationId=%1 messageCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedCode);
    Q_UNUSED(handle);
}

void DsccBridge::readAllMessages()
{
    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral(
            "[DsccBridge] readAllMessages rejected because UserAssets is not initialized");
        emit allMessagesReadFailed(0, dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] readAllMessages request");

    const dscc::Handle handle = m_assets->ReadAllMessages();
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] readAllMessages submitted operationId=%1").arg(handle.GetOperationId());
    Q_UNUSED(handle);
}

void DsccBridge::deleteMessage(const QString &messageCode)
{
    const QString trimmedCode = messageCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] deleteMessage rejected because UserAssets is not initialized messageCode=\"%1\"")
                   .arg(trimmedCode);
        emit messageDeleteFailed(0, trimmedCode, dscc::Notification());
        return;
    }

    if (trimmedCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] deleteMessage rejected because messageCode is empty");
        emit messageDeleteFailed(0, QString(), dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] deleteMessage request messageCode=\"%1\"").arg(trimmedCode);

    const dscc::Handle handle = m_assets->DeleteMessage(trimmedCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] deleteMessage submitted operationId=%1 messageCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedCode);
    Q_UNUSED(handle);
}

QString DsccBridge::encryptedTargetFilePath(const QString &sourceFile, const QString &outputDir) const
{
    const QFileInfo sourceInfo(sourceFile.trimmed());
    const QString sourceName = sourceInfo.fileName().trimmed();
    if (sourceName.isEmpty())
    {
        return QString();
    }

    const QString trimmedOutputDir = outputDir.trimmed();
    const QString targetDirPath = trimmedOutputDir.isEmpty() ? sourceInfo.absolutePath() : trimmedOutputDir;
    if (targetDirPath.trimmed().isEmpty())
    {
        return QString();
    }

    QDir targetDir(targetDirPath);
    const QString targetName = sourceName + QStringLiteral(".sealed");
    QString candidate = QDir::cleanPath(targetDir.filePath(targetName));
    if (!QFileInfo::exists(candidate))
    {
        return candidate;
    }

    for (int i = 1; i < 10000; ++i)
    {
        const QString candidateName =
            sourceName + QStringLiteral(" (") + QString::number(i) + QStringLiteral(").sealed");
        candidate = QDir::cleanPath(targetDir.filePath(candidateName));
        if (!QFileInfo::exists(candidate))
        {
            return candidate;
        }
    }

    return QString();
}

void DsccBridge::encryptFile(const QString &sourceFile, const QString &targetFile, const QString &publicKey)
{
    const QString trimmedSourceFile = sourceFile.trimmed();
    const QString trimmedTargetFile = targetFile.trimmed();
    const QString trimmedPublicKey = publicKey.trimmed();

    auto emitFailure = [this, trimmedSourceFile, trimmedTargetFile](const dscc::Notification &notification) {
        emit encryptFileFailed(0, trimmedSourceFile, trimmedTargetFile, notification);
    };

    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] encryptFile rejected because UserAssets is not "
                                               "initialized source=\"%1\" target=\"%2\"")
                                    .arg(trimmedSourceFile, trimmedTargetFile);
        emitFailure(dscc::Notification());
        return;
    }

    if (trimmedSourceFile.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] encryptFile rejected because source file is empty");
        emitFailure(dscc::Notification(dscc::Notification::kCryptoEncryptSourceFileEmpty, dscc::Notification::kError));
        return;
    }

    QFileInfo sourceInfo(trimmedSourceFile);
    if (!sourceInfo.isFile())
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] encryptFile rejected because source file was not found source=\"%1\"")
                                    .arg(trimmedSourceFile);
        emitFailure(dscc::Notification(dscc::Notification::kCryptoEncryptSourceFileNotFound, dscc::Notification::kError,
                                       {{QStringLiteral("path"), trimmedSourceFile}}));
        return;
    }

    if (trimmedTargetFile.isEmpty())
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] encryptFile rejected because target file is empty source=\"%1\"")
                                    .arg(trimmedSourceFile);
        emitFailure(
            dscc::Notification(dscc::Notification::kCryptoEncryptDestinationFileEmpty, dscc::Notification::kError));
        return;
    }

    QFileInfo targetInfo(trimmedTargetFile);
    if (targetInfo.fileName().trimmed().isEmpty() || targetInfo.isDir())
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] encryptFile rejected because target path is not a file source=\"%1\" target=\"%2\"")
                   .arg(trimmedSourceFile, trimmedTargetFile);
        emitFailure(dscc::Notification());
        return;
    }

    const QString sourceAbs = QDir::cleanPath(sourceInfo.absoluteFilePath());
    const QString targetAbs = QDir::cleanPath(targetInfo.absoluteFilePath());
#ifdef Q_OS_WIN
    const bool samePath = sourceAbs.compare(targetAbs, Qt::CaseInsensitive) == 0;
#else
    const bool samePath = sourceAbs == targetAbs;
#endif
    if (samePath)
    {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] encryptFile rejected because source and target are the same source=\"%1\"")
                   .arg(trimmedSourceFile);
        emitFailure(dscc::Notification());
        return;
    }

    if (trimmedPublicKey.isEmpty())
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] encryptFile rejected because public key is empty source=\"%1\" target=\"%2\"")
                   .arg(trimmedSourceFile, trimmedTargetFile);
        emitFailure(dscc::Notification(dscc::Notification::kCryptoEncryptPublicKeyEmpty, dscc::Notification::kError));
        return;
    }

    QDir targetParent = targetInfo.absoluteDir();
    if (!targetParent.exists() && !targetParent.mkpath(QStringLiteral(".")))
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] encryptFile rejected because target parent cannot be "
                                               "created source=\"%1\" target=\"%2\"")
                                    .arg(trimmedSourceFile, trimmedTargetFile);
        emitFailure(dscc::Notification());
        return;
    }

    const dscc::Handle handle = m_assets->EncryptFile(trimmedSourceFile, trimmedTargetFile, trimmedPublicKey);
    const uint32_t operationId = handle.GetOperationId();
    m_encryptFileOperations.insert(operationId, FileCryptoOperation{trimmedSourceFile, trimmedTargetFile});
    qInfo().noquote() << QStringLiteral("[DsccBridge] encryptFile submitted operationId=%1 source=\"%2\" target=\"%3\"")
                             .arg(operationId)
                             .arg(trimmedSourceFile, trimmedTargetFile);
    Q_UNUSED(handle);
}

QString DsccBridge::domainCreateFailureMessage(uint32_t operationId, const QString &fallback) const
{
    const QString message = m_domainCreateFailureMessages.value(operationId).trimmed();
    if (!message.isEmpty())
    {
        return message;
    }

    const QString trimmedFallback = fallback.trimmed();
    return trimmedFallback.isEmpty() ? tr("Security domain creation failed") : trimmedFallback;
}

QString DsccBridge::notificationMessage(const QVariant &notification, const QString &fallback) const
{
    if (notification.canConvert<dscc::Notification>())
    {
        return notificationDisplayText(notification.value<dscc::Notification>(), fallback);
    }

    const QString directMessage = notification.toString().trimmed();
    if (!directMessage.isEmpty())
    {
        return directMessage;
    }

    return fallback.trimmed();
}

void DsccBridge::loadDomainList()
{
    if (!m_assets)
    {
        emit domainListLoaded(QVariantList());
        return;
    }

    QList<dscc::DomainInfo> domains = m_assets->ListDomains();
    std::sort(domains.begin(), domains.end(),
              [](const dscc::DomainInfo &a, const dscc::DomainInfo &b) { return a.created_at > b.created_at; });

    QVariantList list;
    list.reserve(domains.size());
    for (const dscc::DomainInfo &domain : domains)
    {
        list.append(domainInfoToSummary(domain));
    }
    emit domainListLoaded(list);
}

void DsccBridge::refresh()
{
    triggerSyncData();
}

void DsccBridge::triggerSyncData()
{
    if (!m_assets)
    {
        return;
    }
    // SyncData() returns a Handle whose work starts on Submit(); the round
    // completes asynchronously and fires DataSyncFinished.
    m_assets->SyncData().Submit();
}

void DsccBridge::startSyncTimer()
{
    if (m_syncTimer && !m_syncTimer->isActive())
    {
        m_syncTimer->start();
    }
}

void DsccBridge::stopSyncTimer()
{
    if (m_syncTimer)
    {
        m_syncTimer->stop();
    }
}

QString DsccBridge::resolveUserNameWithCache(const QHash<QString, QString> &domainLookup, const QString &userId)
{
    const QString trimmedUserId = userId.trimmed();
    if (trimmedUserId.isEmpty())
    {
        return QString();
    }

    const QString fromDomain = domainLookup.value(trimmedUserId).trimmed();
    if (!fromDomain.isEmpty())
    {
        return fromDomain;
    }

    const auto cached = m_userNameCache.constFind(trimmedUserId);
    if (cached != m_userNameCache.constEnd())
    {
        return cached->isEmpty() ? trimmedUserId : *cached;
    }

    QString resolved;
    if (m_assets)
    {
        const auto info = m_assets->DetailVisibleUserInfo(trimmedUserId);
        if (info.has_value())
        {
            resolved = info->auth_user_name.trimmed();
            if (resolved.isEmpty())
            {
                resolved = info->display_name.trimmed();
            }
            if (resolved.isEmpty())
            {
                resolved = info->account.trimmed();
            }
        }
    }

    m_userNameCache.insert(trimmedUserId, resolved);
    return resolved.isEmpty() ? trimmedUserId : resolved;
}

void DsccBridge::loadInstances(const QString &domainCode)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets)
    {
        emit instancesLoaded(trimmedDomainCode, QVariantList());
        return;
    }

    QList<dscc::InstanceInfo> instances = m_assets->ListInstances(trimmedDomainCode);
    std::sort(instances.begin(), instances.end(),
              [](const dscc::InstanceInfo &a, const dscc::InstanceInfo &b) { return a.created_at > b.created_at; });

    const QList<dscc::VisibleUserInfo> visibleUsers = m_domainVisibleUsersCache.value(trimmedDomainCode);
    const QHash<QString, QString> userNameLookup =
        buildUserNameLookup(visibleUsers, m_currentUserId, m_currentUserName);

    QVariantList list;
    list.reserve(instances.size());
    for (const dscc::InstanceInfo &inst : instances)
    {
        QVariantMap map = instanceInfoToVariant(inst);
        const QString creatorUserName = resolveUserNameWithCache(userNameLookup, inst.creator_user_id);
        map.insert(QStringLiteral("creatorUserName"), creatorUserName);
        list.append(map);
    }
    qInfo().noquote() << QStringLiteral("[DsccBridge] loadInstances domainCode=\"%1\" count=%2")
                             .arg(trimmedDomainCode)
                             .arg(list.size());
    emit instancesLoaded(trimmedDomainCode, list);
}

void DsccBridge::loadAudits(const QString &domainCode, int applyType)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets)
    {
        emit auditsLoaded(trimmedDomainCode, applyType, QVariantList());
        return;
    }

    if (applyType != 1 && applyType != 2)
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] loadAudits unsupported applyType=%1 domainCode=\"%2\"")
                                    .arg(applyType)
                                    .arg(trimmedDomainCode);
        emit auditsLoaded(trimmedDomainCode, applyType, QVariantList());
        return;
    }

    QHash<QString, QString> instanceNameMap;
    const QList<dscc::VisibleUserInfo> visibleUsers = m_domainVisibleUsersCache.value(trimmedDomainCode);
    const QHash<QString, QString> userNameLookup =
        buildUserNameLookup(visibleUsers, m_currentUserId, m_currentUserName);

    const QList<dscc::InstanceInfo> instances = m_assets->ListInstances(trimmedDomainCode);
    for (const dscc::InstanceInfo &inst : instances)
    {
        if (!inst.instance_code.isEmpty() && !inst.instance_name.isEmpty())
        {
            instanceNameMap.insert(inst.instance_code, inst.instance_name);
        }
    }

    QList<dscc::AuditInfo> audits = m_assets->ListAudits(trimmedDomainCode, static_cast<uint32_t>(applyType));
    std::sort(audits.begin(), audits.end(),
              [](const dscc::AuditInfo &a, const dscc::AuditInfo &b) { return a.created_at > b.created_at; });

    QVariantList list;
    list.reserve(audits.size());
    for (const dscc::AuditInfo &audit : audits)
    {
        QVariantMap map;
        map.insert(QStringLiteral("applyCode"), audit.apply_code);
        map.insert(QStringLiteral("id"), audit.apply_code);
        map.insert(QStringLiteral("applyType"), applyType);
        const QString applicantUserName = resolveUserNameWithCache(userNameLookup, audit.applicant_user_id);
        map.insert(QStringLiteral("applicant"), applicantUserName);
        map.insert(QStringLiteral("applicantUserId"), audit.applicant_user_id);
        map.insert(QStringLiteral("applicantUserName"), applicantUserName);
        map.insert(QStringLiteral("instanceCode"), audit.instance_code);
        map.insert(QStringLiteral("fileCode"), audit.file_code);
        map.insert(QStringLiteral("fileHash"), audit.file_hash);

        const QString instanceName = instanceNameMap.value(audit.instance_code, audit.instance_code);
        map.insert(QStringLiteral("instanceName"), instanceName);
        map.insert(QStringLiteral("instanceId"), audit.instance_code);

        // 申请单状态：0 待审核 / 1 已授权 / 2 已拒绝 / 3 已过期（后端 ApplyEnum）。
        // 白名单申请带授权期限，到期后由后端定时任务把 is_approved 置为 3；这里漏掉
        // 那一支，界面上的「状态」列就会直接显示裸的 "3"。
        QString statusText;
        switch (audit.status)
        {
        case 0:
            statusText = QStringLiteral("待审核");
            break;
        case 1:
            statusText = QStringLiteral("已授权");
            break;
        case 2:
            statusText = QStringLiteral("已拒绝");
            break;
        case 3:
            statusText = QStringLiteral("已过期");
            break;
        default:
            // 后端将来再扩状态码时，宁可显示一句看得懂的兜底，也不要甩一个数字。
            statusText = QStringLiteral("未知状态(%1)").arg(audit.status);
            break;
        }
        map.insert(QStringLiteral("status"), statusText);
        map.insert(QStringLiteral("statusCode"), audit.status);

        const QString createdAtStr = timestampToIsoString(audit.created_at);
        map.insert(QStringLiteral("createdAt"), createdAtStr);
        map.insert(QStringLiteral("applyTime"), createdAtStr);
        // 原始 epoch 毫秒，0 表示永久授权
        map.insert(QStringLiteral("expireAt"), quint64(audit.expire_at));

        if (applyType == 1)
        {
            map.insert(QStringLiteral("appName"), audit.file_name);
            map.insert(QStringLiteral("fileName"), audit.file_name);
            if (!audit.file_name.isEmpty() || !audit.file_code.isEmpty() || !audit.file_hash.isEmpty())
            {
                QVariantMap process;
                process.insert(QStringLiteral("fileName"), audit.file_name);
                process.insert(QStringLiteral("masterFileName"), audit.file_name);
                process.insert(QStringLiteral("fileCode"), audit.file_code);
                process.insert(QStringLiteral("fileHash"), audit.file_hash);
                map.insert(QStringLiteral("processes"), QVariantList{process});
            }
        }
        else
        {
            map.insert(QStringLiteral("fileName"), audit.file_name);
            map.insert(QStringLiteral("fileSize"), quint64(audit.file_size));
            map.insert(QStringLiteral("files"),
                       audit.file_name.isEmpty() ? QVariantList() : QVariantList{audit.file_name});
        }

        list.append(map);
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] loadAudits domainCode=\"%1\" applyType=%2 count=%3")
                             .arg(trimmedDomainCode)
                             .arg(applyType)
                             .arg(list.size());
    emit auditsLoaded(trimmedDomainCode, applyType, list);
}

void DsccBridge::loadDomainSummary(const QString &domainCode)
{
    QVariantMap summary;
    const QString trimmedDomainCode = domainCode.trimmed();
    qInfo().noquote() << QStringLiteral("[DsccBridge] loadDomainSummary request domainCode=\"%1\" trimmed=\"%2\" "
                                        "hasAssets=%3 currentUserHash=%4")
                             .arg(domainCode)
                             .arg(trimmedDomainCode)
                             .arg(m_assets != nullptr)
                             .arg(logHash(m_currentUserId));

    if (m_assets && !trimmedDomainCode.isEmpty())
    {
        const auto info = m_assets->DetailDomainInfo(trimmedDomainCode);
        if (info.has_value())
        {
            logDomainInfoSummarySource(trimmedDomainCode, *info);
            m_domainVisibleUsersCache.insert(trimmedDomainCode, info->visible_users);
            summary = domainInfoToSummary(*info);
            summary.insert(QStringLiteral("visibleUsers"), visibleUsersToVariantList(info->visible_users));
        }
        else
        {
            m_domainVisibleUsersCache.remove(trimmedDomainCode);
            qWarning().noquote()
                << QStringLiteral(
                       "[DsccBridge] loadDomainSummary DetailDomainInfo returned empty for domainCode=\"%1\"")
                       .arg(trimmedDomainCode);
        }
    }
    else if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral(
            "[DsccBridge] loadDomainSummary skipped because UserAssets is not initialized");
    }
    else
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] loadDomainSummary skipped because domainCode is empty");
    }

    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] loadDomainSummary emit domainCode=\"%1\" summarySize=%2 summary=%3")
                             .arg(domainCode)
                             .arg(summary.size())
                             .arg(variantMapText(summary));
    emit domainSummaryLoaded(domainCode, summary);
}

void DsccBridge::createDomain(const QVariantMap &info)
{
    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral(
            "[DsccBridge] createDomain rejected because UserAssets is not initialized");
        m_domainCreateFailureMessages.insert(0, tr("Security domain creation failed"));
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
    domainInfo.remarks = remarks;

    const QString payer = info.value("payer").toString().trimmed();
    domainInfo.pay_type = (payer == QStringLiteral("使用者")) ? 2 : 1;

    const QVariantList visibleUsers = info.value("visibleUsers").toList();
    int visibleUserIndex = 0;
    for (const QVariant &v : visibleUsers)
    {
        const QVariantMap u = v.toMap();
        dscc::VisibleUserInfo user;
        user.account = u.value("account").toString().trimmed();
        user.auth_user_id = u.value("authUserId").toString().trimmed();
        user.auth_user_name = u.value("authUserName").toString().trimmed();
        user.display_name = u.value("displayName").toString().trimmed();
        if (user.display_name.isEmpty())
        {
            user.display_name = user.auth_user_name.isEmpty() ? user.account : user.auth_user_name;
        }
        if (user.auth_user_name.isEmpty())
        {
            user.auth_user_name = user.display_name.isEmpty() ? user.account : user.display_name;
        }
        if (!user.account.isEmpty() && !user.auth_user_id.isEmpty())
        {
            domainInfo.visible_users.append(user);
            qInfo().noquote() << QStringLiteral("[DsccBridge] createDomain visibleUser[%1] accepted account=\"%2\" "
                                                "authUserIdHash=%3 authUserName=\"%4\" displayName=\"%5\"")
                                     .arg(visibleUserIndex)
                                     .arg(user.account, logHash(user.auth_user_id), user.auth_user_name,
                                          user.display_name);
        }
        else
        {
            qWarning().noquote() << QStringLiteral("[DsccBridge] createDomain visibleUser[%1] skipped account=\"%2\" "
                                                   "authUserIdHash=%3 authUserName=\"%4\" displayName=\"%5\"")
                                        .arg(visibleUserIndex)
                                        .arg(user.account, logHash(user.auth_user_id), user.auth_user_name,
                                             user.display_name);
        }
        ++visibleUserIndex;
    }

    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] createDomain request domainName=\"%1\" nameLength=%2 remarksLength=%3 "
                             "remarksAutoFilled=%4 payerRaw=\"%5\" payType=%6 visibleUsersInput=%7 "
                             "visibleUsersAccepted=%8 currentUserHash=%9 creatorUserIdHash=%10 creatorUserName=\"%11\" "
                             "creatorDisplayName=\"%12\" bridgePubKeyEmpty=%13 bridgePriKeyEmpty=%14")
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
        << QStringLiteral("[DsccBridge] createDomain submitted operationId=%1").arg(handle.GetOperationId());
    Q_UNUSED(handle);
}

void DsccBridge::updateDomainDesc(const QString &domainCode, const QString &desc)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedDesc = desc.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] updateDomainDesc rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainDescUpdateFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] updateDomainDesc rejected because domainCode is empty");
        emit domainDescUpdateFailed(
            0, QString(),
            dscc::Notification(dscc::Notification::kUpdateDomainDescEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode))
    {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] updateDomainDesc rejected because domain is inactive domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainDescUpdateFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] updateDomainDesc request domainCode=\"%1\" descLength=%2 currentUserHash=%3")
                             .arg(trimmedDomainCode)
                             .arg(trimmedDesc.size())
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->UpdateDomainDesc(trimmedDomainCode, trimmedDesc);
    qInfo().noquote() << QStringLiteral("[DsccBridge] updateDomainDesc submitted operationId=%1 domainCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::addUserToDomain(const QString &domainCode, const QString &userId)
{
    qInfo().noquote() << QStringLiteral("[DsccBridge] addUserToDomain called domainCode=\"%1\" userId=\"%2\"")
                             .arg(domainCode, userId);

    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedUserId = userId.trimmed();
    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] addUserToDomain rejected because UserAssets is not "
                                               "initialized domainCode=\"%1\" userIdHash=%2")
                                    .arg(trimmedDomainCode)
                                    .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] addUserToDomain rejected because domainCode is empty userIdHash=%1")
                                    .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(
            0, QString(), trimmedUserId,
            dscc::Notification(dscc::Notification::kAddUserToDomainEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    if (trimmedUserId.isEmpty())
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] addUserToDomain rejected because userId is empty domainCode=\"%1\"")
                                    .arg(trimmedDomainCode);
        emit addUserToDomainFailed(
            0, trimmedDomainCode, QString(),
            dscc::Notification(dscc::Notification::kAddUserToDomainEmptyUserId, dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode))
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] addUserToDomain rejected because domain is inactive domainCode=\"%1\" userIdHash=%2")
                   .arg(trimmedDomainCode)
                   .arg(logHash(trimmedUserId));
        emit addUserToDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] addUserToDomain request domainCode=\"%1\" userIdHash=%2 currentUserHash=%3")
                             .arg(trimmedDomainCode)
                             .arg(logHash(trimmedUserId))
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->AddUserToDomain(trimmedDomainCode, trimmedUserId);
    qInfo().noquote() << QStringLiteral(
                             "[DsccBridge] addUserToDomain submitted operationId=%1 domainCode=\"%2\" userIdHash=%3")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode)
                             .arg(logHash(trimmedUserId));
    Q_UNUSED(handle);
}

void DsccBridge::removeUserFromDomain(const QString &domainCode, const QString &userId)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    const QString trimmedUserId = userId.trimmed();
    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because UserAssets is not "
                                               "initialized domainCode=\"%1\" userIdHash=%2")
                                    .arg(trimmedDomainCode)
                                    .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because domainCode is empty userIdHash=%1")
                   .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(
            0, QString(), trimmedUserId,
            dscc::Notification(dscc::Notification::kRemoveUserFromDomainEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    if (trimmedUserId.isEmpty())
    {
        qWarning().noquote()
            << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because userId is empty domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit removeUserFromDomainFailed(
            0, trimmedDomainCode, QString(),
            dscc::Notification(dscc::Notification::kRemoveUserFromDomainEmptyUserId, dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode))
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] removeUserFromDomain rejected because domain is inactive "
                                               "domainCode=\"%1\" userIdHash=%2")
                                    .arg(trimmedDomainCode)
                                    .arg(logHash(trimmedUserId));
        emit removeUserFromDomainFailed(0, trimmedDomainCode, trimmedUserId, dscc::Notification());
        return;
    }

    qInfo().noquote()
        << QStringLiteral(
               "[DsccBridge] removeUserFromDomain request domainCode=\"%1\" userIdHash=%2 currentUserHash=%3")
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
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] closeDomain rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainCloseFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] closeDomain rejected because domainCode is empty");
        emit domainCloseFailed(
            0, QString(),
            dscc::Notification(dscc::Notification::kCloseDomainEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    if (isDomainInactiveForOperation(trimmedDomainCode))
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] closeDomain rejected because domain is inactive domainCode=\"%1\"")
                                    .arg(trimmedDomainCode);
        emit domainCloseFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] closeDomain request domainCode=\"%1\" currentUserHash=%2")
                             .arg(trimmedDomainCode)
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->CloseDomain(trimmedDomainCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] closeDomain submitted operationId=%1 domainCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::deleteDomain(const QString &domainCode)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] deleteDomain rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainDeleteFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] deleteDomain rejected because domainCode is empty");
        emit domainDeleteFailed(0, QString(), dscc::Notification());
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] deleteDomain request domainCode=\"%1\" currentUserHash=%2")
                             .arg(trimmedDomainCode)
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->DeleteDomain(trimmedDomainCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] deleteDomain submitted operationId=%1 domainCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::archiveDomain(const QString &domainCode)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] archiveDomain rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainArchiveFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] archiveDomain rejected because domainCode is empty");
        emit domainArchiveFailed(
            0, QString(),
            dscc::Notification(dscc::Notification::kArchiveDomainEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    // 归档对任意状态的安全域均可执行，不做 inactive 校验 (PRD 3.1)。
    qInfo().noquote() << QStringLiteral("[DsccBridge] archiveDomain request domainCode=\"%1\" currentUserHash=%2")
                             .arg(trimmedDomainCode)
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->ArchiveDomain(trimmedDomainCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] archiveDomain submitted operationId=%1 domainCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::unarchiveDomain(const QString &domainCode)
{
    const QString trimmedDomainCode = domainCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] unarchiveDomain rejected because UserAssets is not initialized domainCode=\"%1\"")
                   .arg(trimmedDomainCode);
        emit domainUnarchiveFailed(0, trimmedDomainCode, dscc::Notification());
        return;
    }

    if (trimmedDomainCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] unarchiveDomain rejected because domainCode is empty");
        emit domainUnarchiveFailed(
            0, QString(),
            dscc::Notification(dscc::Notification::kUnarchiveDomainEmptyDomainCode, dscc::Notification::kError));
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] unarchiveDomain request domainCode=\"%1\" currentUserHash=%2")
                             .arg(trimmedDomainCode)
                             .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->UnarchiveDomain(trimmedDomainCode);
    qInfo().noquote() << QStringLiteral("[DsccBridge] unarchiveDomain submitted operationId=%1 domainCode=\"%2\"")
                             .arg(handle.GetOperationId())
                             .arg(trimmedDomainCode);
    Q_UNUSED(handle);
}

void DsccBridge::auditInstanceRequest(const QString &instanceCode, bool approved)
{
    const QString trimmedInstanceCode = instanceCode.trimmed();
    if (!m_assets)
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] auditInstanceRequest rejected because UserAssets is not "
                                               "initialized instanceCode=\"%1\"")
                                    .arg(trimmedInstanceCode);
        emit auditInstanceRequestFailed(0, trimmedInstanceCode, dscc::Notification());
        return;
    }

    if (trimmedInstanceCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral(
            "[DsccBridge] auditInstanceRequest rejected because instanceCode is empty");
        emit auditInstanceRequestFailed(
            0, QString(),
            dscc::Notification(dscc::Notification::kAuditInstanceRequestEmptyInstanceCode, dscc::Notification::kError));
        return;
    }

    qInfo().noquote()
        << QStringLiteral(
               "[DsccBridge] auditInstanceRequest request instanceCode=\"%1\" approved=%2 currentUserHash=%3")
               .arg(trimmedInstanceCode)
               .arg(approved)
               .arg(logHash(m_currentUserId));

    const dscc::Handle handle = m_assets->AuditInstanceRequest(trimmedInstanceCode, approved);
    qInfo().noquote()
        << QStringLiteral("[DsccBridge] auditInstanceRequest submitted operationId=%1 instanceCode=\"%2\" approved=%3")
               .arg(handle.GetOperationId())
               .arg(trimmedInstanceCode)
               .arg(approved);
    Q_UNUSED(handle);
}

void DsccBridge::auditRequest(const QString &auditCode, const QString &fileCode, bool approved, const QString &reason)
{
    const QString trimmedAuditCode = auditCode.trimmed();
    const QString trimmedFileCode = fileCode.trimmed();
    const QString trimmedReason = reason.trimmed();

    if (!m_assets)
    {
        qWarning().noquote()
            << QStringLiteral(
                   "[DsccBridge] auditRequest rejected because UserAssets is not initialized auditCode=\"%1\"")
                   .arg(trimmedAuditCode);
        emit auditRequestFailed(0, trimmedAuditCode, trimmedFileCode, dscc::Notification());
        return;
    }

    if (trimmedAuditCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] auditRequest rejected because auditCode is empty");
        emit auditRequestFailed(
            0, QString(), trimmedFileCode,
            dscc::Notification(dscc::Notification::kAuditRequestEmptyAuditCode, dscc::Notification::kError));
        return;
    }

    if (trimmedFileCode.isEmpty())
    {
        qWarning().noquote() << QStringLiteral(
                                    "[DsccBridge] auditRequest rejected because fileCode is empty auditCode=\"%1\"")
                                    .arg(trimmedAuditCode);
        emit auditRequestFailed(
            0, trimmedAuditCode, QString(),
            dscc::Notification(dscc::Notification::kAuditRequestEmptyFileCode, dscc::Notification::kError));
        return;
    }

    if (approved && trimmedReason.isEmpty())
    {
        qWarning().noquote() << QStringLiteral("[DsccBridge] auditRequest rejected because approval reason is empty "
                                               "auditCode=\"%1\" fileCode=\"%2\"")
                                    .arg(trimmedAuditCode)
                                    .arg(trimmedFileCode);
        emit auditRequestFailed(
            0, trimmedAuditCode, trimmedFileCode,
            dscc::Notification(dscc::Notification::kAuditRequestMissingApprovalCredential, dscc::Notification::kError));
        return;
    }

    qInfo().noquote() << QStringLiteral("[DsccBridge] auditRequest request auditCode=\"%1\" fileCode=\"%2\" "
                                        "approved=%3 reasonLength=%4 currentUserHash=%5")
                             .arg(trimmedAuditCode)
                             .arg(trimmedFileCode)
                             .arg(approved)
                             .arg(trimmedReason.size())
                             .arg(logHash(m_currentUserId));

    const dscc::Handle h = m_assets->AuditRequest(trimmedAuditCode, trimmedFileCode, approved, trimmedReason);
    qInfo().noquote()
        << QStringLiteral(
               "[DsccBridge] auditRequest submitted operationId=%1 auditCode=\"%2\" fileCode=\"%3\" approved=%4")
               .arg(h.GetOperationId())
               .arg(trimmedAuditCode)
               .arg(trimmedFileCode)
               .arg(approved);
    Q_UNUSED(h);
}
