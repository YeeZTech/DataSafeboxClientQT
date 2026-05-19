#include "CasdoorHelper.h"
#include <QUrl>
#include <QUrlQuery>
#include <QDateTime>
#include <QUuid>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static QVariantMap parseJwtClaims(const QString &token)
{
    const QStringList parts = token.split('.');
    if (parts.size() < 2) return {};
    const QByteArray payload = QByteArray::fromBase64(
        parts.at(1).toLatin1(),
        QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    const QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) return {};
    return doc.object().toVariantMap();
}

static QString friendlyError(const QString &raw)
{
    const QString lower = raw.trimmed().toLower();
    if (lower.contains("connection refused"))
        return "无法连接认证服务器，请检查网络后重试";
    if (lower.contains("host not found") || lower.contains("unable to resolve"))
        return "无法解析服务器地址，请检查网络连接";
    if (lower.contains("timed out") || lower.contains("timeout"))
        return "连接超时，请检查网络后重试";
    if (lower.contains("ssl") || lower.contains("certificate"))
        return "SSL 安全验证失败，请检查网络环境";
    if (raw.trimmed().isEmpty())
        return "网络错误，请检查网络后重试";
    return raw.trimmed();
}

// ---------------------------------------------------------------------------
// CasdoorHelper
// ---------------------------------------------------------------------------

CasdoorHelper* CasdoorHelper::instance()
{
    static CasdoorHelper* inst = new CasdoorHelper();
    return inst;
}

CasdoorHelper::CasdoorHelper(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    m_loginWatchdog.setSingleShot(true);
    connect(&m_loginWatchdog, &QTimer::timeout,
            this, &CasdoorHelper::onLoginWatchdogTimeout);
}

void CasdoorHelper::clearAuthExchangeState()
{
    m_loginWatchdog.stop();
    m_authCodeExchangeInFlight = false;
    m_inFlightAuthCode.clear();
}

QString CasdoorHelper::getSigninUrl()
{
    QUrl url(endpoint + "/login/oauth/authorize");
    QUrlQuery query;
    m_oauthState = QString::number(QDateTime::currentMSecsSinceEpoch())
            + "-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    query.addQueryItem("client_id", clientId);
    query.addQueryItem("response_type", "code");
    query.addQueryItem("redirect_uri", redirectUri);
    query.addQueryItem("scope", "read");
    query.addQueryItem("state", m_oauthState);
    url.setQuery(query);
    return url.toString();
}

void CasdoorHelper::handleAuthCode(const QString &code, const QString &state)
{
    const QString normalizedCode = code.trimmed();
    if (normalizedCode.isEmpty()) {
        emit loginFailed("授权码为空");
        return;
    }
    if (m_authCodeExchangeInFlight && normalizedCode == m_inFlightAuthCode) {
        return;
    }
    if (m_oauthState.isEmpty()) {
        emit loginFailed("登录状态异常，请重试");
        return;
    }
    const QString callbackState = state.trimmed();
    if (callbackState.isEmpty() || callbackState != m_oauthState) {
        m_oauthState.clear();
        emit loginFailed("登录状态校验失败，请重试");
        return;
    }
    const QString requestState = m_oauthState;
    m_oauthState.clear();

    m_authCodeExchangeInFlight = true;
    m_inFlightAuthCode = normalizedCode;
    m_loginWatchdog.start(30000);

    callBackendLogin(normalizedCode, requestState);
}

void CasdoorHelper::callBackendLogin(const QString &code, const QString &state)
{
    QJsonObject jsonBody;
    jsonBody["code"]         = code;
    jsonBody["redirectUri"]  = redirectUri;
    jsonBody["redirect_uri"] = redirectUri;
    if (!state.isEmpty())
        jsonBody["state"] = state;

    const QByteArray data = QJsonDocument(jsonBody).toJson(QJsonDocument::Compact);

    QUrl url(QLatin1String(AppCfg::API_BASE_URL) + "/api/user/login/callback");
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(15000);

    QNetworkReply *reply = m_network->post(req, data);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            if (!m_authCodeExchangeInFlight) return;
            clearAuthExchangeState();
            m_currentToken.clear();
            m_currentIdToken.clear();
            emit loginFailed(friendlyError(reply->errorString()));
            return;
        }
        onBackendLoginFinished(reply->readAll(), QString());
    });
}

void CasdoorHelper::onBackendLoginFinished(const QByteArray &body, const QString &netError)
{
    if (!m_authCodeExchangeInFlight) return;

    auto fail = [this](const QString &msg) {
        clearAuthExchangeState();
        m_currentToken.clear();
        m_currentIdToken.clear();
        emit loginFailed(msg);
    };

    if (!netError.isEmpty()) { fail(friendlyError(netError)); return; }

    QJsonParseError jsonErr{};
    const QJsonDocument doc = QJsonDocument::fromJson(body, &jsonErr);
    if (jsonErr.error != QJsonParseError::NoError || !doc.isObject()) {
        fail("服务器响应异常，请重试");
        return;
    }

    const QVariantMap result = doc.object().toVariantMap();
    const int resultCode = result.value("resultCode", -1).toInt();
    if (resultCode != 200) {
        const QString msg = result.value("resultDesc",
                            result.value("msg",
                            result.value("error", "登录失败"))).toString();
        fail(msg.isEmpty() ? "登录失败" : msg);
        return;
    }

    const QVariantMap data = result.value("data").toMap();
    m_currentToken   = data.value("token").toString();
    if (m_currentToken.isEmpty()) m_currentToken = data.value("accessToken").toString();
    if (m_currentToken.isEmpty()) m_currentToken = data.value("access_token").toString();
    m_currentIdToken = data.value("idToken").toString();
    if (m_currentIdToken.isEmpty()) m_currentIdToken = data.value("id_token").toString();

    if (m_currentToken.isEmpty()) { fail("服务器响应异常，请重试"); return; }

    // Parse JWT claims — no extra network call if all fields present
    const QVariantMap jwt = parseJwtClaims(m_currentToken);

    QString userName = jwt.value("name").toString();
    if (userName.isEmpty()) {
        QString sub = jwt.value("sub").toString();
        if (sub.contains('/')) sub = sub.section('/', 1);
        userName = sub;
    }
    QString authUserId = jwt.value("id").toString();
    if (authUserId.isEmpty()) {
        authUserId = jwt.value("sub").toString();
        if (authUserId.contains('/')) authUserId = authUserId.section('/', 1);
    }
    const QString owner = jwt.value("owner").toString();

    if (!userName.isEmpty() && !authUserId.isEmpty() && !owner.isEmpty()) {
        m_sessionToken = m_currentToken;
        m_sessionOwner = owner;

        QVariantMap user;
        user["token"]        = m_currentToken;
        user["idToken"]      = m_currentIdToken;
        user["userName"]     = userName;
        user["authUserId"]   = authUserId;
        user["displayName"]  = jwt.value("displayName").toString();
        user["avatar"]       = jwt.value("avatar").toString();
        user["phone"]        = jwt.value("phone").toString();
        user["email"]        = jwt.value("email").toString();

        m_currentToken.clear();
        m_currentIdToken.clear();
        clearAuthExchangeState();
        emit loginSuccess(user);
        return;
    }

    // JWT incomplete — fall back to Casdoor /api/get-account
    fetchCasdoorUserInfo(m_currentToken);
}

void CasdoorHelper::fetchCasdoorUserInfo(const QString &accessToken)
{
    QUrl url(endpoint + "/api/get-account");
    QUrlQuery query;
    query.addQueryItem("access_token", accessToken);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("Authorization", ("Bearer " + accessToken).toUtf8());
    req.setTransferTimeout(10000);

    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (!m_authCodeExchangeInFlight) return;

        auto fail = [this](const QString &msg) {
            clearAuthExchangeState();
            m_currentToken.clear();
            m_currentIdToken.clear();
            emit loginFailed(msg);
        };

        if (reply->error() != QNetworkReply::NoError) {
            fail(friendlyError(reply->errorString()));
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) { fail("获取用户信息失败"); return; }

        const QJsonObject root = doc.object();
        if (root.value("status").toString().toLower() != "ok") {
            const QString msg = root.value("msg").toString();
            fail(msg.isEmpty() ? "获取用户信息失败" : msg);
            return;
        }
        if (!root.value("data").isObject()) { fail("获取用户信息失败"); return; }

        const QJsonObject dataObj = root.value("data").toObject();
        const QString name      = dataObj.value("name").toString();
        const QString userId    = dataObj.value("id").toString();
        const QString owner     = dataObj.value("owner").toString();
        if (name.isEmpty() || userId.isEmpty() || owner.isEmpty()) {
            fail("获取用户信息失败：缺少必要字段");
            return;
        }

        m_sessionToken = m_currentToken;
        m_sessionOwner = owner;

        QVariantMap user;
        user["token"]        = m_currentToken;
        user["idToken"]      = m_currentIdToken;
        user["userName"]     = name;
        user["authUserId"]   = userId;
        user["displayName"]  = dataObj.value("displayName").toString();
        user["avatar"]       = dataObj.value("avatar").toString();
        user["phone"]        = dataObj.value("phone").toString();
        user["email"]        = dataObj.value("email").toString();

        m_currentToken.clear();
        m_currentIdToken.clear();
        clearAuthExchangeState();
        emit loginSuccess(user);
    });
}

void CasdoorHelper::onLoginWatchdogTimeout()
{
    if (!m_authCodeExchangeInFlight) return;
    clearAuthExchangeState();
    m_currentToken.clear();
    m_currentIdToken.clear();
    emit loginFailed("登录超时，请重试");
}

void CasdoorHelper::searchUser(const QString &username)
{
    if (username.isEmpty()) { emit userSearchFailed("用户名不能为空"); return; }

    if (m_sessionToken.isEmpty() || m_sessionOwner.isEmpty()) {
        emit userSearchFailed("未登录，无法查询用户");
        return;
    }

    QUrl url(endpoint + "/api/get-user");
    QUrlQuery query;
    query.addQueryItem("id", m_sessionOwner + "/" + username);
    query.addQueryItem("access_token", m_sessionToken);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("Authorization", ("Bearer " + m_sessionToken).toUtf8());

    QNetworkReply *reply = m_network->get(req);
    const QString requestedUsername = username;
    connect(reply, &QNetworkReply::finished, this, [this, reply, requestedUsername]() {
        reply->deleteLater();
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError networkError = reply->error();
        const QString networkErrorText = reply->errorString();
        const QByteArray body = reply->readAll();

        qInfo().noquote()
            << QStringLiteral("[CasdoorHelper] /api/get-user response username=\"%1\" httpStatus=%2 networkError=%3 networkErrorText=\"%4\" body=")
                   .arg(requestedUsername,
                        QString::number(httpStatus),
                        QString::number(static_cast<int>(networkError)),
                        networkErrorText)
            << QString::fromUtf8(body);

        if (networkError != QNetworkReply::NoError) {
            if (httpStatus == 404) {
                emit userSearchFailed("查询用户不存在");
            } else {
                emit userSearchFailed(friendlyError(networkErrorText));
            }
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        if (!doc.isObject()) { emit userSearchFailed("解析用户信息失败"); return; }
        const QJsonObject root = doc.object();
        if (root.value("status").toString().toLower() != "ok") {
            emit userSearchFailed("查询用户不存在");
            return;
        }
        const QJsonObject dataObj = root.value("data").toObject();
        const QString userId = dataObj.value("id").toString().trimmed();
        const QString userName = dataObj.value("name").toString().trimmed();
        const QString account = dataObj.value("displayName").toString().trimmed();
        if (dataObj.isEmpty() || userId.isEmpty() || userName.isEmpty() || account.isEmpty()) {
            emit userSearchFailed("查询结果缺少必填字段，请联系管理员");
            return;
        }
        QVariantMap userInfo;
        userInfo["user_id"]      = userId;
        userInfo["user_name"]    = userName;
        userInfo["account"]      = account;
        userInfo["authUserId"]   = userId;
        userInfo["authUserName"] = userName;
        userInfo["displayName"]  = account;
        emit userSearchCompleted(userInfo);
    });
}

void CasdoorHelper::clearCasdoorCookies()
{
    // offTheRecord profile — cookies are in-memory only.
}

void CasdoorHelper::logout()
{
    // Fully reset internal state so the next login starts from a clean slate.
    clearAuthExchangeState();
    m_oauthState.clear();
    m_currentToken.clear();
    m_currentIdToken.clear();
    m_sessionToken.clear();
    m_sessionOwner.clear();
    emit logoutCompleted();
}
