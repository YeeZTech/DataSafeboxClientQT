#include "UpdateManager.h"
#include "AppConfig.h"
#include <QCoreApplication>
#include <QDebug>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>

static QString normalizeVersionString(const QString &version)
{
    QString normalized = version.trimmed();
    if (normalized.startsWith("v", Qt::CaseInsensitive))
    {
        normalized.remove(0, 1);
    }
    return normalized;
}

static QString inferVersionFromInstallerPath(const QString &installerPath)
{
    const QString fileName = QFileInfo(installerPath).completeBaseName();
    static const QRegularExpression re(QStringLiteral("([0-9]+(?:\\.[0-9]+){1,3})"));
    const QRegularExpressionMatch match = re.match(fileName);
    if (!match.hasMatch())
    {
        return QString();
    }
    return normalizeVersionString(match.captured(1));
}

// Parse a human-readable size string such as "285.99MB" into bytes (1024-based).
// Falls back to MB when no unit is present; returns 0 when unparseable.
static qint64 parseSizeToBytes(const QString &sizeText)
{
    const QString s = sizeText.trimmed();
    if (s.isEmpty())
        return 0;

    static const QRegularExpression re(QStringLiteral("([0-9]+(?:\\.[0-9]+)?)\\s*(GB|MB|KB|B)?"),
                                       QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(s);
    if (!m.hasMatch())
        return 0;

    const double value = m.captured(1).toDouble();
    const QString unit = m.captured(2).toUpper();
    double multiplier = 1024.0 * 1024.0; // default to MB
    if (unit == QLatin1String("GB"))
        multiplier = 1024.0 * 1024.0 * 1024.0;
    else if (unit == QLatin1String("KB"))
        multiplier = 1024.0;
    else if (unit == QLatin1String("B"))
        multiplier = 1.0;
    return static_cast<qint64>(value * multiplier);
}

// Format a duration in seconds as HH:MM:SS.
static QString formatRemainingTime(qint64 totalSeconds)
{
    if (totalSeconds < 0)
        totalSeconds = 0;
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 seconds = totalSeconds % 60;
    return QStringLiteral("%1:%2:%3")
        .arg(hours, 2, 10, QLatin1Char('0'))
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds, 2, 10, QLatin1Char('0'));
}

UpdateManager::UpdateManager(QObject *parent)
    : QObject(parent), m_networkManager(new QNetworkAccessManager(this)), m_forceUpdate(false), m_clientSize(0),
      m_isDownloading(false), m_isChecking(false), m_manualCheck(false), m_downloadProgress(0.0),
      m_currentReply(nullptr), m_downloadFile(nullptr), m_lastBytesReceived(0), m_bytesReceivedSinceLastTimer(0),
      m_clientType(1) // Default to Windows
      ,
      m_hasPendingInstall(false)
{
    m_networkManager = new QNetworkAccessManager(this);
    m_speedTimer = new QTimer(this);
    m_speedTimer->setInterval(1000); // 1 second
    connect(m_speedTimer, &QTimer::timeout, this, &UpdateManager::updateSpeed);

    // Initialize pending install state file path
    QString cacheDir = QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation))
                           .filePath(AppCfg::environmentDirName());
    m_pendingInstallStateFile = QDir(cacheDir).filePath(".pending_install");

    // Load pending install state from disk
    loadPendingInstallState();
}

UpdateManager::~UpdateManager()
{
    if (m_downloadFile)
    {
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

QString UpdateManager::downloadEta() const
{
    return m_downloadEtaStr;
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
    if (m_isChecking)
        return;

    m_manualCheck = manual;
    m_isChecking = true;
    emit checkStatusChanged();

    QNetworkRequest request;
    QString updateUrl = QLatin1String(AppCfg::API_BASE_URL) + QLatin1String("/api/appVersion/latest/info");
    request.setUrl(QUrl(updateUrl));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded;charset=utf-8");
    request.setRawHeader("Accept", "application/json");
    request.setTransferTimeout(15000);

#if QT_CONFIG(ssl)
    QSslConfiguration sslConfig = QSslConfiguration::defaultConfiguration();
    sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
    request.setSslConfiguration(sslConfig);
#endif

    // This endpoint takes no request parameters; send an empty form body.
    QNetworkReply *reply = m_networkManager->post(request, QByteArray());

    connect(reply, &QNetworkReply::finished, this, [this, reply, manual]() {
        m_isChecking = false;
        emit checkStatusChanged();

        const QByteArray response = reply->readAll();
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        qInfo().noquote()
            << QStringLiteral("[UpdateCheck] HTTP %1, body=%2").arg(httpStatus).arg(QString::fromUtf8(response));

        if (reply->error() == QNetworkReply::NoError)
        {
            QJsonDocument jsonDoc = QJsonDocument::fromJson(response);

            if (jsonDoc.isObject())
            {
                QJsonObject obj = jsonDoc.object();
                int resultCode = obj["resultCode"].toInt();

                if (resultCode == 200)
                {
                    QJsonObject data = obj["data"].toObject();
                    QString latestVersion = normalizeVersionString(data["versionNo"].toString());

                    if (!isNewerVersion(latestVersion))
                    {
                        // The client is already at or ahead of the backend's latest version.
                        // This covers both the equal case and a client build (e.g. 1.0.4) that
                        // is newer than the backend's latest (e.g. 1.0.3): such a client is up to
                        // date and must never be prompted — let alone force-updated — to downgrade.
                        if (manual)
                        {
                            emit noUpdateAvailable();
                        }
                    }
                    else
                    {
                        // A strictly newer version is available — notify the UI so the update
                        // dialog pops up.
                        m_latestVersion = latestVersion;
                        // isNewerVersion() is guaranteed true here, so honor the backend's force flag.
                        m_forceUpdate = data["needForceUpdate"].toBool();
                        // m_forceUpdate = true;

                        // Resolve the download URL and (approximate) size for the platform we
                        // are running on, so startDownload() fetches the matching installer.
#if defined(Q_OS_WIN)
                        m_downloadUrl = data["downloadWin"].toString();
                        m_clientSize = parseSizeToBytes(data["sizeWin"].toString());
                        const QString defaultExt = QStringLiteral("exe");
#elif defined(Q_OS_MACOS)
                        m_downloadUrl = data["downloadMac"].toString();
                        m_clientSize = parseSizeToBytes(data["sizeMac"].toString());
                        const QString defaultExt = QStringLiteral("dmg");
#else
                        m_downloadUrl = data["downloadLinux"].toString();
                        m_clientSize = parseSizeToBytes(data["sizeLinux"].toString());
                        const QString defaultExt = QStringLiteral("deb");
#endif

                        // Resolve the local installer path: <cache>/update/<filename>.
                        if (!m_downloadUrl.isEmpty() && !m_cacheDirectory.isEmpty())
                        {
                            QString fileName = QUrl(m_downloadUrl).fileName();
                            if (fileName.isEmpty())
                                fileName = QStringLiteral("DataSafeboxSetup-%1.%2").arg(m_latestVersion, defaultExt);
                            QDir updateDir(QDir(m_cacheDirectory).filePath(QStringLiteral("update")));
                            if (!updateDir.exists())
                                updateDir.mkpath(QStringLiteral("."));
                            m_downloadedFilePath = updateDir.filePath(fileName);
                        }

                        emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
                    }
                }
                else
                {
                    QString message = obj["resultDesc"].toString();
                    if (manual || !message.isEmpty())
                    {
                        emit checkUpdateFailed(message.isEmpty() ? tr("Failed to check for updates") : message);
                    }
                }
            }
            else
            {
                if (manual)
                {
                    emit checkUpdateFailed(tr("Invalid server response format"));
                }
            }
        }
        else
        {
            int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QString errorMsg = reply->errorString();

            if (manual)
            {
                QString lower = errorMsg.toLower();
                QString friendlyMsg = errorMsg;

                if (lower.contains("host not found") || lower.contains("unable to resolve"))
                    friendlyMsg = tr("Cannot resolve server address, please check your network");
                else if (lower.contains("timed out") || lower.contains("timeout"))
                    friendlyMsg = tr("Connection timed out, please check your network and try again");
                else if (lower.contains("ssl") || lower.contains("certificate"))
                    friendlyMsg = tr("SSL verification failed, please check your network environment");
                else if (errorMsg.trimmed().isEmpty())
                    friendlyMsg = tr("Network error, please check your network and try again");
                else if (httpCode > 0)
                    friendlyMsg = tr("Server error: HTTP %1").arg(httpCode);

                emit checkUpdateFailed(friendlyMsg);
            }
        }

        reply->deleteLater();
    });
}

void UpdateManager::checkRemoteFileStatus()
{
    // Reset progress first
    m_downloadProgress = 0.0;

    // IMPORTANT: Only check files in the new cache directory
    // Ignore any old files in system Temp directory from previous versions
    if (m_cacheDirectory.isEmpty())
    {
        emit downloadProgressChanged(0.0);
        emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
        return;
    }

    // If local file doesn't exist, no need to HEAD Check
    if (!QFile::exists(m_downloadedFilePath))
    {
        emit downloadProgressChanged(0.0);
        emit updateAvailable(m_latestVersion, m_updateDescription, m_forceUpdate);
        return;
    }

    QNetworkRequest headRequest;
    headRequest.setUrl(QUrl(m_downloadUrl));
    QNetworkReply *headReply = m_networkManager->head(headRequest);

    connect(headReply, &QNetworkReply::finished, this, [this, headReply]() {
        headReply->deleteLater();
        if (headReply->error() == QNetworkReply::NoError)
        {
            qint64 remoteSize = headReply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
            qint64 localSize = QFileInfo(m_downloadedFilePath).size();

            if (remoteSize > 0 && localSize == remoteSize)
            {
                m_downloadProgress = 1.0;
                emit downloadProgressChanged(1.0);
            }
            else if (remoteSize > 0 && localSize < remoteSize)
            {
                m_downloadProgress = (double)localSize / remoteSize;
                emit downloadProgressChanged(m_downloadProgress);
            }
            else if (remoteSize > 0 && localSize > remoteSize)
            {
                // Local file is larger than remote target, likely stale/corrupted. Remove and restart from zero.
                QFile::remove(m_downloadedFilePath);
                m_downloadProgress = 0.0;
                emit downloadProgressChanged(0.0);
            }
        }
        else
        {
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
    if (remote.isEmpty() || remote == current)
        return false;

    QStringList remoteParts = remote.split('.');
    QStringList currentParts = current.split('.');

    int length = std::max(remoteParts.size(), currentParts.size());

    for (int i = 0; i < length; ++i)
    {
        int r = i < remoteParts.size() ? remoteParts[i].toInt() : 0;
        int c = i < currentParts.size() ? currentParts[i].toInt() : 0;
        if (r > c)
            return true;
        if (r < c)
            return false;
    }

    return false;
}

void UpdateManager::startDownload()
{
    if (m_isDownloading)
        return;

    if (m_downloadUrl.isEmpty())
    {
        emit downloadFailed(tr("Invalid download URL"));
        return;
    }

    // If local installer is already complete, skip download and enter install flow directly.
    if (!m_downloadedFilePath.isEmpty() && QFile::exists(m_downloadedFilePath) && m_clientSize > 0)
    {
        qint64 localSize = QFileInfo(m_downloadedFilePath).size();
        if (localSize == m_clientSize)
        {
            m_downloadProgress = 1.0;
            emit downloadProgressChanged(1.0);
            installUpdate();
            return;
        }
        if (localSize > m_clientSize)
        {
            QFile::remove(m_downloadedFilePath);
        }
    }

    // Check for existing partial file for resume
    qint64 existingSize = 0;

    if (m_downloadFile)
    {
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    m_downloadFile = new QFile(m_downloadedFilePath);

    // Try to open in Append mode to support resume, or WriteOnly to start over
    // Ideally we should check if the server supports range requests, but for COS/CDN it usually does.
    // Here we assume we can resume if file exists.
    bool resume = false;
    if (m_downloadFile->exists())
    {
        existingSize = m_downloadFile->size();

        if (m_clientSize > 0 && existingSize > m_clientSize)
        {
            if (!m_downloadFile->remove())
            {
            }
            existingSize = 0;
        }
        if (existingSize > 0 && m_downloadFile->open(QIODevice::Append))
        {
            resume = true;
        }
    }

    if (!resume)
    {
        if (!m_downloadFile->open(QIODevice::WriteOnly))
        {
            emit downloadFailed(tr("Cannot create download file"));
            return;
        }
        existingSize = 0;
    }

    if (m_isDownloading)
        return; // Add this check again just in case

    QNetworkRequest request;
    request.setUrl(QUrl(m_downloadUrl));

    // Only set Range header if we actually need it and file exists
    if (existingSize > 0)
    {
        // We do NOT know the total size yet, so we can't tell if we are already finished.
        // We will make a request. If server returns 416 (Range Not Satisfiable), it likely means we are done (or file
        // changed).
        QString rangeHeader = QString("bytes=%1-").arg(existingSize);
        request.setRawHeader("Range", rangeHeader.toUtf8());
    }

    m_currentReply = m_networkManager->get(request);
    m_currentReply->setProperty("resumeOffset", existingSize);
    m_currentReply->setProperty("rangeFallbackApplied", false);

    // If server ignores Range and responds with full body (200 without Content-Range),
    // switch to truncate-write mode before appending payload to avoid a corrupted installer file.
    connect(m_currentReply, &QNetworkReply::metaDataChanged, this, [this]() {
        if (!m_currentReply || !m_downloadFile)
        {
            return;
        }

        const qint64 resumeOffset = m_currentReply->property("resumeOffset").toLongLong();
        if (resumeOffset <= 0 || m_currentReply->property("rangeFallbackApplied").toBool())
        {
            return;
        }

        const int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool hasContentRange = m_currentReply->hasRawHeader("Content-Range");
        if (statusCode == 200 && !hasContentRange)
        {
            if (m_downloadFile->isOpen())
            {
                m_downloadFile->close();
            }
            if (!m_downloadFile->open(QIODevice::WriteOnly | QIODevice::Truncate))
            {
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
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError code) {
        if (code == QNetworkReply::ContentAccessDenied || code == QNetworkReply::ContentOperationNotPermittedError ||
            code == QNetworkReply::ProtocolInvalidOperationError)
        {
            // Check for 416 Range Not Satisfiable
            int httpCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (httpCode == 416)
            {
                // Fake a finish
                m_downloadProgress = 1.0;
                emit downloadProgressChanged(1.0);
                // We don't emit downloadFinished here because onDownloadFinished will still be called naturally or we
                // can call it? Usually errorOccurred comes before finished. let onDownloadFinished handle it or we
                // ignore this error.
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
    if (m_isDownloading && m_currentReply)
    {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        m_isDownloading = false;
        m_speedTimer->stop();
        if (m_downloadFile)
        {
            m_downloadFile->flush();
            m_downloadFile->close();
        }
        emit downloadingChanged();
    }
}

void UpdateManager::onDownloadReadyRead()
{
    if (m_downloadFile && m_currentReply)
    {
        QByteArray data = m_currentReply->readAll();
        m_downloadFile->write(data);
        m_bytesReceivedSinceLastTimer += data.size();
    }
}

void UpdateManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    // If resuming, bytesReceived is only for this request. bytesTotal might be partial or full depending on server.
    // Adjust logic for Range request:
    // With Range header, bytesReceived is the chunk size. bytesTotal is usually the chunk size too or full size
    // depending on implementation. For reliable total progress, we need to know the Total file size. However, the
    // easiest way for UI is to trust the reply's progress for the *remaining* part, OR just use a simple approach: if
    // bytesTotal is -1, we assume we don't know.

    // A robust way with Range request:
    // The content-range header usually returns "bytes START-END/TOTAL"
    // We can parse that.

    qint64 totalSize = bytesTotal;
    qint64 currentDownloadSize = bytesReceived;
    const qint64 resumeOffset = (m_currentReply ? m_currentReply->property("resumeOffset").toLongLong() : 0);

    if (m_currentReply->hasRawHeader("Content-Range"))
    {
        QString contentRange = m_currentReply->rawHeader("Content-Range");
        // Format: bytes 5242880-10485759/10485760
        QStringList parts = contentRange.split('/');
        if (parts.size() == 2)
        {
            totalSize = parts[1].toLongLong();
            // Important: When resuming, bytesReceived is the new data.
            // But we are calculating progress based on TOTAL file size.
            // m_downloadFile->size() is reliable because we write to it in readyRead
            // However, readyRead might lag behind onDownloadProgress slightly or vice versa?
            // Actually, m_downloadFile->size() + bytesReceived (if not yet flushed) might be tricky.
            // Better: m_lastBytesReceived + bytesReceived
            currentDownloadSize = resumeOffset + bytesReceived;
        }
    }
    else
    {
        // Normal download, non-resumed or server doesn't report range correctly
        // If we resumed but server ignored Range header (sent 200 instead of 206), bytesReceived is from 0.
        // If server sent 206, bytesReceived is from offset.

        if (resumeOffset > 0 && totalSize > 0)
        {
            // Probably didn't get Content-Range header but still partial? Unlikely for norm compliant servers.
            // If we sent Range but got 200 OK, then totalSize is the full size, and m_lastBytesReceived should be
            // ignored (or file truncated).
            int statusCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (statusCode == 200)
            {
                // Server ignored range, sent full file.
                // We should probably truncated file if we haven't already.
                // But we opened in Append mode?
                // That's a potential corruption if we just append full content to partial content.
                // But for now, let's assume COS works.
                currentDownloadSize = bytesReceived;
            }
            else
            {
                currentDownloadSize = resumeOffset + bytesReceived;
                // bytesTotal is the reducing amount usually?
                // No, for simple GET, bytesTotal is Content-Length.
                totalSize = resumeOffset + bytesTotal;
            }
        }
    }

    // Fallback if totalSize is invalid (e.g. -1)
    if (totalSize <= 0)
        totalSize = 1;

    if (totalSize > 0)
    {
        double progress = (double)currentDownloadSize / totalSize;
        if (progress > 1.0)
            progress = 1.0;

        // Update UI only if changed significantly or finished
        if (qAbs(progress - m_downloadProgress) > 0.001 || progress >= 1.0)
        {
            m_downloadProgress = progress;
            emit downloadProgressChanged(m_downloadProgress);

            // Auto trigger finished state if we hit 100% logic here? No, rely on finished signal.
        }
    }
}

void UpdateManager::updateSpeed()
{
    // m_bytesReceivedSinceLastTimer holds the bytes received during the last second,
    // i.e. the current download speed in bytes/second.
    const qint64 bytesPerSec = m_bytesReceivedSinceLastTimer;
    const QString speed = formatSpeed(bytesPerSec);

    // Estimated remaining time, from the (approximate) total size and current speed.
    QString eta;
    if (bytesPerSec > 0 && m_clientSize > 0 && m_downloadProgress < 1.0)
    {
        const qint64 remainingBytes = static_cast<qint64>(m_clientSize * (1.0 - m_downloadProgress));
        eta = formatRemainingTime(remainingBytes / bytesPerSec);
    }

    if (m_downloadSpeedStr != speed || m_downloadEtaStr != eta)
    {
        m_downloadSpeedStr = speed;
        m_downloadEtaStr = eta;
        // Re-emit progress to carry the new speed/eta values to the UI.
        emit downloadProgressChanged(m_downloadProgress);
    }
    m_bytesReceivedSinceLastTimer = 0;
}

QString UpdateManager::formatSpeed(qint64 bytesPerSec)
{
    if (bytesPerSec < 1024)
    {
        return QString::number(bytesPerSec) + " B/s";
    }
    else if (bytesPerSec < 1024 * 1024)
    {
        return QString::number(bytesPerSec / 1024.0, 'f', 1) + " KB/s";
    }
    else
    {
        return QString::number(bytesPerSec / (1024.0 * 1024.0), 'f', 1) + " MB/s";
    }
}

void UpdateManager::onDownloadFinished()
{
    m_speedTimer->stop();
    m_isDownloading = false;
    emit downloadingChanged();

    if (m_downloadFile)
    {
        m_downloadFile->flush();
        m_downloadFile->close();
    }

    const QNetworkReply::NetworkError err = m_currentReply->error();
    const int httpCode = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    // A 416 (Requested Range Not Satisfiable) while resuming means the local file is
    // already complete — the server has nothing past the bytes we already hold. Treat it
    // as a finished download and continue to the install flow instead of reporting failure.
    const bool finishedOk = (err == QNetworkReply::NoError) || (httpCode == 416);

    if (finishedOk)
    {
        m_downloadProgress = 1.0;
        emit downloadProgressChanged(1.0);
        emit downloadFinished();
        markPendingInstall();
        emit pendingInstallReminder(m_downloadedFilePath);
        qInfo().noquote() << QStringLiteral("[UpdateDownload] finished%1 => file=%2, size=%3")
                                 .arg(httpCode == 416 ? QStringLiteral(" (already complete)") : QString())
                                 .arg(m_downloadedFilePath)
                                 .arg(QFileInfo(m_downloadedFilePath).size());
    }
    else if (err != QNetworkReply::OperationCanceledError)
    {
        emit downloadFailed(tr("Download error: %1").arg(m_currentReply->errorString()));
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
}

void UpdateManager::installUpdate()
{
    QString installerPath = m_downloadedFilePath;
    if ((installerPath.isEmpty() || !QFile::exists(installerPath)) && !m_pendingInstallFilePath.isEmpty() &&
        QFile::exists(m_pendingInstallFilePath))
    {
        installerPath = m_pendingInstallFilePath;
        m_downloadedFilePath = installerPath;
    }

    if (installerPath.isEmpty() || !QFile::exists(installerPath))
    {
        emit checkUpdateFailed(tr("Installer file not found, please download again"));
        return;
    }

    // Normalize path for the OS
    QString nativePath = QDir::toNativeSeparators(installerPath);

    // Start the installer detached - using QProcess is preferred for executables
    bool success = QProcess::startDetached(nativePath, QStringList());

    if (!success)
    {
        // Fallback
        success = QDesktopServices::openUrl(QUrl::fromLocalFile(installerPath));
    }

    if (success)
    {
        // Installer launched successfully; clear pending state so we don't remind again
        clearPendingInstall();
        // Ensure the application quits
        QCoreApplication::quit();
    }
    else
    {
        emit checkUpdateFailed(tr("Cannot launch installer, please install manually.\nLocation: %1").arg(nativePath));
        // Show the file in explorer so user can run manually
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(installerPath).absolutePath()));
    }
}

void UpdateManager::markPendingInstall()
{
    if (m_downloadedFilePath.isEmpty())
    {
        return;
    }

    if (!QFile::exists(m_downloadedFilePath))
    {
        qWarning().noquote()
            << QStringLiteral("[PendingInstall] skip mark: installer not found => %1").arg(m_downloadedFilePath);
        return;
    }

    m_hasPendingInstall = true;
    m_pendingInstallFilePath = m_downloadedFilePath;
    if (m_latestVersion.isEmpty())
    {
        m_latestVersion = inferVersionFromInstallerPath(m_pendingInstallFilePath);
    }
    savePendingInstallState();
    emit pendingInstallChanged();

    qInfo().noquote() << QStringLiteral("[PendingInstall] marked => file=%1").arg(m_pendingInstallFilePath);
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
    m_latestVersion.clear();

    if (m_pendingInstallStateFile.isEmpty() || !QFile::exists(m_pendingInstallStateFile))
    {
        return;
    }

    QFile file(m_pendingInstallStateFile);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        return;
    }

    QByteArray content = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(content);
    if (!doc.isObject())
    {
        qWarning() << "[PendingInstall] invalid state json";
        return;
    }

    QJsonObject obj = doc.object();
    m_hasPendingInstall = obj.value("hasPending").toBool();
    m_pendingInstallFilePath = obj.value("filePath").toString();
    m_latestVersion = normalizeVersionString(obj.value("version").toString());

    if (!m_hasPendingInstall)
    {
        m_pendingInstallFilePath.clear();
        m_latestVersion.clear();
        return;
    }

    // Verify the file still exists
    if (!QFile::exists(m_pendingInstallFilePath))
    {
        m_hasPendingInstall = false;
        m_pendingInstallFilePath.clear();
        m_latestVersion.clear();
        qWarning() << "[PendingInstall] state exists but installer missing, cleared in memory";
    }
    else
    {
        // Restore installer path for install flow after app restart.
        m_downloadedFilePath = m_pendingInstallFilePath;
        if (m_latestVersion.isEmpty())
        {
            m_latestVersion = inferVersionFromInstallerPath(m_pendingInstallFilePath);
        }

        // If the pending installer is for a version we are already running (or older), the
        // update has already been applied — e.g. the installer was launched manually instead
        // of through clearPendingInstall(). Drop the stale state and remove the leftover
        // installer so we don't keep prompting "install now" on every launch.
        if (!m_latestVersion.isEmpty() && !isNewerVersion(m_latestVersion))
        {
            qInfo().noquote() << QStringLiteral("[PendingInstall] installer v%1 not newer than current v%2, "
                                                "clearing stale pending state")
                                     .arg(m_latestVersion, currentVersion());
            QFile::remove(m_pendingInstallFilePath);
            m_hasPendingInstall = false;
            m_pendingInstallFilePath.clear();
            m_latestVersion.clear();
            m_downloadedFilePath.clear();
            savePendingInstallState();
            return;
        }

        qInfo().noquote() << QStringLiteral("[PendingInstall] restored => file=%1").arg(m_pendingInstallFilePath);
    }
}

void UpdateManager::savePendingInstallState()
{
    if (m_pendingInstallStateFile.isEmpty())
    {
        return;
    }

    // Ensure directory exists
    QDir dir(QFileInfo(m_pendingInstallStateFile).absolutePath());
    if (!dir.exists())
    {
        dir.mkpath(".");
    }

    QJsonObject obj;
    obj["hasPending"] = m_hasPendingInstall;
    obj["filePath"] = m_pendingInstallFilePath;
    obj["version"] = m_hasPendingInstall ? m_latestVersion : QString();

    QJsonDocument doc(obj);
    QFile file(m_pendingInstallStateFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text))
    {
        file.write(doc.toJson());
        file.close();
    }
    else
    {
    }
}
