#include "UpdateManager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QUrl>
#include <QProcess>
#include <QDebug>

static QString normalizeVersionString(const QString &version)
{
    QString normalized = version.trimmed();
    if (normalized.startsWith("v", Qt::CaseInsensitive)) {
        normalized.remove(0, 1);
    }
    return normalized;
}

UpdateManager::UpdateManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_forceUpdate(false)
    , m_clientSize(0)
    , m_isDownloading(false)
    , m_isChecking(false)
    , m_manualCheck(false)
    , m_downloadProgress(0.0)
    , m_currentReply(nullptr)
    , m_downloadFile(nullptr)
    , m_lastBytesReceived(0)
    , m_bytesReceivedSinceLastTimer(0)
    , m_clientType(1)  // Default to Windows
    , m_hasPendingInstall(false)
{
    m_speedTimer = new QTimer(this);
    m_speedTimer->setInterval(1000); // 1 second
    connect(m_speedTimer, &QTimer::timeout, this, &UpdateManager::updateSpeed);
    
    // Initialize pending install state file path
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    m_pendingInstallStateFile = QDir(cacheDir).filePath(".pending_install");
    
    // Load pending install state from disk
    loadPendingInstallState();
}

UpdateManager::~UpdateManager()
{
    if (m_downloadFile) {
        if (m_downloadFile->isOpen())
            m_downloadFile->close();
        delete m_downloadFile;
    }
}

QString UpdateManager::currentVersion() const
{
#ifdef APP_VERSION
    return normalizeVersionString(QStringLiteral(APP_VERSION));
#else
    return QStringLiteral("1.0.0");
#endif
}

QString UpdateManager::latestVersion() const
{
    return m_latestVersion;
}

QString UpdateManager::updateDescription() const
{
    return m_updateDescription;
}

qint64 UpdateManager::clientSize() const
{
    return m_clientSize;
}

bool UpdateManager::isDownloading() const
{
    return m_isDownloading;
}

double UpdateManager::downloadProgress() const
{
    return m_downloadProgress;
}

QString UpdateManager::downloadSpeed() const
{
    return m_downloadSpeedStr;
}

bool UpdateManager::isChecking() const
{
    return m_isChecking;
}

bool UpdateManager::hasPendingInstall() const
{
    return m_hasPendingInstall;
}

void UpdateManager::setCacheDirectory(const QString &cacheDir)
{
    m_cacheDirectory = QDir::cleanPath(cacheDir);
}

void UpdateManager::checkUpdate(bool manual)
{
    if (m_isChecking) return;

    m_manualCheck = manual;
    m_isChecking = true;
    emit checkStatusChanged();

    // 版本检查请求由后续接入的动态库提供，当前UI仅作为界面展示。
    m_isChecking = false;
    emit checkStatusChanged();
    emit checkUpdateFailed(QStringLiteral("版本检查服务未接入"));
}

void UpdateManager::checkRemoteFileStatus()
{
    // Reset progress first
    m_downloadProgress = 0.0;

    // IMPORTANT: Only check files in the new cache directory
    // Ignore any old files in system Temp directory from previous versions
    if (m_cacheDirectory.isEmpty()) {
        emit downloadProgressChanged(0.0);
        emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
        return;
    }

    // If local file doesn't exist, no need to HEAD Check
    if (!QFile::exists(m_downloadedFilePath)) {
         emit downloadProgressChanged(0.0);
         emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
         return;
    }

    QNetworkRequest headRequest;
    headRequest.setUrl(QUrl(m_downloadUrl));
    QNetworkReply *headReply = m_networkManager->head(headRequest);

    connect(headReply, &QNetworkReply::finished, this, [this, headReply]() {
        headReply->deleteLater();
        if (headReply->error() == QNetworkReply::NoError) {
             qint64 remoteSize = headReply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
             qint64 localSize = QFileInfo(m_downloadedFilePath).size();

             if (remoteSize > 0 && localSize == remoteSize) {
                 m_downloadProgress = 1.0;
                 emit downloadProgressChanged(1.0);
             } else if (remoteSize > 0 && localSize < remoteSize) {
                 m_downloadProgress = (double)localSize / remoteSize;
                 emit downloadProgressChanged(m_downloadProgress);
             } else if (remoteSize > 0 && localSize > remoteSize) {
                 // Local file is larger than remote target, likely stale/corrupted. Remove and restart from zero.
                 QFile::remove(m_downloadedFilePath);
                 m_downloadProgress = 0.0;
                 emit downloadProgressChanged(0.0);
             }
        } else {
            // Just ignore error and proceed with 0 progress or whatever we have
        }

        // Finally emit update available signal
        emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
    });
}

bool UpdateManager::isNewerVersion(const QString &remoteVer)
{
    QString remote = normalizeVersionString(remoteVer);
    QString current = normalizeVersionString(currentVersion());
    if (remote.isEmpty() || remote == current) return false;

    QStringList remoteParts = remote.split('.');
    QStringList currentParts = current.split('.');

    int length = std::max(remoteParts.size(), currentParts.size());

    for (int i = 0; i < length; ++i) {
        int r = i < remoteParts.size() ? remoteParts[i].toInt() : 0;
        int c = i < currentParts.size() ? currentParts[i].toInt() : 0;
        if (r > c) return true;
        if (r < c) return false;
    }

    return false;
}

void UpdateManager::startDownload()
{
    if (m_isDownloading) return;

    if (m_downloadUrl.isEmpty()) {
        emit downloadFailed("无效的下载地址");
        return;
    }

    // If local installer is already complete, skip download and enter install flow directly.
    if (!m_downloadedFilePath.isEmpty() && QFile::exists(m_downloadedFilePath) && m_clientSize > 0) {
        qint64 localSize = QFileInfo(m_downloadedFilePath).size();
        if (localSize == m_clientSize) {
            m_downloadProgress = 1.0;
            emit downloadProgressChanged(1.0);
            installUpdate();
            return;
        }
        if (localSize > m_clientSize) {
            QFile::remove(m_downloadedFilePath);
        }
    }
    
    // Check for existing partial file for resume
    qint64 existingSize = 0;
    
    if (m_downloadFile) {
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }
    
    m_downloadFile = new QFile(m_downloadedFilePath);
    
    // Try to open in Append mode to support resume, or WriteOnly to start over
    // Ideally we should check if the server supports range requests, but for COS/CDN it usually does.
    // Here we assume we can resume if file exists.
    bool resume = false;
    if (m_downloadFile->exists()) {
        existingSize = m_downloadFile->size();

        if (m_clientSize > 0 && existingSize > m_clientSize) {
            if (!m_downloadFile->remove()) {
            }
            existingSize = 0;
        }
        if (existingSize > 0 && m_downloadFile->open(QIODevice::Append)) {
            resume = true;
        }
    }
    
    if (!resume) {
        if (!m_downloadFile->open(QIODevice::WriteOnly)) {
            emit downloadFailed("无法创建下载文件");
            return;
        }
        existingSize = 0;
    }

    if (m_isDownloading) return; // Add this check again just in case

    QNetworkRequest request;
    request.setUrl(QUrl(m_downloadUrl));
    
    // Only set Range header if we actually need it and file exists
    if (existingSize > 0) {
        // We do NOT know the total size yet, so we can't tell if we are already finished.
        // We will make a request. If server returns 416 (Range Not Satisfiable), it likely means we are done (or file changed).
        QString rangeHeader = QString("bytes=%1-").arg(existingSize);
        request.setRawHeader("Range", rangeHeader.toUtf8());
    }

    m_currentReply = m_networkManager->get(request);
    m_currentReply->setProperty("resumeOffset", existingSize);
    m_currentReply->setProperty("rangeFallbackApplied", false);

    // If server ignores Range and responds with full body (200 without Content-Range),
    // switch to truncate-write mode before appending payload to avoid a corrupted installer file.
    connect(m_currentReply, &QNetworkReply::metaDataChanged, this, [this]() {
        if (!m_currentReply || !m_downloadFile) {
            return;
        }

        const qint64 resumeOffset = m_currentReply->property("resumeOffset").toLongLong();
        if (resumeOffset <= 0 || m_currentReply->property("rangeFallbackApplied").toBool()) {
            return;
        }

        const int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool hasContentRange = m_currentReply->hasRawHeader("Content-Range");
        if (statusCode == 200 && !hasContentRange) {
            if (m_downloadFile->isOpen()) {
                m_downloadFile->close();
            }
            if (!m_downloadFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                return;
            }

            m_currentReply->setProperty("resumeOffset", 0);
            m_currentReply->setProperty("rangeFallbackApplied", true);
            m_lastBytesReceived = 0;
            m_bytesReceivedSinceLastTimer = 0;
            m_downloadProgress = 0.0;
            emit downloadProgressChanged(0.0);
        }
    });

    connect(m_currentReply, &QNetworkReply::downloadProgress, this, &UpdateManager::onDownloadProgress);
    connect(m_currentReply, &QNetworkReply::readyRead, this, &UpdateManager::onDownloadReadyRead);
    connect(m_currentReply, &QNetworkReply::finished, this, &UpdateManager::onDownloadFinished);
    // Handle 416 error specifically
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError code){
        if (code == QNetworkReply::ContentAccessDenied || code == QNetworkReply::ContentOperationNotPermittedError || code == QNetworkReply::ProtocolInvalidOperationError) {
             // Check for 416 Range Not Satisfiable
             int httpCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
             if (httpCode == 416) {
                 // Fake a finish
                 m_downloadProgress = 1.0;
                 emit downloadProgressChanged(1.0);
                 // We don't emit downloadFinished here because onDownloadFinished will still be called naturally or we can call it?
                 // Usually errorOccurred comes before finished.
                 // let onDownloadFinished handle it or we ignore this error.
             }
        }
    });

    m_isDownloading = true;
    m_lastBytesReceived = existingSize; // Base for progress calculation
    m_bytesReceivedSinceLastTimer = 0;
    
    m_speedTimer->start();
    emit downloadingChanged();
}

void UpdateManager::pauseDownload()
{
    if (m_isDownloading && m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        m_isDownloading = false;
        m_speedTimer->stop();
        if (m_downloadFile) {
            m_downloadFile->flush();
            m_downloadFile->close();
        }
        emit downloadingChanged();
    }
}

void UpdateManager::onDownloadReadyRead()
{
    if (m_downloadFile && m_currentReply) {
        QByteArray data = m_currentReply->readAll();
        m_downloadFile->write(data);
        m_bytesReceivedSinceLastTimer += data.size();
    }
}

void UpdateManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    // If resuming, bytesReceived is only for this request. bytesTotal might be partial or full depending on server.
    // Adjust logic for Range request:
    // With Range header, bytesReceived is the chunk size. bytesTotal is usually the chunk size too or full size depending on implementation.
    // For reliable total progress, we need to know the Total file size.
    // However, the easiest way for UI is to trust the reply's progress for the *remaining* part,
    // OR just use a simple approach: if bytesTotal is -1, we assume we don't know.
    
    // A robust way with Range request:
    // The content-range header usually returns "bytes START-END/TOTAL"
    // We can parse that.
    
    qint64 totalSize = bytesTotal;
    qint64 currentDownloadSize = bytesReceived;
    const qint64 resumeOffset = (m_currentReply ? m_currentReply->property("resumeOffset").toLongLong() : 0);
    
    if (m_currentReply->hasRawHeader("Content-Range")) {
         QString contentRange = m_currentReply->rawHeader("Content-Range");
         // Format: bytes 5242880-10485759/10485760
         QStringList parts = contentRange.split('/');
         if (parts.size() == 2) {
             totalSize = parts[1].toLongLong();
             // Important: When resuming, bytesReceived is the new data.
             // But we are calculating progress based on TOTAL file size.
             // m_downloadFile->size() is reliable because we write to it in readyRead
             // However, readyRead might lag behind onDownloadProgress slightly or vice versa?
             // Actually, m_downloadFile->size() + bytesReceived (if not yet flushed) might be tricky.
             // Better: m_lastBytesReceived + bytesReceived
             currentDownloadSize = resumeOffset + bytesReceived;
         }
    } else {
        // Normal download, non-resumed or server doesn't report range correctly
        // If we resumed but server ignored Range header (sent 200 instead of 206), bytesReceived is from 0.
        // If server sent 206, bytesReceived is from offset.
        
        if (resumeOffset > 0 && totalSize > 0) {
            // Probably didn't get Content-Range header but still partial? Unlikely for norm compliant servers.
            // If we sent Range but got 200 OK, then totalSize is the full size, and m_lastBytesReceived should be ignored (or file truncated).
            int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (statusCode == 200) {
                 // Server ignored range, sent full file.
                 // We should probably truncated file if we haven't already.
                 // But we opened in Append mode?
                 // That's a potential corruption if we just append full content to partial content.
                 // But for now, let's assume COS works.
                 currentDownloadSize = bytesReceived; 
            } else {
                  currentDownloadSize = resumeOffset + bytesReceived;
                 // bytesTotal is the reducing amount usually?
                 // No, for simple GET, bytesTotal is Content-Length.
                  totalSize = resumeOffset + bytesTotal;
            }
        }
    }
    
    // Fallback if totalSize is invalid (e.g. -1)
    if (totalSize <= 0) totalSize = 1;

    if (totalSize > 0) {
        double progress = (double)currentDownloadSize / totalSize;
        if (progress > 1.0) progress = 1.0;
        
        // Update UI only if changed significantly or finished
        if (qAbs(progress - m_downloadProgress) > 0.001 || progress >= 1.0) {
            m_downloadProgress = progress;
            emit downloadProgressChanged(m_downloadProgress);
            
            // Auto trigger finished state if we hit 100% logic here? No, rely on finished signal.
        }
    }
}

void UpdateManager::updateSpeed()
{
    // Bytes per second
    QString speed = formatSpeed(m_bytesReceivedSinceLastTimer);
    if (m_downloadSpeedStr != speed) {
        m_downloadSpeedStr = speed;
        // Re-emit progress to carry the new speed value update
        emit downloadProgressChanged(m_downloadProgress); 
    }
    m_bytesReceivedSinceLastTimer = 0;
}

QString UpdateManager::formatSpeed(qint64 bytesPerSec)
{
    if (bytesPerSec < 1024) {
        return QString::number(bytesPerSec) + " B/s";
    } else if (bytesPerSec < 1024 * 1024) {
        return QString::number(bytesPerSec / 1024.0, 'f', 1) + " KB/s";
    } else {
        return QString::number(bytesPerSec / (1024.0 * 1024.0), 'f', 1) + " MB/s";
    }
}

void UpdateManager::onDownloadFinished()
{
    m_speedTimer->stop();
    m_isDownloading = false;
    emit downloadingChanged();
    
    if (m_downloadFile) {
        m_downloadFile->flush();
        m_downloadFile->close();
    }
    
    if (m_currentReply->error() != QNetworkReply::NoError && m_currentReply->error() != QNetworkReply::OperationCanceledError) {
        emit downloadFailed("下载出错: " + m_currentReply->errorString());
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        return;
    }
    
    // Check if truly finished (sometimes finished is called on error too)
    if (m_currentReply->error() == QNetworkReply::NoError) {
        m_downloadProgress = 1.0;
        emit downloadProgressChanged(1.0);
        emit downloadFinished();
        markPendingInstall();
        emit pendingInstallReminder(m_downloadedFilePath);
        qInfo().noquote() << QStringLiteral("[UpdateDownload] finished => file=%1, size=%2")
                              .arg(m_downloadedFilePath)
                              .arg(QFileInfo(m_downloadedFilePath).size());
    } else {
        // Check for 416 (Range Satisfiable) which effectively means done for resume
        int httpCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (httpCode == 416) {
             m_downloadProgress = 1.0;
             emit downloadProgressChanged(1.0);
             emit downloadFinished();
             markPendingInstall();
             emit pendingInstallReminder(m_downloadedFilePath);
             qInfo().noquote() << QStringLiteral("[UpdateDownload] finished (416) => file=%1, size=%2")
                                   .arg(m_downloadedFilePath)
                                   .arg(QFileInfo(m_downloadedFilePath).size());
        }
    }
    
    m_currentReply->deleteLater();
    m_currentReply = nullptr;
}

void UpdateManager::installUpdate()
{
    QString installerPath = m_downloadedFilePath;
    if ((installerPath.isEmpty() || !QFile::exists(installerPath))
        && !m_pendingInstallFilePath.isEmpty()
        && QFile::exists(m_pendingInstallFilePath)) {
        installerPath = m_pendingInstallFilePath;
        m_downloadedFilePath = installerPath;
    }

    if (installerPath.isEmpty() || !QFile::exists(installerPath)) {
        emit checkUpdateFailed("安装文件不存在，请重新下载");
        return;
    }
    
    // Normalize path for the OS
    QString nativePath = QDir::toNativeSeparators(installerPath);
    
    // Start the installer detached - using QProcess is preferred for executables
    bool success = QProcess::startDetached(nativePath, QStringList());
    
    if (!success) {
        // Fallback
        success = QDesktopServices::openUrl(QUrl::fromLocalFile(installerPath));
    }
    
    if (success) {
        // Installer launched successfully; clear pending state so we don't remind again
        clearPendingInstall();
        // Ensure the application quits
        QCoreApplication::quit();
    } else {
        emit checkUpdateFailed("无法启动安装程序，请尝试手动安装。\n位置: " + nativePath);
        // Show the file in explorer so user can run manually
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(installerPath).absolutePath()));
    }
}

void UpdateManager::markPendingInstall()
{
    if (m_downloadedFilePath.isEmpty()) {
        return;
    }

    if (!QFile::exists(m_downloadedFilePath)) {
        qWarning().noquote() << QStringLiteral("[PendingInstall] skip mark: installer not found => %1")
                                .arg(m_downloadedFilePath);
        return;
    }

    m_hasPendingInstall = true;
    m_pendingInstallFilePath = m_downloadedFilePath;
    savePendingInstallState();
    emit pendingInstallChanged();

    qInfo().noquote() << QStringLiteral("[PendingInstall] marked => file=%1")
                          .arg(m_pendingInstallFilePath);
}

void UpdateManager::clearPendingInstall()
{
    m_hasPendingInstall = false;
    m_pendingInstallFilePath.clear();
    savePendingInstallState();
    emit pendingInstallChanged();

    qInfo() << "[PendingInstall] cleared";
}

void UpdateManager::loadPendingInstallState()
{
    m_hasPendingInstall = false;
    m_pendingInstallFilePath.clear();

    if (m_pendingInstallStateFile.isEmpty() || !QFile::exists(m_pendingInstallStateFile)) {
        return;
    }

    QFile file(m_pendingInstallStateFile);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QByteArray content = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(content);
    if (!doc.isObject()) {
        qWarning() << "[PendingInstall] invalid state json";
        return;
    }

    QJsonObject obj = doc.object();
    m_hasPendingInstall = obj.value("hasPending").toBool();
    m_pendingInstallFilePath = obj.value("filePath").toString();

    // Verify the file still exists
    if (!QFile::exists(m_pendingInstallFilePath)) {
        m_hasPendingInstall = false;
        m_pendingInstallFilePath.clear();
        qWarning() << "[PendingInstall] state exists but installer missing, cleared in memory";
    } else {
        // Restore installer path for install flow after app restart.
        m_downloadedFilePath = m_pendingInstallFilePath;
        qInfo().noquote() << QStringLiteral("[PendingInstall] restored => file=%1")
                              .arg(m_pendingInstallFilePath);
    }
}

void UpdateManager::savePendingInstallState()
{
    if (m_pendingInstallStateFile.isEmpty()) {
        return;
    }
    
    // Ensure directory exists
    QDir dir(QFileInfo(m_pendingInstallStateFile).absolutePath());
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    
    QJsonObject obj;
    obj["hasPending"] = m_hasPendingInstall;
    obj["filePath"] = m_pendingInstallFilePath;
    
    QJsonDocument doc(obj);
    QFile file(m_pendingInstallStateFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(doc.toJson());
        file.close();
    } else {
    }
}
