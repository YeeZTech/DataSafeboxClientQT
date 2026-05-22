#ifndef UPDATEMANAGER_H
#define UPDATEMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QDateTime>
#include <QTimer>
#include <QDebug>

class UpdateManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY updateAvailable)
    Q_PROPERTY(QString updateDescription READ updateDescription NOTIFY updateAvailable)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY downloadingChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString downloadSpeed READ downloadSpeed NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool isChecking READ isChecking NOTIFY checkStatusChanged)
    Q_PROPERTY(bool hasPendingInstall READ hasPendingInstall NOTIFY pendingInstallChanged)
    Q_PROPERTY(qint64 clientSize READ clientSize NOTIFY updateAvailable)

public:
    explicit UpdateManager(QObject *parent = nullptr);
    ~UpdateManager();

    QString currentVersion() const;
    QString latestVersion() const;
    QString updateDescription() const;
    qint64 clientSize() const;
    bool isDownloading() const;
    double downloadProgress() const;
    QString downloadSpeed() const;
    bool isChecking() const;
    bool hasPendingInstall() const;

    // Check for updates
    // manual: if true, emit signal even if no update (for "Check Now" button)
    Q_INVOKABLE void checkUpdate(bool manual = false);

    // Start or Resume download
    Q_INVOKABLE void startDownload();

    // Pause download
    Q_INVOKABLE void pauseDownload();

    // Configure base cache directory (downloaded installers will be placed under cache/update)
    Q_INVOKABLE void setCacheDirectory(const QString &cacheDir);

    // Install the downloaded update (quits the app)
    Q_INVOKABLE void installUpdate();

    // Handle pending install state
    Q_INVOKABLE void markPendingInstall();
    Q_INVOKABLE void clearPendingInstall();

signals:
    // Found a new version
    void updateAvailable(const QString &version, const QString &desc, bool force);
    // Checked but no new version found (mostly for manual check)
    void noUpdateAvailable();
    // Check failed (network error, etc.)
    void checkUpdateFailed(const QString &message);

    void downloadingChanged();
    void downloadProgressChanged(double progress);
    void downloadFinished();
    void downloadFailed(const QString &message);
    void checkStatusChanged();
    void pendingInstallChanged();
    void pendingInstallReminder(const QString &filePath);  // Reminder to install pending update

private slots:
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onDownloadFinished();
    void onDownloadReadyRead();
    void updateSpeed();

private:
    QNetworkAccessManager *m_networkManager;
    QString m_latestVersion;
    QString m_updateDescription;
    QString m_downloadUrl;
    bool m_forceUpdate;
    qint64 m_clientSize;

    bool m_isDownloading;
    bool m_isChecking;
    bool m_manualCheck; // Was this check initiated manually by user?

    double m_downloadProgress;
    QString m_downloadSpeedStr;
    
    QNetworkReply *m_currentReply;
    QFile *m_downloadFile;
    QString m_downloadedFilePath;
    QString m_cacheDirectory;
    
    // For speed calculation
    qint64 m_lastBytesReceived;
    qint64 m_bytesReceivedSinceLastTimer;
    QTimer *m_speedTimer;

    // Configuration
    int m_clientType;  // 1: Windows, 2: Mac, 3: Linux
    
    // Pending install state
    bool m_hasPendingInstall;
    QString m_pendingInstallFilePath;
    QString m_pendingInstallStateFile;
    
    // Methods for pending install state persistence
    void loadPendingInstallState();
    void savePendingInstallState();
    
    bool isNewerVersion(const QString &remoteVer);
    QString formatSpeed(qint64 bytesPerSec);
    void checkRemoteFileStatus(); // Helper to check file size via HEAD
};

#endif // UPDATEMANAGER_H
