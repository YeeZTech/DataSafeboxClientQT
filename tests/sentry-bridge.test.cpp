// Compiles the production bridge against sentry-native. The custom transport owns
// every envelope in memory; Crashpad is disabled and no network transport exists.
#include "SentryBridge.h"
#include <QAtomicInt>
#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QMutexLocker>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QTemporaryFile>
#include <QTextStream>
#include <QtTest>
#include <atomic>
#include <sentry.h>
#include <thread>
#include <vector>

#include "sentry-routing.generated.h"

namespace
{
struct RecordingTransport
{
    QMutex mutex;
    QList<QJsonObject> events;
    QList<QJsonObject> logs;
    std::atomic<int> flushes{0};

    static void send(sentry_envelope_t *envelope, void *state)
    {
        auto &self = *static_cast<RecordingTransport *>(state);
        QMutexLocker lock(&self.mutex);
        const sentry_value_t event = sentry_envelope_get_event(envelope);
        if (!sentry_value_is_null(event))
        {
            char *json = sentry_value_to_json(event);
            self.events.append(QJsonDocument::fromJson(json).object());
            sentry_free(json);
        }
        size_t size = 0;
        char *serialized = sentry_envelope_serialize(envelope, &size);
        const QByteArray bytes(serialized, static_cast<qsizetype>(size));
        sentry_free(serialized);
        qsizetype pos = bytes.indexOf('\n') + 1;
        while (pos > 0 && pos < bytes.size())
        {
            const qsizetype end = bytes.indexOf('\n', pos);
            if (end < 0)
                break;
            const auto header = QJsonDocument::fromJson(bytes.mid(pos, end - pos)).object();
            const int length = header.value("length").toInt();
            if (header.value("type") == "log")
            {
                const auto payload = QJsonDocument::fromJson(bytes.mid(end + 1, length)).object();
                for (const auto &item : payload.value("items").toArray())
                    self.logs.append(item.toObject());
            }
            pos = end + 1 + length;
            if (pos < bytes.size() && bytes.at(pos) == '\n')
                ++pos;
        }
        sentry_envelope_free(envelope);
    }

    QList<QJsonObject> eventSnapshot()
    {
        QMutexLocker lock(&mutex);
        return events;
    }

    QList<QJsonObject> logSnapshot()
    {
        QMutexLocker lock(&mutex);
        return logs;
    }
};
} // namespace

class SentryBridgeTest : public QObject
{
    Q_OBJECT
    RecordingTransport transport;
    QTemporaryDir database;
    const QStringList diagnosticMessages{"Connection closed", "Host not found", "Insufficient balance",
                                         "Duplicate request", "File not found", "Encryption failed",
                                         "Payment confirmed"};

  private slots:
    void initTestCase()
    {
        QVERIFY(database.isValid());
        auto *options = sentry_options_new();
        sentry_options_set_dsn(options, "https://offline-test@127.0.0.1:1/1");
        sentry_options_set_database_path(options, database.path().toUtf8().constData());
        sentry_options_set_backend(options, nullptr);
        sentry_options_set_auto_session_tracking(options, 0);
        sentry_options_set_symbolize_stacktraces(options, 0);
        sentry_options_set_enable_logs(options, 1);
        auto *sink = sentry_transport_new(RecordingTransport::send);
        sentry_transport_set_state(sink, &transport);
        sentry_transport_set_startup_func(sink, [](const sentry_options_t *, void *) { return 0; });
        sentry_transport_set_flush_func(sink, [](uint64_t, void *state) {
            ++static_cast<RecordingTransport *>(state)->flushes;
            return 0;
        });
        sentry_options_set_transport(options, sink);
        QCOMPARE(sentry_init(options), 0);
    }

    void diagnosticsRetainLogsAndBreadcrumbsWithoutIssuesOrFlush()
    {
        SentryBridge bridge;
        const int flushesBefore = transport.flushes.load();
        for (const auto &message : diagnosticMessages)
            bridge.recordMessage(message, message == "Payment confirmed" ? 0 : 2);
        SentryBridge::addBreadcrumb("dscc.notification", "error", "User cancelled", {{"operation_id", 123}});
        SentryBridge::addBreadcrumb("qt", "warning", "Font fallback");
        SentryBridge::addBreadcrumb("qt", "error", "Recoverable Qt critical");
        QVERIFY(transport.eventSnapshot().isEmpty());
        QCOMPARE(transport.flushes.load(), flushesBefore);
        SentryBridge::captureCritical("startup.qml_load_failed", "root_object_creation_failed",
                                      {{"url", "qrc:/Main.qml"}});
        const auto events = transport.eventSnapshot();
        QCOMPARE(events.size(), 1);
        const auto crumbs = events.first().value("breadcrumbs").toArray();
        for (const auto &message : diagnosticMessages)
        {
            bool found = false;
            for (const auto &crumb : crumbs)
                found |= crumb.toObject().value("message") == message;
            QVERIFY2(found, qPrintable("Missing breadcrumb: " + message));
        }
    }

    void criticalEventsHaveStableGroupingAndSeparateDetails()
    {
        const int before = transport.eventSnapshot().size();
        const QVariantMap details{{"operation_id", 123}, {"message", QString::fromUtf8("初始化失败")}};
        SentryBridge::captureCritical("core.initialization_failed", "database_not_ready", details);
        SentryBridge::captureCritical("core.initialization_failed", "database_not_ready",
                                      {{"operation_id", 999}, {"message", "Initialization failed"}});
        const auto events = transport.eventSnapshot();
        QCOMPARE(events.size(), before + 1);
        const auto event = events.last();
        QCOMPARE(event.value("level").toString(), "error");
        QCOMPARE(event.value("logger").toString(), "app.critical");
        QCOMPARE(event.value("message").toObject().value("formatted").toString(),
                 "core.initialization_failed: database_not_ready");
        QCOMPARE(event.value("fingerprint").toArray(),
                 QJsonArray({"core.initialization_failed", "database_not_ready"}));
        const auto tags = event.value("tags").toObject();
        QCOMPARE(tags.value("alert_worthy").toString(), "true");
        QCOMPARE(tags.value("event_key").toString(), "core.initialization_failed");
        QCOMPARE(tags.value("reason_code").toString(), "database_not_ready");
        QCOMPARE(event.value("extra").toObject(), QJsonObject::fromVariantMap(details));
    }

    void distinctReasonsAndKeysRemainReportable()
    {
        const int before = transport.eventSnapshot().size();
        SentryBridge::captureCritical("core.initialization_failed", "exception");
        SentryBridge::captureCritical("test:a", "b");
        SentryBridge::captureCritical("test", "a:b");
        QCOMPARE(transport.eventSnapshot().size(), before + 3);
    }

    void recoverableQtDiagnosticsStayLocalAndDoNotCreateIssues()
    {
        const int before = transport.eventSnapshot().size();
        QTemporaryFile file;
        QVERIFY(file.open());
        QTextStream stream(&file);
        g_logFile = &file;
        g_logStream = &stream;
        g_previousMessageHandler = [](QtMsgType, const QMessageLogContext &, const QString &) {};
        const auto reset = qScopeGuard([] {
            g_logFile = nullptr;
            g_logStream = nullptr;
        });
        sentryMessageHandler(QtWarningMsg, QMessageLogContext(), "Font fallback");
        sentryMessageHandler(QtCriticalMsg, QMessageLogContext(), "Host not found");
        sentryMessageHandler(QtCriticalMsg, QMessageLogContext(nullptr, 0, nullptr, "dscc"), "Duplicate request");
        QCOMPARE(transport.eventSnapshot().size(), before);
        QVERIFY(file.seek(0));
        const QByteArray localLog = file.readAll();
        QVERIFY(localLog.contains("Font fallback"));
        QVERIFY(localLog.contains("Host not found"));
        QVERIFY(localLog.contains("Duplicate request"));
    }

    void pipelineAndPluginRoutingCoalesceKnownFailures()
    {
        const int before = transport.eventSnapshot().size();
        QTemporaryFile file;
        QVERIFY(file.open());
        QTextStream stream(&file);
        g_logFile = &file;
        g_logStream = &stream;
        const auto reset = qScopeGuard([] {
            g_logFile = nullptr;
            g_logStream = nullptr;
        });
        for (int i = 0; i < 20; ++i)
        {
            sentryMessageHandler(QtWarningMsg, QMessageLogContext(), "MSL function for entry point main0 not found");
            sentryMessageHandler(QtWarningMsg, QMessageLogContext(), "Failed to build graphics pipeline state");
        }
        auto events = transport.eventSnapshot();
        QCOMPARE(events.size(), before + 1);
        QCOMPARE(events.last().value("fingerprint").toArray(),
                 QJsonArray({"render.pipeline_failed", "graphics_pipeline"}));
        QVERIFY(file.seek(0));
        const QByteArray localLog = file.readAll();
        QCOMPARE(localLog.count("graphics pipeline warnings suppressed"), 1);
        QCOMPARE(localLog.count("[WARN]"), 11);

        sentryMessageHandler(QtWarningMsg, QMessageLogContext(), "No WebView plug-in found!");
        sentryMessageHandler(QtCriticalMsg, QMessageLogContext(), "No WebView plug-in found!");
        events = transport.eventSnapshot();
        QCOMPARE(events.size(), before + 2);
        QCOMPARE(events.last().value("fingerprint").toArray(),
                 QJsonArray({"startup.webview_unavailable", "plugin_missing"}));
    }

    void fatalHandlerFlushesAndDelegatesWithoutSyntheticIssue()
    {
        static int fatalDelegations = 0;
        g_previousMessageHandler = [](QtMsgType type, const QMessageLogContext &, const QString &) {
            if (type == QtFatalMsg)
                ++fatalDelegations;
        };
        const int before = transport.eventSnapshot().size();
        const int flushes = transport.flushes.load();
        // Call the handler directly: invoking qFatal() would terminate the test process.
        sentryMessageHandler(QtFatalMsg, QMessageLogContext(), "Failed to build graphics pipeline state");
        QCOMPARE(transport.eventSnapshot().size(), before);
        QCOMPARE(transport.flushes.load(), flushes + 1);
        QCOMPARE(fatalDelegations, 1);
    }

    void concurrentCallsReportOncePerProcess()
    {
        const int before = transport.eventSnapshot().size();
        std::vector<std::thread> workers;
        std::atomic<bool> start{false};
        for (int i = 0; i < 24; ++i)
        {
            workers.emplace_back([i, &start] {
                while (!start.load())
                    std::this_thread::yield();
                for (int repeat = 0; repeat < 20; ++repeat)
                    SentryBridge::captureCritical("test.concurrent", "same_failure", {{"operation_id", i}});
            });
        }
        start.store(true);
        for (auto &worker : workers)
            worker.join();
        QCOMPARE(transport.eventSnapshot().size(), before + 1);
    }

    void unhandledEventsBypassBridgeDeduplication()
    {
        // This verifies the SDK event route, not actual Crashpad/minidump generation.
        // Native crash integration still requires a separate controlled crash test.
        const int before = transport.eventSnapshot().size();
        for (int i = 0; i < 2; ++i)
        {
            auto event = sentry_value_new_event();
            sentry_value_set_by_key(event, "level", sentry_value_new_string("fatal"));
            auto exception = sentry_value_new_exception("SyntheticUnhandled", "Offline regression test");
            auto mechanism = sentry_value_new_object();
            sentry_value_set_by_key(mechanism, "handled", sentry_value_new_bool(0));
            sentry_value_set_by_key(mechanism, "type", sentry_value_new_string("test"));
            sentry_value_set_by_key(exception, "mechanism", mechanism);
            sentry_event_add_exception(event, exception);
            sentry_capture_event(event);
        }
        const auto events = transport.eventSnapshot();
        QCOMPARE(events.size(), before + 2);
        QVERIFY(!events.last()
                     .value("exception")
                     .toObject()
                     .value("values")
                     .toArray()
                     .first()
                     .toObject()
                     .value("mechanism")
                     .toObject()
                     .value("handled")
                     .toBool(true));
    }

    void cleanupTestCase()
    {
        const int before = transport.eventSnapshot().size();
        // This SDK batches Logs independently of sentry_flush(); close drains them.
        QCOMPARE(sentry_close(), 0);
        QCOMPARE(transport.eventSnapshot().size(), before);
        const auto logs = transport.logSnapshot();
        for (const auto &message : diagnosticMessages)
        {
            bool found = false;
            for (const auto &log : logs)
                found |= log.value("body").toString().contains(message);
            QVERIFY2(found, qPrintable("Missing diagnostic log: " + message));
        }
    }
};

QTEST_GUILESS_MAIN(SentryBridgeTest)
#include "sentry-bridge.test.moc"
