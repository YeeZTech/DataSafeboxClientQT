#ifndef ARREARSMANAGER_H
#define ARREARSMANAGER_H

#include "AppConfig.h"
#include <QObject>
#include <QString>
#include <QVariantMap>

class QNetworkAccessManager;

class ArrearsManager : public QObject
{
    Q_OBJECT
  public:
    explicit ArrearsManager(QObject *parent = nullptr);

    Q_INVOKABLE void getArrearsOverview(const QString &token);

  signals:
    void arrearsOverviewFetched(const QVariantMap &result);
    void arrearsOverviewFetchFailed(const QString &error);

  private:
    QNetworkAccessManager *m_network;
};

#endif // ARREARSMANAGER_H
