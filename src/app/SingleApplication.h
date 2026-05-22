#ifndef SINGLEAPPLICATION_H
#define SINGLEAPPLICATION_H

#include <QApplication>
#include <QLocalServer>
#include <QLocalSocket>

class SingleApplication : public QApplication
{
    Q_OBJECT
public:
    SingleApplication(int &argc, char **argv, const QString &serverName = QString());
    bool isRunning() const { return m_isRunning; }
    bool sendMessage(const QString &message);

signals:
    void messageReceived(const QString &message);

private slots:
    void newLocalConnection();

private:
    void initLocalConnection();

    bool m_isRunning;
    QLocalServer *m_localServer;
    QString m_serverName;
};

#endif // SINGLEAPPLICATION_H
