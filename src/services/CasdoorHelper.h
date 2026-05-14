#ifndef CASDOORHELPER_H
#define CASDOORHELPER_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QTimer>
#include "AppConfig.h"

class QNetworkAccessManager;

class CasdoorHelper : public QObject
{
    Q_OBJECT
public:
    explicit CasdoorHelper(QObject *parent = nullptr);
    static CasdoorHelper* instance();

    // Configuration
    const QString endpoint  = QLatin1String(AppCfg::CASDOOR_ENDPOINT);
    const QString clientId  = QLatin1String(AppCfg::CASDOOR_CLIENT_ID);

    Q_INVOKABLE QString getSigninUrl();
    Q_INVOKABLE QString getRedirectUri() const { return redirectUri; }
    Q_INVOKABLE QString getStateValue()  const { return m_oauthState; }
    Q_INVOKABLE QString getEndpoint()    const { return endpoint; }
    Q_INVOKABLE void handleAuthCode(const QString &code, const QString &state = QString());
    Q_INVOKABLE void searchUser(const QString &username);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearCasdoorCookies();

signals:
    void loginSuccess(const QVariantMap &user);
    void loginFailed(const QString &errorMessage);
    void logoutCompleted();
    void logoutFailed(const QString &errorMessage);
    void userSearchCompleted(const QVariantMap &userInfo);
    void userSearchFailed(const QString &errorMessage);

private slots:
    void onLoginWatchdogTimeout();

private:
    const QString redirectUri = QLatin1String(AppCfg::CASDOOR_REDIRECT_URI);

    QString  m_oauthState;
    QString  m_currentToken;
    QString  m_currentIdToken;
    QString  m_sessionToken;
    QString  m_sessionOwner;
    bool     m_authCodeExchangeInFlight = false;
    QString  m_inFlightAuthCode;
    QTimer   m_loginWatchdog;

    QNetworkAccessManager *m_network;

    void clearAuthExchangeState();
    void callBackendLogin(const QString &code, const QString &state);
    void onBackendLoginFinished(const QByteArray &body, const QString &netError);
    void fetchCasdoorUserInfo(const QString &accessToken);
};

#endif // CASDOORHELPER_H
