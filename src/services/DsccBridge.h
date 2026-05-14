#ifndef DSCCBRIDGE_H
#define DSCCBRIDGE_H

#include <QMap>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

#include "dscc/core/common/active_notify.h"
#include "dscc/core/interface/user_assets.h"

class DsccBridge : public QObject
{
    Q_OBJECT

public:
    explicit DsccBridge(const QString &metaDbPath,
                        const QString &dbPath,
                        const QString &serverUrl,
                        const QString &credential,
                        QObject *parent = nullptr);
    ~DsccBridge() override;

    void initialize();
    void shutdown();

    // 登录后设置当前用户
    Q_INVOKABLE void setCurrentUser(const QString &userId,
                                    const QString &userName,
                                    const QString &accessToken,
                                    const QString &refreshToken);

    // ── 读操作（触发后通过信号异步返回数据）──────────────────────────────────
    // 加载安全域列表（侧边栏）
    Q_INVOKABLE void loadDomainList();

    // 加载安全域基本信息（基本信息卡片）
    Q_INVOKABLE void loadDomainSummary(const QString &domainCode);

    // 加载可见用户列表
    Q_INVOKABLE void loadVisibleUsers(const QString &domainCode);

    // 加载实例列表（按域）
    // ⚠️ stub：等 DSCC 补充 ListInstances(domainCode) 后实现
    Q_INVOKABLE void loadInstances(const QString &domainCode);

    // 加载审计列表（按域），applyType: 1=白名单  2=导出文件
    // ⚠️ stub：等 DSCC 补充 ListAudits(domainCode, applyType) 后实现
    Q_INVOKABLE void loadAudits(const QString &domainCode, int applyType);

    // ── 写操作（调用后通过信号异步回调结果）──────────────────────────────────
    // 创建安全域，info 字段: domainName, remarks, payer, visibleUsers
    Q_INVOKABLE void createDomain(const QVariantMap &info);

    // 关闭安全域
    Q_INVOKABLE void closeDomain(const QString &domainCode);

    // 修改安全域描述
    Q_INVOKABLE void updateDomainDesc(const QString &domainCode, const QString &desc);

    // 添加/移除安全域可见用户
    Q_INVOKABLE void addUserToDomain(const QString &domainCode, const QString &userId);
    Q_INVOKABLE void removeUserFromDomain(const QString &domainCode, const QString &userId);

    // 实例操作（createInstance 本阶段不实现）
    Q_INVOKABLE void startInstance(const QString &instanceCode);
    Q_INVOKABLE void deleteInstance(const QString &instanceCode);

    // 白名单操作
    Q_INVOKABLE void addWhitelistToInstance(const QString &instanceCode, const QString &filePath);
    Q_INVOKABLE void removeWhitelistFromInstance(const QString &instanceCode, const QString &fileCode);

    // 文件操作
    Q_INVOKABLE void importFileToInstance(const QString &instanceCode, const QString &filePath);
    Q_INVOKABLE void exportFileFromInstance(const QString &instanceCode, const QString &filePath);

signals:
    // ── 数据加载信号（均携带 domainCode 防竞态）─────────────────────────────
    // 安全域列表，每个元素: { domainCode, name, pubKey, status, createdAt }
    void domainListLoaded(QVariantList domains);
    // 安全域基本信息: { domainCode, name, pubKey, status, creator, payer, description, createdAt }
    void domainSummaryLoaded(QString domainCode, QVariantMap summary);
    // 可见用户列表，每个元素: { account, authUserId, authUserName, displayName }
    void visibleUsersLoaded(QString domainCode, QVariantList users);
    // 实例列表，每个元素: { instanceCode, domainCode, name, status, creator, createdAt, ... }
    void instancesLoaded(QString domainCode, QVariantList instances);
    // 审计列表，applyType: 1=白名单  2=导出文件
    void auditsLoaded(QString domainCode, int applyType, QVariantList audits);

    // ── 安全域写操作结果信号 ───────────────────────────────────────────────
    void domainCreated(quint32 operationId, QString domainCode, QString domainName);
    void domainCreateFailed(quint32 operationId, QString errorMessage);
    void domainClosed(quint32 operationId, QString domainCode);
    void domainCloseFailed(quint32 operationId, QString domainCode, QString errorMessage);
    void domainDescUpdated(quint32 operationId, QString domainCode);
    void domainDescUpdateFailed(quint32 operationId, QString domainCode, QString errorMessage);
    void addUserToDomainSuccess(quint32 operationId, QString domainCode, QString userId);
    void addUserToDomainFailed(quint32 operationId, QString domainCode, QString userId, QString errorMessage);
    void removeUserFromDomainSuccess(quint32 operationId, QString domainCode, QString userId);
    void removeUserFromDomainFailed(quint32 operationId, QString domainCode, QString userId, QString errorMessage);

    // ── 实例写操作结果信号 ────────────────────────────────────────────────
    void instanceStarted(quint32 operationId, QString instanceCode);
    void instanceStartFailed(quint32 operationId, QString instanceCode, QString errorMessage);
    void instanceDeleted(quint32 operationId, QString instanceCode);
    void instanceDeleteFailed(quint32 operationId, QString instanceCode, QString errorMessage);

    // ── 白名单写操作结果信号 ──────────────────────────────────────────────
    void whitelistAdded(quint32 operationId, QString instanceCode, QString filePath);
    void whitelistAddFailed(quint32 operationId, QString instanceCode, QString filePath, QString errorMessage);
    void whitelistRemoved(quint32 operationId, QString instanceCode, QString fileCode);
    void whitelistRemoveFailed(quint32 operationId, QString instanceCode, QString fileCode, QString errorMessage);

    // ── 文件操作结果信号 ──────────────────────────────────────────────────
    void fileImported(quint32 operationId, QString instanceCode, QString filePath);
    void fileImportFailed(quint32 operationId, QString instanceCode, QString filePath, QString errorMessage);
    void fileImportProgress(quint32 operationId, QString instanceCode, quint64 processedBytes, quint64 totalBytes);
    void fileExported(quint32 operationId, QString instanceCode, QString filePath);
    void fileExportFailed(quint32 operationId, QString instanceCode, QString filePath, QString errorMessage);

private:
    // Notification → 用户可读字符串（替换占位符）
    QString notificationToString(const dscc::Notification &n) const;

    std::unique_ptr<dscc::UserAssets> m_assets;
    QString m_metaDbPath;
    QString m_serverUrl;

    QString m_currentUserName;  // setCurrentUser 时记录，用于 creator 字段兑底

    // key: operationId，value: 创建时提交的 DomainInfo（用于回调中补充 domain_name）
    QMap<quint32, dscc::DomainInfo> m_pendingCreateDomain;

    // 本会话内存兜底：DSCC 未把 creator 持久化到本地时，
    // 用创建表单里的信息补齐 loadDomainSummary 返回的空字段。
    // key: domainCode，value: 创建时提交的 DomainInfo
    QMap<QString, dscc::DomainInfo> m_createdDomainCache;
};

#endif // DSCCBRIDGE_H
