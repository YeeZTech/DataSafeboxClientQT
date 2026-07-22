#ifndef FILETRANSFERBRIDGE_H
#define FILETRANSFERBRIDGE_H

#include <QObject>
#include <QString>

#include <memory>
#include <thread>

namespace dscc
{
namespace transfer
{
class FileTransfer;
} // namespace transfer
} // namespace dscc

// 把加密好的 .sealed 文件点对点发给命令行客户端。
//
// 换取一个 6 位取件码，用户把码告诉对端；对端 `dv transfer recv <码>` 取件后，
// 文件经 WebRTC DataChannel 直传，内容不经过服务器。信令服务只负责房间与
// SDP/ICE 中继。
//
// SDK 的 SendFile 是阻塞调用，因此整个过程跑在工作线程上，回调经队列连接投递
// 回主线程再发信号 —— QML 只会在 GUI 线程上收到这些信号。
class FileTransferBridge : public QObject
{
    Q_OBJECT

  public:
    explicit FileTransferBridge(QObject *parent = nullptr);
    ~FileTransferBridge() override;

    // 是否配置了信令服务。未配置时 QML 应隐藏传输入口。
    Q_INVOKABLE bool isAvailable() const;

    // 开始发送。已有传输在进行时直接以 transferFailed 拒绝，不排队。
    Q_INVOKABLE void sendFile(const QString &filePath);

    // 中止进行中的传输。未在传输时无副作用。
    Q_INVOKABLE void cancel();

    Q_INVOKABLE bool isBusy() const;

  signals:
    // 取件码就绪，界面应把它显著地展示给用户。
    void roomCodeReady(QString roomCode);
    // 阶段提示文案（"等待对方连接"/"正在传输"…），可直接展示。
    void stageChanged(QString stageText);
    void transferProgress(quint64 processedBytes, quint64 totalBytes);
    void transferSucceeded(QString filePath, quint64 totalBytes);
    void transferFailed(QString message);

  private:
    void joinWorker();

    std::unique_ptr<dscc::transfer::FileTransfer> m_transfer;
    std::thread m_worker;
    bool m_busy = false;
};

#endif // FILETRANSFERBRIDGE_H
