#include "AppConfig.h"
#include "ArrearsManager.h"
#include "CasdoorHelper.h"
#include "DsccBridge.h"
#include "LanguageManager.h"
#include "PathManager.h"
#include "SentryBridge.h"
#include "SingleApplication.h"
#include "UpdateManager.h"
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
#include <QWebEngineProfile>
#include <QtQml>
#include <QtWebEngineQuick>

// Sentry library is linked via the .pro (LIBS += -lsentry).
// The previous `#pragma comment(lib, "sentry.lib")` was MSVC-only and is removed for cross-platform builds.

static QtMessageHandler g_previousMessageHandler = nullptr;
static QFile *g_logFile = nullptr;
static QTextStream *g_logStream = nullptr;

static QString startupLocalRootPath()
{
#ifdef Q_OS_WIN
    const QString localAppData = qEnvironmentVariable("LOCALAPPDATA");
    if (!localAppData.isEmpty())
    {
        return QDir(localAppData).filePath(QStringLiteral("yeeztech/datasafebox-client"));
    }
#endif
    return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
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

    if (type == QtCriticalMsg || type == QtFatalMsg)
    {
        QByteArray utf8Message = msg.toUtf8();
        sentry_value_t event = sentry_value_new_event();
        sentry_value_set_by_key(event, "level", sentry_value_new_string("error"));
        sentry_value_t messageObject = sentry_value_new_object();
        sentry_value_set_by_key(messageObject, "formatted", sentry_value_new_string(utf8Message.constData()));
        sentry_value_set_by_key(event, "message", messageObject);
        sentry_value_set_by_key(event, "logger", sentry_value_new_string(context.category ? context.category : "qt"));
        sentry_capture_event(event);
        // Flush immediately for critical/fatal so events are sent even if the app crashes
        sentry_flush(5000);
    }
    else if (type == QtWarningMsg)
    {
        QByteArray utf8Message = msg.toUtf8();
        sentry_value_t event = sentry_value_new_event();
        sentry_value_set_by_key(event, "level", sentry_value_new_string("warning"));
        sentry_value_set_by_key(event, "logger", sentry_value_new_string("qt"));
        sentry_value_t messageObject = sentry_value_new_object();
        sentry_value_set_by_key(messageObject, "formatted", sentry_value_new_string(utf8Message.constData()));
        sentry_value_set_by_key(event, "message", messageObject);
        sentry_capture_event(event);
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

        const QString webEngineDataPath = QDir(startupCacheDir).filePath("webengine/default-profile/storage");
        const QString qmlDiskCachePath = QDir(startupCacheDir).filePath("qml/disk-cache");
        QDir().mkpath(webEngineDataPath);
        QDir().mkpath(qmlDiskCachePath);

        // Force QtWebEngine/QML runtime files under local cache root, avoid Roaming writes.
        qputenv("QTWEBENGINE_USER_DATA_PATH", webEngineDataPath.toUtf8());
        qputenv("QTWEBENGINE_CHROMIUM_USER_DATA_DIR", webEngineDataPath.toUtf8());
        qputenv("QML_DISK_CACHE_PATH", qmlDiskCachePath.toUtf8());
        qputenv("QML_CACHE_PATH", qmlDiskCachePath.toUtf8());
    }

    // Set WebEngine environment before initialization
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu");

    // Auto-select render mode (software vs hardware) before any Qt windowing init
    autoSelectRenderMode();

    // Initialize QtWebEngine BEFORE creating QApplication
    QtWebEngineQuick::initialize();

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

    // Remove legacy Casdoor persistent storage (cookies, localStorage) so the
    // off-the-record WebEngineProfile starts with a clean slate on every launch.
    // This prevents the Casdoor login page from showing "使用以下账号继续".
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

    QWebEngineProfile *defaultWebProfile = QWebEngineProfile::defaultProfile();
    defaultWebProfile->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);

    auto applyRuntimeCachePaths = [pathManager, defaultWebProfile](UpdateManager *manager) {
        const QString cacheRoot = pathManager->cacheDir();
        qputenv("APP_CACHE_DIR", cacheRoot.toUtf8());
        qputenv("QML_DISK_CACHE_PATH", QDir(cacheRoot).filePath("qml/disk-cache").toUtf8());
        qputenv("QML_CACHE_PATH", QDir(cacheRoot).filePath("qml/disk-cache").toUtf8());

        const QString webEngineProfileRoot = QDir(cacheRoot).filePath("webengine/default-profile");
        const QString webEngineStoragePath = QDir(webEngineProfileRoot).filePath("storage");
        const QString webEngineHttpCachePath = QDir(webEngineProfileRoot).filePath("http-cache");
        QDir().mkpath(webEngineStoragePath);
        QDir().mkpath(webEngineHttpCachePath);

        qputenv("QTWEBENGINE_USER_DATA_PATH", webEngineStoragePath.toUtf8());
        qputenv("QTWEBENGINE_CHROMIUM_USER_DATA_DIR", webEngineStoragePath.toUtf8());
        defaultWebProfile->setPersistentStoragePath(webEngineStoragePath);
        defaultWebProfile->setCachePath(webEngineHttpCachePath);

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
        sentry_options_set_release(options, "datasafebox-client@1.0.0");
        sentry_options_set_environment(options, "production");
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
            }
            else
            {
                qWarning() << "[Config] Sentry initialization failed, code:" << sentryInitResult;
            }
        }
    }
    g_previousMessageHandler = qInstallMessageHandler(sentryMessageHandler);
    qInfo() << "[Startup] datasafebox-qt-client starting, build:" << __DATE__ << __TIME__;

    // Periodically flush queued Sentry events (e.g. warnings) every 30 seconds
    QTimer *sentryFlushTimer = new QTimer(&app);
    sentryFlushTimer->setInterval(30000);
    QObject::connect(sentryFlushTimer, &QTimer::timeout, []() { sentry_flush(3000); });
    sentryFlushTimer->start();

    app.setWindowIcon(QIcon(":/icons/SafeLogo.svg"));

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

    // Register AppConfig (unified service URL config — edit AppConfig.h to switch environments)
    AppConfig *appConfig = new AppConfig(&app);
    engine.rootContext()->setContextProperty("AppConfig", appConfig);

    // Register LanguageManager — must be done before DsccBridge so that
    // Notification::SetTranslator is installed before any notifications are created.
    LanguageManager *languageManager = new LanguageManager(&app);
    languageManager->applyInitialLanguage();
    engine.rootContext()->setContextProperty("LanguageManager", languageManager);

    // Register DsccBridge (business logic dynamic library)
    const QString dsccDbPath = pathManager->featureDataDir("dscc");
    QDir().mkpath(dsccDbPath);
    DsccBridge *dsccBridge = new DsccBridge(QDir(dsccDbPath).filePath("meta.db"), dsccDbPath,
                                            QString::fromLatin1(AppCfg::API_BASE_URL), QString(), &app);
    dsccBridge->initialize();
    engine.rootContext()->setContextProperty("DsccBridge", static_cast<QObject *>(dsccBridge));

    // Register ArrearsManager (account arrears/paused status)
    ArrearsManager *arrearsManager = new ArrearsManager(&app);
    engine.rootContext()->setContextProperty("ArrearsManager", arrearsManager);

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
