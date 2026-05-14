#include "PathManager.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

PathManager::PathManager(QObject *parent)
    : QObject(parent)
    , m_cacheSizeBytes(0)
{
    m_rootDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (m_rootDir.isEmpty()) {
        m_rootDir = QCoreApplication::applicationDirPath();
    }

    m_dataDir = QDir(m_rootDir).filePath("data");
    m_defaultCacheDir = QDir(m_rootDir).filePath("cache");
    m_cacheDir = m_defaultCacheDir;

    ensureDir(m_dataDir);
    ensureDir(m_defaultCacheDir);

    // Use settings file in rootDir to avoid creating files in AppData\Roaming
    QSettings settings(QDir(m_rootDir).filePath("settings.ini"), QSettings::IniFormat);
    const QString configuredCacheDir = settings.value("paths/cacheDir").toString().trimmed();
    if (!configuredCacheDir.isEmpty() && ensureDir(configuredCacheDir)) {
        m_cacheDir = QDir::cleanPath(configuredCacheDir);
    } else {
        m_cacheDir = QDir::cleanPath(m_defaultCacheDir);
        if (!configuredCacheDir.isEmpty()) {
            settings.remove("paths/cacheDir");
        }
    }

    m_defaultTempDir = QDir(m_cacheDir).filePath("temp");
    m_tempDir = m_defaultTempDir;
    ensureDir(m_cacheDir);
    ensureDir(m_defaultTempDir);

    // Remove deprecated temp override to keep cache-root governance.
    settings.remove("paths/tempDir");

    refreshCacheSize();
}

QString PathManager::rootDir() const
{
    return m_rootDir;
}

QString PathManager::dataDir() const
{
    return m_dataDir;
}

QString PathManager::cacheDir() const
{
    return m_cacheDir;
}

QString PathManager::defaultTempDir() const
{
    return m_defaultTempDir;
}

QString PathManager::tempDir() const
{
    return m_tempDir;
}

qint64 PathManager::cacheSizeBytes() const
{
    return m_cacheSizeBytes;
}

QString PathManager::featureDataDir(const QString &feature) const
{
    const QString cleanedFeature = feature.trimmed();
    if (cleanedFeature.isEmpty()) {
        return m_dataDir;
    }
    const QString dirPath = QDir(m_dataDir).filePath(cleanedFeature);
    ensureDir(dirPath);
    return QDir::cleanPath(dirPath);
}

QString PathManager::featureCacheDir(const QString &feature) const
{
    const QString cleanedFeature = feature.trimmed();
    if (cleanedFeature.isEmpty()) {
        return m_cacheDir;
    }
    const QString dirPath = QDir(m_cacheDir).filePath(cleanedFeature);
    ensureDir(dirPath);
    return QDir::cleanPath(dirPath);
}

QString PathManager::featureTempDir(const QString &feature) const
{
    const QString cleanedFeature = feature.trimmed();
    if (cleanedFeature.isEmpty()) {
        return m_tempDir;
    }
    const QString dirPath = QDir(m_tempDir).filePath(cleanedFeature);
    ensureDir(dirPath);
    return QDir::cleanPath(dirPath);
}

bool PathManager::setTempDir(const QString &dirPath)
{
    const QString trimmed = dirPath.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }

    if (!ensureDir(trimmed)) {
        return false;
    }

    const QString normalized = QDir::cleanPath(trimmed);

    if (normalized == m_cacheDir) {
        return true;
    }

    m_cacheDir = normalized;
    m_defaultTempDir = QDir(m_cacheDir).filePath("temp");
    m_tempDir = m_defaultTempDir;
    ensureDir(m_defaultTempDir);

    // Use settings file in rootDir to avoid creating files in AppData\Roaming
    QSettings settings(QDir(m_rootDir).filePath("settings.ini"), QSettings::IniFormat);
    settings.setValue("paths/cacheDir", m_cacheDir);
    settings.remove("paths/tempDir");
    emit cacheDirChanged();
    emit tempDirChanged();
    refreshCacheSize();
    return true;
}

void PathManager::resetTempDir()
{
    const QString normalizedDefault = QDir::cleanPath(m_defaultCacheDir);
    if (QDir::cleanPath(m_cacheDir) == normalizedDefault) {
        return;
    }

    m_cacheDir = normalizedDefault;
    m_defaultTempDir = QDir(m_cacheDir).filePath("temp");
    m_tempDir = m_defaultTempDir;
    ensureDir(m_cacheDir);
    ensureDir(m_defaultTempDir);

    // Use settings file in rootDir to avoid creating files in AppData\Roaming
    QSettings settings(QDir(m_rootDir).filePath("settings.ini"), QSettings::IniFormat);
    settings.remove("paths/cacheDir");
    settings.remove("paths/tempDir");
    emit cacheDirChanged();
    emit tempDirChanged();
    refreshCacheSize();
}

bool PathManager::openTempDir()
{
    return openPath(m_cacheDir);
}

bool PathManager::openPath(const QString &path)
{
    const QString cleaned = QDir::cleanPath(path);
    if (!ensureDir(cleaned)) {
        return false;
    }
    return QDesktopServices::openUrl(QUrl::fromLocalFile(cleaned));
}

qint64 PathManager::refreshCacheSize()
{
    const qint64 currentSize = calculateDirSize(m_cacheDir);
    if (currentSize != m_cacheSizeBytes) {
        m_cacheSizeBytes = currentSize;
        emit cacheSizeChanged();
    }
    return m_cacheSizeBytes;
}

qint64 PathManager::clearCache()
{
    const qint64 before = refreshCacheSize();

    clearDirContents(m_cacheDir);

    const qint64 after = refreshCacheSize();
    const qint64 cleaned = before > after ? (before - after) : 0;
    return cleaned;
}

bool PathManager::ensureDir(const QString &path)
{
    QDir dir(path);
    if (dir.exists()) {
        return true;
    }
    return dir.mkpath(".");
}

qint64 PathManager::calculateDirSize(const QString &path)
{
    QDir dir(path);
    if (!dir.exists()) {
        return 0;
    }

    qint64 size = 0;
    QDirIterator it(path, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        size += it.fileInfo().size();
    }
    return size;
}

bool PathManager::clearDirContents(const QString &path)
{
    QDir dir(path);
    if (!dir.exists()) {
        return true;
    }

    bool ok = true;
    const QFileInfoList entries = dir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries);
    for (const QFileInfo &entry : entries) {
        if (entry.isDir()) {
            QDir child(entry.absoluteFilePath());
            ok = child.removeRecursively() && ok;
        } else {
            ok = QFile::remove(entry.absoluteFilePath()) && ok;
        }
    }
    return ok;
}
