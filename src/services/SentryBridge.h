#ifndef SENTRYBRIDGE_H
#define SENTRYBRIDGE_H

#include <QObject>
#include <QString>

class SentryBridge : public QObject
{
    Q_OBJECT
  public:
    explicit SentryBridge(QObject *parent = nullptr);

    Q_INVOKABLE void captureMessage(const QString &message, int level = 0);
};

#endif // SENTRYBRIDGE_H
