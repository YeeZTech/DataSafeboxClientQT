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
    bool isRunning() const
    {
        return m_isRunning;
    }
    bool sendMessage(const QString &message);
    // 关闭本地 server 并释放实例名，供"切换服务器环境后重启自身"使用：
    // 先释放再拉起新进程，新实例才不会被单实例检查当作重复实例。
    void releaseSingleInstance();

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
