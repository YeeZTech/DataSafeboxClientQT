#ifndef CASDOORHELPER_H
#define CASDOORHELPER_H

#include "AppConfig.h"
#include <QNetworkCookie>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantMap>

class QNetworkAccessManager;
class QWebEngineCookieStore;

class CasdoorHelper : public QObject
{
    Q_OBJECT
  public:
    explicit CasdoorHelper(QObject *parent = nullptr);
    static CasdoorHelper *instance();

    // Configuration
    const QString endpoint = QLatin1String(AppCfg::currentProfile().casdoorEndpoint);
    const QString clientId = QLatin1String(AppCfg::currentProfile().casdoorClientId);

    Q_INVOKABLE QString getSigninUrl();
    Q_INVOKABLE QString getRedirectUri() const
    {
        return redirectUri;
    }
    Q_INVOKABLE QString getStateValue() const
    {
        return m_oauthState;
    }
    Q_INVOKABLE QString getEndpoint() const
    {
        return endpoint;
    }
    Q_INVOKABLE void handleAuthCode(const QString &code, const QString &state = QString());
    Q_INVOKABLE void searchUser(const QString &username);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearCasdoorCookies();
    Q_INVOKABLE void setCasdoorWebProfile(QObject *profile);

  signals:
    void loginSuccess(const QVariantMap &user);
    void loginFailed(const QString &errorMessage);
    void logoutCompleted();
    void logoutFailed(const QString &errorMessage);
    void userSearchCompleted(const QVariantMap &userInfo);
    void userSearchFailed(const QString &errorMessage);

  private slots:
    void onLoginWatchdogTimeout();
    void onCookieAdded(const QNetworkCookie &cookie);
    void onCookieRemoved(const QNetworkCookie &cookie);

  private:
    const QString redirectUri = QLatin1String(AppCfg::currentProfile().casdoorRedirectUri);

    QString m_oauthState;
    QString m_currentToken;
    QString m_currentIdToken;
    QString m_sessionToken;
    QString m_sessionOwner;
    bool m_authCodeExchangeInFlight = false;
    QString m_inFlightAuthCode;
    QTimer m_loginWatchdog;

    QNetworkAccessManager *m_network;
    QWebEngineCookieStore *m_cookieStore = nullptr;
    QString m_casdoorSessionId;

    void clearAuthExchangeState();
    void callBackendLogin(const QString &code, const QString &state);
    void onBackendLoginFinished(const QByteArray &body, const QString &netError);
    void fetchCasdoorUserInfo(const QString &accessToken);
    void performLocalCleanup();
    void sendCasdoorLogoutRequest();
};

#endif // CASDOORHELPER_H
