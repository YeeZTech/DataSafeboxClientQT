#ifndef DSCCBRIDGE_H
#define DSCCBRIDGE_H

#include <QHash>
#include <QObject>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

#include "dscc/core/interface/user_assets.h"

class DsccBridge : public QObject
{
    Q_OBJECT

  public:
    explicit DsccBridge(const QString &metaDbPath, const QString &dsccDataRoot, const QString &serverUrl,
                        const QString &credential, QObject *parent = nullptr);
    ~DsccBridge() override;

    void initialize();
    void shutdown();

    Q_INVOKABLE void setCurrentUser(const QString &userId, const QString &userName, const QString &accessToken,
                                    const QString &refreshToken);
    Q_INVOKABLE void clearCurrentUser();

    Q_INVOKABLE void loadDomainList();
    Q_INVOKABLE void loadInstances(const QString &domainCode);
    Q_INVOKABLE void loadDomainSummary(const QString &domainCode);
    Q_INVOKABLE void loadAudits(const QString &domainCode, int applyType);
    Q_INVOKABLE void createDomain(const QVariantMap &info);
    Q_INVOKABLE void closeDomain(const QString &domainCode);
    Q_INVOKABLE void updateDomainDesc(const QString &domainCode, const QString &desc);
    Q_INVOKABLE void addUserToDomain(const QString &domainCode, const QString &userId);
    Q_INVOKABLE void removeUserFromDomain(const QString &domainCode, const QString &userId);
    Q_INVOKABLE QString domainCreateFailureMessage(uint32_t operation_id, const QString &fallback) const;
    Q_INVOKABLE void auditInstanceRequest(const QString &instanceCode, bool approved);
    Q_INVOKABLE void auditRequest(const QString &auditCode, const QString &fileCode, bool approved,
                                  const QString &reason);
    Q_INVOKABLE QString notificationMessage(const QVariant &notification, const QString &fallback) const;
    Q_INVOKABLE void loadMessageList();
    Q_INVOKABLE void readMessage(const QString &messageCode);
    Q_INVOKABLE void readAllMessages();
    Q_INVOKABLE void deleteMessage(const QString &messageCode);
    Q_INVOKABLE void encryptFile(const QString &sourceFile, const QString &targetFile, const QString &publicKey);
    Q_INVOKABLE QString encryptedTargetFilePath(const QString &sourceFile, const QString &outputDir) const;

  signals:
    void messageListLoaded(QVariantList messages);
    void messageRead(uint32_t operation_id, QString message_code);
    void messageReadFailed(uint32_t operation_id, QString message_code, dscc::Notification notification);
    void allMessagesRead(uint32_t operation_id);
    void allMessagesReadFailed(uint32_t operation_id, dscc::Notification notification);
    void messageDeleted(uint32_t operation_id, QString message_code);
    void messageDeleteFailed(uint32_t operation_id, QString message_code, dscc::Notification notification);
    void encryptFileStarted(uint32_t operation_id, QString source_file, QString target_file);
    void encryptFileProgress(uint32_t operation_id, QString source_file, QString target_file, quint64 processed_bytes,
                             quint64 total_bytes);
    void encryptFileSucceeded(uint32_t operation_id, QString source_file, QString target_file);
    void encryptFileFailed(uint32_t operation_id, QString source_file, QString target_file,
                           dscc::Notification notification);
    void encryptFileCanceled(uint32_t operation_id, QString source_file, QString target_file);
    void domainListLoaded(QVariantList domains);
    void domainSummaryLoaded(QString domainCode, QVariantMap summary);
    void instancesLoaded(QString domainCode, QVariantList instances);
    void auditsLoaded(QString domainCode, int applyType, QVariantList audits);
    void domainCreated(uint32_t operation_id, QString domain_code);
    void domainCreateFailed(uint32_t operation_id, dscc::Notification notification);
    void domainClosed(uint32_t operation_id, QString domain_code);
    void domainCloseFailed(uint32_t operation_id, QString domain_code, dscc::Notification notification);
    void domainDescUpdated(uint32_t operation_id, QString domain_code);
    void domainDescUpdateFailed(uint32_t operation_id, QString domain_code, dscc::Notification notification);
    void addUserToDomainSuccess(uint32_t operation_id, QString domain_code, QString user_id);
    void addUserToDomainFailed(uint32_t operation_id, QString domain_code, QString user_id,
                               dscc::Notification notification);
    void removeUserFromDomainSuccess(uint32_t operation_id, QString domain_code, QString user_id);
    void removeUserFromDomainFailed(uint32_t operation_id, QString domain_code, QString user_id,
                                    dscc::Notification notification);
    void auditRequestSuccess(uint32_t operation_id, QString audit_code, QString file_code);
    void auditRequestFailed(uint32_t operation_id, QString audit_code, QString file_code,
                            dscc::Notification notification);
    void auditInstanceRequestSuccess(uint32_t operation_id, QString instance_code);
    void auditInstanceRequestFailed(uint32_t operation_id, QString instance_code, dscc::Notification notification);
    void coreErrorOccurred(dscc::Notification notification);

  private:
    void connectAssetSignals();
    QString userDomainDbPath(const QString &userId) const;
    bool isDomainInactiveForOperation(const QString &domainCode) const;
    QVariantMap domainInfoToSummary(const dscc::DomainInfo &info) const;
    QVariantMap instanceInfoToVariant(const dscc::InstanceInfo &info) const;
    QVariantMap messageInfoToVariant(const dscc::MessageInfo &info) const;

    struct FileCryptoOperation
    {
        QString sourceFile;
        QString targetFile;
    };

    std::unique_ptr<dscc::UserAssets> m_assets;
    QString m_metaDbPath;
    QString m_dsccDataRoot;
    QString m_serverUrl;
    QString m_credential;
    QString m_currentUserId;
    QString m_currentUserName;
    bool m_initializingUserAssets = false;
    dscc::Notification m_userAssetsInitializationError;
    QHash<QString, QList<dscc::VisibleUserInfo>> m_domainVisibleUsersCache;
    QHash<uint32_t, QString> m_domainCreateFailureMessages;
    QHash<uint32_t, FileCryptoOperation> m_encryptFileOperations;
};

#endif // DSCCBRIDGE_H
