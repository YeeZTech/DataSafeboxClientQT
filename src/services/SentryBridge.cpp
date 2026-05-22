#include "SentryBridge.h"
#include "sentry.h"
#include <QDebug>

SentryBridge::SentryBridge(QObject *parent)
    : QObject(parent)
{
}

void SentryBridge::captureMessage(const QString &message, int level)
{
    const char *levelName = "info";
    if (level == 1) {
        levelName = "warning";
    } else if (level >= 2) {
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
    sentry_flush(2000);
}
