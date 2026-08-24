#ifndef SENTRYBRIDGE_H
#define SENTRYBRIDGE_H

#include <QObject>
#include <QString>
#include <QVariantMap>

class SentryBridge : public QObject
{
    Q_OBJECT
  public:
    explicit SentryBridge(QObject *parent = nullptr);

    Q_INVOKABLE void captureMessage(const QString &message, int level = 0);

    // C++-only helpers shared by main.cpp / DsccBridge / CasdoorHelper wiring so every call
    // site produces the same structured breadcrumb/event shape instead of ad-hoc strings.
    static void addBreadcrumb(const QString &category, const QString &level, const QString &message,
                              const QVariantMap &data = {});
    static void captureError(const QString &loggerName, const QString &message, const QVariantMap &tags,
                             const QVariantMap &extra);
    static void setUser(const QString &id, const QString &username, const QString &email);
    static void clearUser();
    static void setContext(const QString &key, const QVariantMap &data);
    static void setTag(const QString &key, const QString &value);

    // Populates the app/device/culture/runtime contexts and the machine-level tags that
    // sentry-native does not collect on its own. Call once, after sentry_init().
    static void installStartupContexts(const QString &appVersion);
    // Re-reads the volatile parts (process/system memory) so reports carry current figures.
    static void refreshRuntimeContext();
};

#endif // SENTRYBRIDGE_H
