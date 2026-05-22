#include "ArrearsManager.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

ArrearsManager::ArrearsManager(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
}

void ArrearsManager::getArrearsOverview(const QString &token)
{
    if (token.isEmpty()) {
        emit arrearsOverviewFetchFailed("Token is required");
        return;
    }

    QUrl url(QLatin1String(AppCfg::API_BASE_URL) + QLatin1String("/api/user/arrears/overview"));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("token", token.toUtf8());
    req.setTransferTimeout(15000);

    QNetworkReply *reply = m_network->post(req, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit arrearsOverviewFetchFailed(reply->errorString());
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            emit arrearsOverviewFetchFailed("解析欠费状态失败");
            return;
        }
        const QJsonObject obj = doc.object();
        const int resultCode = obj.value("resultCode").toInt();
        if (resultCode != 200) {
            const QString desc = obj.value("resultDesc").toString(
                obj.value("msg").toString("获取欠费状态失败"));
            emit arrearsOverviewFetchFailed(desc);
            return;
        }
        emit arrearsOverviewFetched(obj.value("data").toObject().toVariantMap());
    });
}
