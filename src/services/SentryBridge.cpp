#include "SentryBridge.h"
#include "sentry.h"
#include <QDateTime>
#include <QDebug>
#include <QGuiApplication>
#include <QLocale>
#include <QScreen>
#include <QSettings>
#include <QSysInfo>
#include <QThread>
#include <QTimeZone>
#include <cstdint>

// Sentry's device/app contexts want details Qt has no portable API for (physical memory,
// boot time, CPU model, process working set), so they come from the platform SDKs.
#if defined(Q_OS_WIN)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
// psapi.h must follow windows.h
#include <psapi.h>
#elif defined(Q_OS_MACOS)
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#endif

namespace
{
sentry_value_t qVariantToSentryValue(const QVariant &value)
{
    switch (value.typeId())
    {
    case QMetaType::Bool:
        return sentry_value_new_bool(value.toBool() ? 1 : 0);
    case QMetaType::Double:
    case QMetaType::Float:
        return sentry_value_new_double(value.toDouble());
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong: {
        // Numbers must stay numbers: Sentry renders e.g. device.memory_size as "15.4 GiB"
        // only if it is numeric. Byte counts overflow int32, and a double holds integers
        // exactly up to 2^53 — far beyond any value reported here.
        const qlonglong asInt = value.toLongLong();
        if (asInt >= INT32_MIN && asInt <= INT32_MAX)
        {
            return sentry_value_new_int32(static_cast<int32_t>(asInt));
        }
        return sentry_value_new_double(static_cast<double>(asInt));
    }
    default:
        return sentry_value_new_string(value.toString().toUtf8().constData());
    }
}

sentry_value_t qVariantMapToSentryObject(const QVariantMap &map)
{
    sentry_value_t object = sentry_value_new_object();
    for (auto it = map.constBegin(); it != map.constEnd(); ++it)
    {
        sentry_value_set_by_key(object, it.key().toUtf8().constData(), qVariantToSentryValue(it.value()));
    }
    return object;
}

// Invariant halves of the app/device contexts, captured once at startup. sentry_set_context
// replaces a context wholesale, so a refresh has to re-send these alongside the fresh values.
QVariantMap g_staticDeviceContext;
QString g_appVersion;
QString g_appStartTime;

// Physical RAM: {total bytes, free bytes}. Zeroes mean "unavailable" and are dropped.
struct MemoryInfo
{
    qint64 total = 0;
    qint64 free = 0;
};

MemoryInfo systemMemory()
{
    MemoryInfo info;
#if defined(Q_OS_WIN)
    MEMORYSTATUSEX status;
    status.dwLength = sizeof(status);
    if (GlobalMemoryStatusEx(&status))
    {
        info.total = static_cast<qint64>(status.ullTotalPhys);
        info.free = static_cast<qint64>(status.ullAvailPhys);
    }
#elif defined(Q_OS_MACOS)
    int64_t memSize = 0;
    size_t memSizeLen = sizeof(memSize);
    if (sysctlbyname("hw.memsize", &memSize, &memSizeLen, nullptr, 0) == 0)
    {
        info.total = static_cast<qint64>(memSize);
    }

    vm_size_t pageSize = 0;
    vm_statistics64_data_t vmStat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS &&
        host_statistics64(mach_host_self(), HOST_VM_INFO64, reinterpret_cast<host_info64_t>(&vmStat), &count) ==
            KERN_SUCCESS)
    {
        info.free = static_cast<qint64>(vmStat.free_count) * static_cast<qint64>(pageSize);
    }
#endif
    return info;
}

// Resident set of this process, in bytes (0 when unavailable).
qint64 processMemoryUsage()
{
#if defined(Q_OS_WIN)
    PROCESS_MEMORY_COUNTERS counters;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters)))
    {
        return static_cast<qint64>(counters.WorkingSetSize);
    }
#elif defined(Q_OS_MACOS)
    mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS)
    {
        return static_cast<qint64>(info.resident_size);
    }
#endif
    return 0;
}

// System boot time as ISO-8601 UTC (empty when unavailable).
QString bootTimeIso()
{
#if defined(Q_OS_WIN)
    return QDateTime::currentDateTimeUtc().addMSecs(-static_cast<qint64>(GetTickCount64())).toString(Qt::ISODate);
#elif defined(Q_OS_MACOS)
    struct timeval bootTime;
    size_t len = sizeof(bootTime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &bootTime, &len, nullptr, 0) == 0)
    {
        return QDateTime::fromSecsSinceEpoch(bootTime.tv_sec, QTimeZone::UTC).toString(Qt::ISODate);
    }
    return QString();
#else
    return QString();
#endif
}

// Marketing name of the CPU, e.g. "AMD Ryzen 7 5800H with Radeon Graphics".
QString cpuDescription()
{
#if defined(Q_OS_WIN)
    QSettings cpuKey(QStringLiteral("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0"),
                     QSettings::NativeFormat);
    return cpuKey.value(QStringLiteral("ProcessorNameString")).toString().trimmed();
#elif defined(Q_OS_MACOS)
    char brand[256] = {0};
    size_t brandLen = sizeof(brand);
    if (sysctlbyname("machdep.cpu.brand_string", brand, &brandLen, nullptr, 0) == 0)
    {
        return QString::fromUtf8(brand).trimmed();
    }
    return QString();
#else
    return QString();
#endif
}

// Nominal CPU clock in MHz (0 when unavailable).
int cpuFrequencyMhz()
{
#if defined(Q_OS_WIN)
    QSettings cpuKey(QStringLiteral("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0"),
                     QSettings::NativeFormat);
    return cpuKey.value(QStringLiteral("~MHz")).toInt();
#else
    return 0;
#endif
}

// Sentry structured Logs are a separate stream from breadcrumbs/events: they show up in
// the project's Logs explorer (and trace-correlated on an event's detail page) regardless
// of whether anything ever crashes, so every breadcrumb/error we report also becomes one.
void emitLog(const QString &level, const QString &message)
{
    const QByteArray utf8 = message.toUtf8();
    if (level == QStringLiteral("error"))
    {
        sentry_log_error("%s", utf8.constData());
    }
    else if (level == QStringLiteral("warning"))
    {
        sentry_log_warn("%s", utf8.constData());
    }
    else if (level == QStringLiteral("debug"))
    {
        sentry_log_debug("%s", utf8.constData());
    }
    else
    {
        sentry_log_info("%s", utf8.constData());
    }
}
} // namespace

SentryBridge::SentryBridge(QObject *parent) : QObject(parent)
{
}

void SentryBridge::captureMessage(const QString &message, int level)
{
    const char *levelName = "info";
    if (level == 1)
    {
        levelName = "warning";
    }
    else if (level >= 2)
    {
        levelName = "error";
    }

    QByteArray utf8Message = message.toUtf8();
    sentry_value_t event = sentry_value_new_event();
    sentry_value_set_by_key(event, "level", sentry_value_new_string(levelName));
    sentry_value_set_by_key(event, "logger", sentry_value_new_string("qml"));

    sentry_value_t messageObject = sentry_value_new_object();
    sentry_value_set_by_key(messageObject, "formatted", sentry_value_new_string(utf8Message.constData()));
    sentry_value_set_by_key(event, "message", messageObject);

    sentry_capture_event(event);
    emitLog(QString::fromUtf8(levelName), QStringLiteral("[qml] %1").arg(message));
    sentry_flush(2000);
}

void SentryBridge::addBreadcrumb(const QString &category, const QString &level, const QString &message,
                                 const QVariantMap &data)
{
    sentry_value_t crumb = sentry_value_new_breadcrumb("default", message.toUtf8().constData());
    sentry_value_set_by_key(crumb, "category", sentry_value_new_string(category.toUtf8().constData()));
    sentry_value_set_by_key(crumb, "level", sentry_value_new_string(level.toUtf8().constData()));
    if (!data.isEmpty())
    {
        sentry_value_set_by_key(crumb, "data", qVariantMapToSentryObject(data));
    }
    sentry_add_breadcrumb(crumb);
    emitLog(level, QStringLiteral("[%1] %2").arg(category, message));
}

void SentryBridge::captureError(const QString &loggerName, const QString &message, const QVariantMap &tags,
                                const QVariantMap &extra)
{
    sentry_value_t event = sentry_value_new_event();
    sentry_value_set_by_key(event, "level", sentry_value_new_string("error"));
    sentry_value_set_by_key(event, "logger", sentry_value_new_string(loggerName.toUtf8().constData()));

    sentry_value_t messageObject = sentry_value_new_object();
    sentry_value_set_by_key(messageObject, "formatted", sentry_value_new_string(message.toUtf8().constData()));
    sentry_value_set_by_key(event, "message", messageObject);

    if (!tags.isEmpty())
    {
        // Sentry tags are always strings.
        sentry_value_t tagsObject = sentry_value_new_object();
        for (auto it = tags.constBegin(); it != tags.constEnd(); ++it)
        {
            sentry_value_set_by_key(tagsObject, it.key().toUtf8().constData(),
                                    sentry_value_new_string(it.value().toString().toUtf8().constData()));
        }
        sentry_value_set_by_key(event, "tags", tagsObject);
    }
    if (!extra.isEmpty())
    {
        sentry_value_set_by_key(event, "extra", qVariantMapToSentryObject(extra));
    }

    sentry_capture_event(event);
    emitLog(QStringLiteral("error"), QStringLiteral("[%1] %2").arg(loggerName, message));
}

void SentryBridge::setUser(const QString &id, const QString &username, const QString &email)
{
    sentry_value_t user = sentry_value_new_object();
    if (!id.isEmpty())
    {
        sentry_value_set_by_key(user, "id", sentry_value_new_string(id.toUtf8().constData()));
    }
    if (!username.isEmpty())
    {
        sentry_value_set_by_key(user, "username", sentry_value_new_string(username.toUtf8().constData()));
    }
    if (!email.isEmpty())
    {
        sentry_value_set_by_key(user, "email", sentry_value_new_string(email.toUtf8().constData()));
    }
    sentry_set_user(user);
}

void SentryBridge::clearUser()
{
    sentry_remove_user();
}

void SentryBridge::setContext(const QString &key, const QVariantMap &data)
{
    sentry_set_context(key.toUtf8().constData(), qVariantMapToSentryObject(data));
}

void SentryBridge::setTag(const QString &key, const QString &value)
{
    sentry_set_tag(key.toUtf8().constData(), value.toUtf8().constData());
}

void SentryBridge::installStartupContexts(const QString &appVersion)
{
    // sentry-native only fills in "os" and "trace" on its own. Everything below is what
    // makes an Issue diagnosable without asking the user what machine they were on.
    // The invariant halves are cached so refreshRuntimeContext() can re-send the whole
    // context (sentry_set_context replaces, never merges) without losing them.
    g_appVersion = appVersion;
    g_appStartTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    g_staticDeviceContext = {{QStringLiteral("arch"), QSysInfo::currentCpuArchitecture()},
                             {QStringLiteral("model"), QSysInfo::prettyProductName()},
                             {QStringLiteral("family"), QStringLiteral("Desktop")},
                             {QStringLiteral("processor_count"), QThread::idealThreadCount()}};
    if (const QString boot = bootTimeIso(); !boot.isEmpty())
    {
        g_staticDeviceContext.insert(QStringLiteral("boot_time"), boot);
    }
    if (const QString cpu = cpuDescription(); !cpu.isEmpty())
    {
        g_staticDeviceContext.insert(QStringLiteral("cpu_description"), cpu);
    }
    if (const int mhz = cpuFrequencyMhz(); mhz > 0)
    {
        g_staticDeviceContext.insert(QStringLiteral("processor_frequency"), mhz);
    }
    // Screens only exist once the GUI application is up; guard so this stays callable early.
    if (const QScreen *screen = QGuiApplication::primaryScreen())
    {
        const QSize size = screen->size();
        g_staticDeviceContext.insert(QStringLiteral("screen_resolution"),
                                     QStringLiteral("%1x%2").arg(size.width()).arg(size.height()));
        g_staticDeviceContext.insert(QStringLiteral("screen_width_pixels"), size.width());
        g_staticDeviceContext.insert(QStringLiteral("screen_height_pixels"), size.height());
        g_staticDeviceContext.insert(QStringLiteral("screen_density"), screen->devicePixelRatio());
    }

    refreshRuntimeContext();

    setContext(QStringLiteral("culture"),
               {{QStringLiteral("locale"), QLocale::system().name()},
                {QStringLiteral("timezone"), QString::fromUtf8(QTimeZone::systemTimeZoneId())}});

    setContext(QStringLiteral("runtime"), {{QStringLiteral("name"), QStringLiteral("Qt")},
                                           {QStringLiteral("version"), QString::fromUtf8(qVersion())}});

    // Tags are the searchable/filterable axis in the Issues list, so mirror the few
    // dimensions worth slicing by.
    setTag(QStringLiteral("qt_version"), QString::fromUtf8(qVersion()));
    setTag(QStringLiteral("arch"), QSysInfo::currentCpuArchitecture());
    setTag(QStringLiteral("app_version"), appVersion);
}

void SentryBridge::refreshRuntimeContext()
{
    // Memory figures age quickly; re-read them so a crash report shows the footprint at
    // the time of the crash rather than at startup.
    const MemoryInfo memory = systemMemory();

    QVariantMap appContext{{QStringLiteral("app_name"), QCoreApplication::applicationName()},
                           {QStringLiteral("app_version"), g_appVersion},
                           {QStringLiteral("app_arch"), QSysInfo::currentCpuArchitecture()},
                           {QStringLiteral("app_start_time"), g_appStartTime}};
    if (const qint64 appMemory = processMemoryUsage(); appMemory > 0)
    {
        appContext.insert(QStringLiteral("app_memory"), appMemory);
    }
    setContext(QStringLiteral("app"), appContext);

    QVariantMap deviceContext = g_staticDeviceContext;
    if (memory.total > 0)
    {
        deviceContext.insert(QStringLiteral("memory_size"), memory.total);
    }
    if (memory.free > 0)
    {
        deviceContext.insert(QStringLiteral("free_memory"), memory.free);
    }
    setContext(QStringLiteral("device"), deviceContext);
}
