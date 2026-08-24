#include "SentryBridge.h"
#include "sentry.h"
#include <QDebug>

namespace
{
sentry_value_t qVariantToSentryValue(const QVariant &value)
{
    if (value.typeId() == QMetaType::Bool)
    {
        return sentry_value_new_bool(value.toBool() ? 1 : 0);
    }
    if (value.typeId() == QMetaType::Double || value.typeId() == QMetaType::Float)
    {
        return sentry_value_new_double(value.toDouble());
    }
    // Integers (incl. 64-bit) and everything else: stringify. These fields are for
    // diagnostic display only, so there is no need to risk int32 overflow.
    return sentry_value_new_string(value.toString().toUtf8().constData());
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
