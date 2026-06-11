#include "SingleApplication.h"
#include <QDebug>
#include <QFileInfo>

SingleApplication::SingleApplication(int &argc, char **argv, const QString &serverName)
    : QApplication(argc, argv), m_isRunning(false), m_localServer(nullptr)
{
    // Use a fixed name or based on app path hash to avoid issues
    if (serverName.isEmpty())
    {
        m_serverName = "datasafebox-qt-client-single-instance";
    }
    else
    {
        m_serverName = serverName;
    }
    initLocalConnection();
}

void SingleApplication::initLocalConnection()
{
    m_isRunning = false;
    QLocalSocket socket;
    socket.connectToServer(m_serverName);
    if (socket.waitForConnected(500))
    {
        m_isRunning = true; // Another instance is running
        return;
    }

    // No other instance, start server
    m_localServer = new QLocalServer(this);
    connect(m_localServer, &QLocalServer::newConnection, this, &SingleApplication::newLocalConnection);

    // Cleanup previous crash
    QLocalServer::removeServer(m_serverName);

    if (!m_localServer->listen(m_serverName))
    {
        if (m_localServer->serverError() == QAbstractSocket::AddressInUseError)
        {
            m_isRunning = true;
        }
    }
}

void SingleApplication::releaseSingleInstance()
{
    if (m_localServer)
    {
        m_localServer->close();
        QLocalServer::removeServer(m_serverName);
    }
}

bool SingleApplication::sendMessage(const QString &message)
{
    if (!m_isRunning)
        return false;
    QLocalSocket socket;
    socket.connectToServer(m_serverName);
    if (socket.waitForConnected(500))
    {
        socket.write(message.toUtf8());
        socket.waitForBytesWritten(1000);
        socket.disconnectFromServer();
        return true;
    }
    return false;
}

void SingleApplication::newLocalConnection()
{
    QLocalSocket *socket = m_localServer->nextPendingConnection();
    if (!socket)
        return;

    connect(socket, &QLocalSocket::readyRead, this, [this, socket]() {
        QByteArray data = socket->readAll();
        QString message = QString::fromUtf8(data);
        emit messageReceived(message);
        socket->deleteLater();
    });
}
