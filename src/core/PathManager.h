#ifndef PATHMANAGER_H
#define PATHMANAGER_H

#include <QObject>

class PathManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString rootDir READ rootDir CONSTANT)
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)
    Q_PROPERTY(QString cacheDir READ cacheDir NOTIFY cacheDirChanged)
    Q_PROPERTY(QString defaultTempDir READ defaultTempDir NOTIFY cacheDirChanged)
    Q_PROPERTY(QString tempDir READ tempDir NOTIFY cacheDirChanged)
    Q_PROPERTY(qint64 cacheSizeBytes READ cacheSizeBytes NOTIFY cacheSizeChanged)

public:
    explicit PathManager(QObject *parent = nullptr);

    QString rootDir() const;
    QString dataDir() const;
    QString cacheDir() const;
    QString defaultTempDir() const;
    QString tempDir() const;
    qint64 cacheSizeBytes() const;

    Q_INVOKABLE QString featureDataDir(const QString &feature) const;
    Q_INVOKABLE QString featureCacheDir(const QString &feature) const;
    Q_INVOKABLE QString featureTempDir(const QString &feature) const;

    Q_INVOKABLE bool setTempDir(const QString &dirPath);
    Q_INVOKABLE void resetTempDir();
    Q_INVOKABLE bool openTempDir();
    Q_INVOKABLE bool openPath(const QString &path);
    Q_INVOKABLE qint64 refreshCacheSize();
    Q_INVOKABLE qint64 clearCache();

signals:
    void cacheDirChanged();
    void tempDirChanged();
    void cacheSizeChanged();

private:
    QString m_rootDir;
    QString m_dataDir;
    QString m_defaultCacheDir;
    QString m_cacheDir;
    QString m_defaultTempDir;
    QString m_tempDir;
    qint64 m_cacheSizeBytes;

    static bool ensureDir(const QString &path);
    static qint64 calculateDirSize(const QString &path);
    static bool clearDirContents(const QString &path);
};

#endif // PATHMANAGER_H
