#include "FileTransferBridge.h"

#include <QDebug>
#include <QFileInfo>
#include <QMetaObject>

#include "AppConfig.h"
#include "dscc/transfer/file_transfer.h"

FileTransferBridge::FileTransferBridge(QObject *parent) : QObject(parent)
{
}

FileTransferBridge::~FileTransferBridge()
{
    cancel();
    joinWorker();
}

bool FileTransferBridge::isAvailable() const
{
    return !QString::fromLatin1(AppCfg::currentProfile().transferSignalUrl).trimmed().isEmpty();
}

bool FileTransferBridge::isBusy() const
{
    return m_busy;
}

void FileTransferBridge::joinWorker()
{
    if (m_worker.joinable())
    {
        m_worker.join();
    }
}

void FileTransferBridge::sendFile(const QString &filePath)
{
    if (m_busy)
    {
        emit transferFailed(tr("A file transfer is already in progress."));
        return;
    }

    const QString signalUrl = QString::fromLatin1(AppCfg::currentProfile().transferSignalUrl).trimmed();
    if (signalUrl.isEmpty())
    {
        emit transferFailed(tr("File transfer is not configured for this server."));
        return;
    }

    const QFileInfo info(filePath);
    if (!info.exists() || !info.isFile())
    {
        emit transferFailed(tr("File not found: %1").arg(filePath));
        return;
    }

    // 上一次传输的线程可能刚跑完还没回收，这里先 join 再起新的。
    joinWorker();

    dscc::transfer::Config config;
    config.signaling_url = signalUrl.toStdString();
    // 测试环境的信令服务常用自签名证书；正式环境一律走完整校验。
    config.tls_insecure = AppCfg::currentProfile().isTest;

    m_transfer = std::make_unique<dscc::transfer::FileTransfer>(config);
    m_busy = true;

    // 回调在 libdatachannel 的内部线程上触发，一律用队列连接投递回 GUI 线程，
    // 信号因此永远在主线程发出，QML 端不需要额外考虑线程。
    dscc::transfer::Callbacks callbacks;
    callbacks.on_room_code = [this](const std::string &code) {
        const QString roomCode = QString::fromStdString(code);
        QMetaObject::invokeMethod(
            this, [this, roomCode]() { emit roomCodeReady(roomCode); }, Qt::QueuedConnection);
    };
    callbacks.on_stage = [this](dscc::transfer::Stage stage) {
        const QString text = QString::fromUtf8(dscc::transfer::StageText(stage));
        QMetaObject::invokeMethod(
            this, [this, text]() { emit stageChanged(text); }, Qt::QueuedConnection);
    };
    callbacks.on_progress = [this](std::uint64_t processed, std::uint64_t total) {
        QMetaObject::invokeMethod(
            this,
            [this, processed, total]() {
                emit transferProgress(static_cast<quint64>(processed), static_cast<quint64>(total));
            },
            Qt::QueuedConnection);
    };

    const std::string localPath = filePath.toStdString();
    m_worker = std::thread([this, localPath, callbacks, filePath]() {
        const dscc::transfer::Result result = m_transfer->SendFile(localPath, callbacks);
        QMetaObject::invokeMethod(
            this,
            [this, result, filePath]() {
                m_busy = false;
                if (result.ok)
                {
                    emit transferSucceeded(filePath, static_cast<quint64>(result.bytes));
                }
                else
                {
                    emit transferFailed(QString::fromStdString(result.error));
                }
            },
            Qt::QueuedConnection);
    });
}

void FileTransferBridge::cancel()
{
    if (m_transfer)
    {
        // Cancel 是线程安全的：它唤醒工作线程里阻塞的 SendFile，后者随即以
        // 失败返回，走上面的收尾逻辑。
        m_transfer->Cancel();
    }
}
