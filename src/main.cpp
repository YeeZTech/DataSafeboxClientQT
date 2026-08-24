#include "AppConfig.h"
#include "ArrearsManager.h"
#include "CasdoorHelper.h"
#include "DsccBridge.h"
#include "FileTransferBridge.h"
#include "LanguageManager.h"
#include "PathManager.h"
#include "SentryBridge.h"
#include "SingleApplication.h"
#include "UpdateManager.h"
#include "dscc/core/net/http/service_endpoints.h"
#include "sentry.h"
#include <QApplication>
#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QLoggingCategory>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QtQml>
#include <QtWebView>

// Sentry library is linked via the .pro (LIBS += -lsentry).
// The previous `#pragma comment(lib, "sentry.lib")` was MSVC-only and is removed for cross-platform builds.

static QtMessageHandler g_previousMessageHandler = nullptr;
static QFile *g_logFile = nullptr;
static QTextStream *g_logStream = nullptr;

static QString startupLocalRootPath()
{
    const QString base = AppCfg::localDataBaseDir();
    if (base.isEmpty())
    {
        return base;
    }
    return QDir(base).filePath(AppCfg::environmentDirName());
}

static QString startupCacheRootPath(const QString &startupRootDir)
{
    const QString defaultCacheDir = QDir(startupRootDir).filePath(QStringLiteral("cache"));
    if (startupRootDir.isEmpty())
    {
        return defaultCacheDir;
    }

    QSettings settings(QDir(startupRootDir).filePath("settings.ini"), QSettings::IniFormat);
    const QString configuredCacheDir = settings.value("paths/cacheDir").toString().trimmed();
    if (configuredCacheDir.isEmpty())
    {
        return defaultCacheDir;
    }
    return QDir::cleanPath(configuredCacheDir);
}

static void cleanupLegacyRoamingArtifacts(const QString &managedRootDir)
{
    const QString roamingAppDataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (roamingAppDataDir.isEmpty())
    {
        return;
    }

    const QString normalizedRoaming = QDir::cleanPath(roamingAppDataDir);
    const QString normalizedManaged = QDir::cleanPath(managedRootDir);
    if (normalizedRoaming == normalizedManaged)
    {
        return;
    }

    static const QStringList legacyNames = {QStringLiteral("QML"), QStringLiteral("QtWebEngine")};

    for (const QString &name : legacyNames)
    {
        QDir legacyDir(QDir(normalizedRoaming).filePath(name));
        if (legacyDir.exists())
        {
            legacyDir.removeRecursively();
        }
    }
}

static QString logFilePath(const QString &cacheDir)
{
    QString baseDir = cacheDir;

    QDir dir(baseDir);
    if (!dir.exists())
    {
        dir.mkpath(".");
    }
    dir.mkpath("logs");

    return dir.filePath("logs/datasafebox-client.log");
}

static QString logLevelToString(QtMsgType type)
{
    switch (type)
    {
    case QtDebugMsg:
        return "DEBUG";
    case QtInfoMsg:
        return "INFO";
    case QtWarningMsg:
        return "WARN";
    case QtCriticalMsg:
        return "ERROR";
    case QtFatalMsg:
        return "FATAL";
    }
    return "LOG";
}

static void sentryMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    // Suppress noisy Qt internal clipboard retry warning (Windows clipboard contention)
    if (type == QtWarningMsg && msg.contains("Retrying to obtain clipboard"))
    {
        return;
    }

    QString location;
    if (context.file && *context.file)
    {
        location += context.file;
        if (context.line > 0)
        {
            location += ":";
            location += QString::number(context.line);
        }
    }
    if (context.function && *context.function)
    {
        if (!location.isEmpty())
            location += " ";
        location += context.function;
    }
    if (location.isEmpty() && context.category && *context.category)
    {
        location = context.category;
    }

    if (g_logStream && g_logFile && g_logFile->isOpen())
    {
        (*g_logStream) << QDateTime::currentDateTime().toString(Qt::ISODate) << " [" << logLevelToString(type) << "] "
                       << (location.isEmpty() ? QString() : location + " ") << msg << '\n';
        g_logStream->flush();
    }

    // "dscc" category messages are already reported to Sentry explicitly (with structured
    // tags/extra) by DsccBridge::logNotification, so skip them here to avoid double-reporting.
    const bool isDsccCategory = context.category && qstrcmp(context.category, "dscc") == 0;

    if (!isDsccCategory)
    {
        const QVariantMap data =
            location.isEmpty() ? QVariantMap() : QVariantMap{{QStringLiteral("location"), location}};

        if (type == QtCriticalMsg || type == QtFatalMsg)
        {
            // Real error / crash precursor: still its own Issue, now with structured extra.
            SentryBridge::captureError(context.category ? QString::fromUtf8(context.category) : QStringLiteral("qt"),
                                       msg, {}, data);
            // Flush immediately for critical/fatal so events are sent even if the app crashes
            sentry_flush(5000);
        }
        else
        {
            // Routine Qt logging: breadcrumb only, so it stops flooding the Issues list and
            // instead shows up as pre-crash context on the next real error/crash event.
            const char *level = type == QtWarningMsg ? "warning" : (type == QtDebugMsg ? "debug" : "info");
            SentryBridge::addBreadcrumb(QStringLiteral("qt"), QString::fromUtf8(level), msg, data);
        }
    }

    if (g_previousMessageHandler)
    {
        g_previousMessageHandler(type, context, msg);
    }
    else
    {
        QMessageLogger(context.file, context.line, context.function, context.category).debug() << msg;
    }
}

// 自动选择渲染模式（必须在创建 QApplication 之前调用）。
static void autoSelectRenderMode()
{
#ifdef Q_OS_WIN
    // 检测虚拟机驱动（读 HKLM 服务键，存在即说明运行在对应虚拟化平台上）
    static const char *const vmServiceKeys[] = {
        "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\vmhgfs",     // VMware
        "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\VBoxGuest",  // VirtualBox
        "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\xenvif",     // Xen / AWS
        "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\hypervideo", // Hyper-V
        nullptr};
    for (int i = 0; vmServiceKeys[i]; ++i)
    {
        QSettings svc(QLatin1String(vmServiceKeys[i]), QSettings::NativeFormat);
        if (!svc.allKeys().isEmpty())
        {
            qputenv("QT_OPENGL", "software");
            return;
        }
    }
#endif
}

static void registerCustomProtocol()
{
#if defined(Q_OS_WIN)
    QString appPath = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
    QSettings settings("HKEY_CURRENT_USER\\Software\\Classes", QSettings::NativeFormat);

    // Check if "dianshu" key exists and points to this app
    settings.beginGroup("dianshu");
    QString currentCmd = settings.value("shell/open/command/.").toString();

    // If not registered or pointing to wrong path, update it
    if (currentCmd.isEmpty() || !currentCmd.contains(appPath))
    {
        settings.setValue(".", "URL:Dianshu Protocol");
        settings.setValue("URL Protocol", "");

        settings.beginGroup("DefaultIcon");
        settings.setValue(".", "\"" + appPath + "\",1");
        settings.endGroup();

        settings.beginGroup("shell");
        settings.beginGroup("open");
        settings.beginGroup("command");
        settings.setValue(".", "\"" + appPath + "\" \"%1\"");
        settings.endGroup();
        settings.endGroup();
        settings.endGroup();
    }
    settings.endGroup();
#elif defined(Q_OS_MAC)
    // macOS: URL scheme registration is declared statically in Info.plist
    // (CFBundleURLTypes / CFBundleURLSchemes = "dianshu"). No runtime work needed.
#elif defined(Q_OS_LINUX)
    // Linux: register an XDG handler that maps the dianshu:// URL scheme to this binary.
    // We always (re)write the .desktop file so it tracks the current install location.
    const QString appPath = QCoreApplication::applicationFilePath();
    const QString desktopDir =
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/applications");
    QDir().mkpath(desktopDir);
    const QString desktopFile = desktopDir + QStringLiteral("/dianshu-url-handler.desktop");
    QFile f(desktopFile);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text))
    {
        QTextStream s(&f);
        s.setEncoding(QStringConverter::Utf8);
        s << "[Desktop Entry]\n"
          << "Type=Application\n"
          << "Name=DatasafeBox URL Handler\n"
          << "Exec=" << appPath << " %u\n"
          << "Icon=datasafebox-client\n"
          << "Terminal=false\n"
          << "NoDisplay=true\n"
          << "MimeType=x-scheme-handler/dianshu;\n";
        f.close();
        QProcess::execute(QStringLiteral("update-desktop-database"), {desktopDir});
        QProcess::execute(QStringLiteral("xdg-mime"),
                          {QStringLiteral("default"), QStringLiteral("dianshu-url-handler.desktop"),
                           QStringLiteral("x-scheme-handler/dianshu")});
    }
#endif
}

int main(int argc, char *argv[])
{
    // Set application properties VERY early for path consistency
    QCoreApplication::setApplicationName(QStringLiteral("datasafebox-client"));
    QCoreApplication::setOrganizationName(QStringLiteral("yeeztech"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("yeez.tech"));

    // Compute a stable local root path before runtime initialization.
    const QString startupRootDir = startupLocalRootPath();
    const QString startupCacheDir = startupCacheRootPath(startupRootDir);
    if (!startupRootDir.isEmpty())
    {
        QDir().mkpath(startupRootDir);
        QDir().mkpath(startupCacheDir);

        const QString qmlDiskCachePath = QDir(startupCacheDir).filePath("qml/disk-cache");
        QDir().mkpath(qmlDiskCachePath);

        // Force QML runtime files under local cache root, avoid Roaming writes.
        qputenv("QML_DISK_CACHE_PATH", qmlDiskCachePath.toUtf8());
        qputenv("QML_CACHE_PATH", qmlDiskCachePath.toUtf8());
    }

    // Auto-select render mode (software vs hardware) before any Qt windowing init
    autoSelectRenderMode();

#if defined(Q_OS_WIN)
    // Force the WebView2-backed plugin (no Qt WebEngine shipped/linked) instead of
    // relying on QtWebView's own plugin-probing order. Windows-only: "webview2" is
    // not a valid plugin name on other platforms.
    qputenv("QT_WEBVIEW_PLUGIN", "webview2");
#elif defined(Q_OS_MACOS)
    // Same reason, opposite default: QtWebView picks its backend by plugin key and
    // qwebviewfactory.cpp hardcodes "webengine" as that default on macOS ("native"
    // on every other platform). Since the WebEngine migration nothing ships Qt
    // WebEngine, so the factory finds no plugin, warns "No WebView plug-in found!"
    // and installs a QNullWebView — a WebView that never loads, never emits load
    // signals, and therefore leaves the login page invisible with no error shown.
    // "native" is the key of the WKWebView-backed darwin plugin.
    qputenv("QT_WEBVIEW_PLUGIN", "native");
#endif

    // Initialize QtWebView BEFORE creating QApplication
    QtWebView::initialize();

    QQuickStyle::setStyle("Basic");

    // Replace QGuiApplication with SingleApplication
    SingleApplication app(argc, argv, "datasafebox-qt-client-single-instance");

    // Check if another instance is running
    if (app.isRunning())
    {
        QStringList args = QCoreApplication::arguments();
        QString message;
        // Look for custom protocol argument
        for (const QString &arg : args)
        {
            if (arg.startsWith("dianshu://"))
            {
                message = arg;
                break;
            }
        }

        if (!message.isEmpty())
        {
            app.sendMessage(message);
        }
        else
        {
            // Just bring to front (if supported, but we just send empty message to wake up)
            app.sendMessage("wakeup");
        }
        return 0;
    }

    PathManager *pathManager = new PathManager(&app);
    const QString appRootDir = pathManager->rootDir();
    cleanupLegacyRoamingArtifacts(appRootDir);

    // Set global QSettings default path to avoid creating files in AppData\Roaming
    // This ensures all QSettings instances use the same directory as PathManager
    QSettings::setDefaultFormat(QSettings::IniFormat);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, appRootDir);

    const QString casdoorRootDir = QDir(appRootDir).filePath("casdoor");
    QDir().mkpath(casdoorRootDir);

    // Remove any leftover Casdoor storage from older (QtWebEngine-based) installs
    // so a clean slate on every launch. This prevents the Casdoor login page from
    // showing "使用以下账号继续".
    {
        QDir casdoorStorage(QDir(casdoorRootDir).filePath("storage"));
        if (casdoorStorage.exists())
        {
            casdoorStorage.removeRecursively();
        }
        QDir casdoorHttpCache(QDir(casdoorRootDir).filePath("http-cache"));
        if (casdoorHttpCache.exists())
        {
            casdoorHttpCache.removeRecursively();
        }
    }

    qputenv("APP_ROOT_DIR", appRootDir.toUtf8());
    qputenv("APP_CACHE_DIR", pathManager->cacheDir().toUtf8());
    qputenv("CASDOOR_WORK_DIR", casdoorRootDir.toUtf8());

    auto applyRuntimeCachePaths = [pathManager](UpdateManager *manager) {
        const QString cacheRoot = pathManager->cacheDir();
        qputenv("APP_CACHE_DIR", cacheRoot.toUtf8());
        qputenv("QML_DISK_CACHE_PATH", QDir(cacheRoot).filePath("qml/disk-cache").toUtf8());
        qputenv("QML_CACHE_PATH", QDir(cacheRoot).filePath("qml/disk-cache").toUtf8());

        if (manager)
        {
            manager->setCacheDirectory(cacheRoot);
        }
    };

    QString logPath = logFilePath(pathManager->cacheDir());
    g_logFile = new QFile(logPath);
    if (g_logFile->open(QIODevice::Append | QIODevice::Text))
    {
        g_logStream = new QTextStream(g_logFile);
        (*g_logStream) << "==============================" << '\n';
        (*g_logStream) << QDateTime::currentDateTime().toString(Qt::ISODate) << " [INFO] Application started" << '\n';
        g_logStream->flush();
    }
    else
    {
    }

#ifdef APP_VERSION
    const QString appVersion = QStringLiteral(APP_VERSION);
#else
    const QString appVersion = QStringLiteral("unknown");
#endif

    // Install message handler (for file logging and Sentry capture)
    {
        // crashpad_handler binary is shipped alongside the executable.
        // Extension differs per platform (.exe on Windows, no extension on macOS/Linux).
        QString handlerPath = QCoreApplication::applicationDirPath() + QStringLiteral("/crashpad_handler")
#ifdef Q_OS_WIN
                              + QStringLiteral(".exe")
#endif
            ;
        sentry_options_t *options = sentry_options_new();
        sentry_options_set_dsn(options, AppCfg::SENTRY_DSN);
        sentry_options_set_release(options, qPrintable(QStringLiteral("datasafebox-client@") + appVersion));
        sentry_options_set_environment(options, AppCfg::currentProfile().isTest ? "test" : "production");
        // Structured Logs: a separate, always-on stream (shown in Sentry's Logs explorer and
        // trace-correlated on event detail pages) independent of breadcrumbs/Issues.
        sentry_options_set_enable_logs(options, 1);
#ifdef QT_DEBUG
        sentry_options_set_debug(options, 1);
#endif
        QString dbPath = QDir(pathManager->featureCacheDir("sentry")).filePath("db");
        QDir dbDir(dbPath);
        if (!dbDir.exists())
            dbDir.mkpath(".");
        sentry_options_set_database_path(options, dbPath.toStdString().c_str());
        sentry_options_set_handler_path(options, handlerPath.toStdString().c_str());
        qInfo() << "[Config] Sentry DSN:" << QString(AppCfg::SENTRY_DSN).left(40) + "...";
        if (!QFile::exists(handlerPath))
        {
            qWarning() << "[Config] Sentry crashpad_handler not found at:" << handlerPath
                       << "- Sentry crash reporting disabled";
            sentry_options_free(options);
        }
        else
        {
            int sentryInitResult = sentry_init(options);
            if (sentryInitResult == 0)
            {
                qInfo() << "[Config] Sentry initialized successfully";
                // sentry-native only auto-populates "os"/"trace"; fill in the rest by hand so
                // crash reports carry the same app/device/locale context dianshu's events do.
                SentryBridge::installStartupContexts(appVersion);
            }
            else
            {
                qWarning() << "[Config] Sentry initialization failed, code:" << sentryInitResult;
            }
        }
    }
    g_previousMessageHandler = qInstallMessageHandler(sentryMessageHandler);
    qInfo() << "[Startup] datasafebox-qt-client starting, version:" << appVersion << "build:" << __DATE__ << __TIME__;

    // Periodically flush queued Sentry events (e.g. warnings) every 30 seconds, refreshing
    // the memory figures first so a later crash report reflects the current footprint.
    QTimer *sentryFlushTimer = new QTimer(&app);
    sentryFlushTimer->setInterval(30000);
    QObject::connect(sentryFlushTimer, &QTimer::timeout, []() {
        SentryBridge::refreshRuntimeContext();
        sentry_flush(3000);
    });
    sentryFlushTimer->start();

#ifdef Q_OS_MACOS
    // Keep the Dock icon from the bundle .icns; the SVG is full-bleed and makes the running app icon look oversized.
#else
    app.setWindowIcon(QIcon(":/icons/SafeLogo.svg"));
#endif

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("PathManager", pathManager);

    // Register CasdoorHelper
    CasdoorHelper *casdoorHelper = CasdoorHelper::instance();
    engine.rootContext()->setContextProperty("CasdoorHelper", casdoorHelper);

    // Register UpdateManager
    UpdateManager *updateManager = new UpdateManager(&app);
    applyRuntimeCachePaths(updateManager);
    QObject::connect(pathManager, &PathManager::cacheDirChanged, &app,
                     [applyRuntimeCachePaths, updateManager]() mutable { applyRuntimeCachePaths(updateManager); });
    engine.rootContext()->setContextProperty("UpdateManager", updateManager);

    // Register SentryBridge (allows QML to call SentryBridge.captureMessage())
    SentryBridge *sentryBridge = new SentryBridge(&app);
    engine.rootContext()->setContextProperty("SentryBridge", sentryBridge);

    // Register AppConfig (runtime server profile — selected on the login page)
    AppConfig *appConfig = new AppConfig(&app);
    engine.rootContext()->setContextProperty("AppConfig", appConfig);
    // 切换服务器环境：选择已持久化，先释放单实例锁再拉起新进程，避免新实例
    // 被单实例检查拒之门外（新旧实例的数据目录分属两个环境，互不冲突）。
    QObject::connect(
        appConfig, &AppConfig::restartRequested, &app,
        [&app]() {
            SentryBridge::addBreadcrumb(QStringLiteral("app"), QStringLiteral("info"),
                                        QStringLiteral("environment switch requested"));
            app.releaseSingleInstance();
            // --server-switched：告知新实例本次启动源于切换服务器，登录页不再重复弹"选择服务器"
            QProcess::startDetached(QCoreApplication::applicationFilePath(), {QStringLiteral("--server-switched")});
            QCoreApplication::quit();
        },
        Qt::QueuedConnection);

    // Register LanguageManager — must be done before DsccBridge so that
    // Notification::SetTranslator is installed before any notifications are created.
    LanguageManager *languageManager = new LanguageManager(&app);
    languageManager->applyInitialLanguage();
    engine.rootContext()->setContextProperty("LanguageManager", languageManager);
    // 运行时切换语言：重新求值所有含 qsTr() 的 QML 绑定，界面无需重启即可刷新。
    QObject::connect(languageManager, &LanguageManager::languageChanged, &engine,
                     [&engine]() { engine.retranslate(); });
    SentryBridge::setTag(QStringLiteral("language"), languageManager->currentLanguage());
    QObject::connect(languageManager, &LanguageManager::languageChanged, [](const QString &languageCode) {
        SentryBridge::setTag(QStringLiteral("language"), languageCode);
    });

    // Register DsccBridge (business logic dynamic library)
    // 向 DSCC 注入当前环境的服务地址（SSO 用户查询 + OpenBao KMS），必须在任何
    // DSCC 网络操作之前完成。
    dscc::SetServiceEndpoints(QLatin1String(AppCfg::currentProfile().casdoorEndpoint),
                              QLatin1String(AppCfg::currentProfile().openbaoServiceUrl));
    const QString dsccDbPath = pathManager->featureDataDir("dscc");
    QDir().mkpath(dsccDbPath);
    DsccBridge *dsccBridge = new DsccBridge(QDir(dsccDbPath).filePath("meta.db"), dsccDbPath,
                                            QString::fromLatin1(AppCfg::currentProfile().apiBaseUrl), QString(), &app);
    dsccBridge->initialize();
    engine.rootContext()->setContextProperty("DsccBridge", static_cast<QObject *>(dsccBridge));

    // Register FileTransferBridge (加密文件点对点发送给命令行客户端)
    FileTransferBridge *fileTransferBridge = new FileTransferBridge(&app);
    engine.rootContext()->setContextProperty("FileTransferBridge", static_cast<QObject *>(fileTransferBridge));

    // Register ArrearsManager (account arrears/paused status)
    ArrearsManager *arrearsManager = new ArrearsManager(&app);
    engine.rootContext()->setContextProperty("ArrearsManager", arrearsManager);

    // Wire Sentry user identity + business breadcrumbs. Login/logout set the real Sentry
    // user (replacing the random install id sentry-native uses by default); file-crypto and
    // update-check milestones become breadcrumbs so a later crash/error carries context.
    QObject::connect(casdoorHelper, &CasdoorHelper::loginSuccess, [](const QVariantMap &user) {
        SentryBridge::setUser(user.value(QStringLiteral("authUserId")).toString(),
                              user.value(QStringLiteral("userName")).toString(),
                              user.value(QStringLiteral("email")).toString());
        SentryBridge::addBreadcrumb(QStringLiteral("auth"), QStringLiteral("info"), QStringLiteral("login succeeded"));
    });
    QObject::connect(casdoorHelper, &CasdoorHelper::loginFailed, [](const QString &errorMessage) {
        SentryBridge::addBreadcrumb(QStringLiteral("auth"), QStringLiteral("error"),
                                    QStringLiteral("login failed: %1").arg(errorMessage));
    });
    QObject::connect(casdoorHelper, &CasdoorHelper::logoutCompleted, []() {
        SentryBridge::addBreadcrumb(QStringLiteral("auth"), QStringLiteral("info"), QStringLiteral("logout completed"));
        SentryBridge::clearUser();
    });
    QObject::connect(casdoorHelper, &CasdoorHelper::logoutFailed, [](const QString &errorMessage) {
        SentryBridge::addBreadcrumb(QStringLiteral("auth"), QStringLiteral("warning"),
                                    QStringLiteral("logout failed: %1").arg(errorMessage));
    });

    QObject::connect(dsccBridge, &DsccBridge::encryptFileStarted,
                     [](uint32_t operationId, const QString &sourceFile, const QString &targetFile) {
                         SentryBridge::addBreadcrumb(QStringLiteral("dscc.crypto"), QStringLiteral("info"),
                                                     QStringLiteral("encryptFile started"),
                                                     {{QStringLiteral("operation_id"), operationId},
                                                      {QStringLiteral("source_file"), sourceFile},
                                                      {QStringLiteral("target_file"), targetFile}});
                     });
    QObject::connect(dsccBridge, &DsccBridge::encryptFileSucceeded,
                     [](uint32_t operationId, const QString &sourceFile, const QString &targetFile) {
                         SentryBridge::addBreadcrumb(QStringLiteral("dscc.crypto"), QStringLiteral("info"),
                                                     QStringLiteral("encryptFile succeeded"),
                                                     {{QStringLiteral("operation_id"), operationId},
                                                      {QStringLiteral("source_file"), sourceFile},
                                                      {QStringLiteral("target_file"), targetFile}});
                     });
    QObject::connect(dsccBridge, &DsccBridge::encryptFileFailed,
                     [](uint32_t operationId, const QString &sourceFile, const QString &targetFile,
                        const dscc::Notification &notification) {
                         Q_UNUSED(notification);
                         SentryBridge::addBreadcrumb(QStringLiteral("dscc.crypto"), QStringLiteral("error"),
                                                     QStringLiteral("encryptFile failed"),
                                                     {{QStringLiteral("operation_id"), operationId},
                                                      {QStringLiteral("source_file"), sourceFile},
                                                      {QStringLiteral("target_file"), targetFile}});
                     });
    QObject::connect(dsccBridge, &DsccBridge::encryptFileCanceled,
                     [](uint32_t operationId, const QString &sourceFile, const QString &targetFile) {
                         SentryBridge::addBreadcrumb(QStringLiteral("dscc.crypto"), QStringLiteral("info"),
                                                     QStringLiteral("encryptFile canceled"),
                                                     {{QStringLiteral("operation_id"), operationId},
                                                      {QStringLiteral("source_file"), sourceFile},
                                                      {QStringLiteral("target_file"), targetFile}});
                     });

    QObject::connect(
        updateManager, &UpdateManager::updateAvailable, [](const QString &version, const QString &desc, bool force) {
            Q_UNUSED(desc);
            SentryBridge::addBreadcrumb(QStringLiteral("update"), QStringLiteral("info"),
                                        QStringLiteral("update available"),
                                        {{QStringLiteral("version"), version}, {QStringLiteral("force"), force}});
        });
    QObject::connect(updateManager, &UpdateManager::checkUpdateFailed, [](const QString &message) {
        SentryBridge::addBreadcrumb(QStringLiteral("update"), QStringLiteral("warning"),
                                    QStringLiteral("check update failed: %1").arg(message));
    });
    QObject::connect(updateManager, &UpdateManager::downloadFinished, []() {
        SentryBridge::addBreadcrumb(QStringLiteral("update"), QStringLiteral("info"),
                                    QStringLiteral("update download finished"));
    });
    QObject::connect(updateManager, &UpdateManager::downloadFailed, [](const QString &message) {
        SentryBridge::addBreadcrumb(QStringLiteral("update"), QStringLiteral("warning"),
                                    QStringLiteral("update download failed: %1").arg(message));
    });

    // Register custom protocol for dev environment
    registerCustomProtocol();

    // Handle incoming messages from other instances
    QObject::connect(&app, &SingleApplication::messageReceived, [casdoorHelper](const QString &msg) {
        if (msg.startsWith("dianshu://"))
        {
            QUrl url(msg);
            if (url.isValid())
            {
                QUrlQuery query(url);
                QString code = query.queryItemValue("code");
                QString state = query.queryItemValue("state");
                if (!code.isEmpty())
                {
                    casdoorHelper->handleAuthCode(code, state);
                }
            }
        }
    });

    QTimer::singleShot(0, [casdoorHelper]() {
        QStringList args = QCoreApplication::arguments();
        for (const QString &arg : args)
        {
            if (arg.startsWith("dianshu://"))
            {
                QUrl url(arg);
                if (url.isValid())
                {
                    QUrlQuery query(url);
                    QString code = query.queryItemValue("code");
                    QString state = query.queryItemValue("state");
                    if (!code.isEmpty())
                    {
                        casdoorHelper->handleAuthCode(code, state);
                    }
                }
                break;
            }
        }
    });

    engine.addImportPath("qrc:/");
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    int exitCode = app.exec();
    // Flush any queued events (warnings etc.) before closing
    sentry_flush(5000);
    sentry_close();
    return exitCode;
}
