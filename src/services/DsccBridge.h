#ifndef DSCCBRIDGE_H
#define DSCCBRIDGE_H

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

#include "dscc/core/interface/user_assets.h"

class DsccBridge : public QObject
{
    Q_OBJECT

public:
    explicit DsccBridge(const QString &metaDbPath,
                        const QString &dsccDataRoot,
                        const QString &serverUrl,
                        const QString &credential,
                        QObject *parent = nullptr);
    ~DsccBridge() override;

    void initialize();
    void shutdown();

    Q_INVOKABLE void setCurrentUser(const QString &userId,
                                    const QString &userName,
                                    const QString &accessToken,
                                    const QString &refreshToken);
    Q_INVOKABLE void clearCurrentUser();

    Q_INVOKABLE void loadDomainList();
    Q_INVOKABLE void loadDomainSummary(const QString &domainCode);
    Q_INVOKABLE void createDomain(const QVariantMap &info);
    Q_INVOKABLE void closeDomain(const QString &domainCode);
    Q_INVOKABLE QString domainCreateFailureMessage(uint32_t operation_id,
                                                   const QString &fallback) const;

signals:
    void domainListLoaded(QVariantList domains);
    void domainSummaryLoaded(QString domainCode, QVariantMap summary);
    void domainCreated(uint32_t operation_id, QString domain_code);
    void domainCreateFailed(uint32_t operation_id, dscc::Notification notification);
    void domainClosed(uint32_t operation_id, QString domain_code);
    void domainCloseFailed(uint32_t operation_id, QString domain_code, dscc::Notification notification);

private:
    void connectAssetSignals();
    QString userDomainDbPath(const QString &userId) const;
    QVariantMap domainInfoToSummary(const dscc::DomainInfo &info) const;

    std::unique_ptr<dscc::UserAssets> m_assets;
    QString m_metaDbPath;
    QString m_dsccDataRoot;
    QString m_serverUrl;
    QString m_credential;
    QString m_currentUserId;
    QString m_currentUserName;
    QHash<uint32_t, QString> m_domainCreateFailureMessages;
};

#endif // DSCCBRIDGE_H
