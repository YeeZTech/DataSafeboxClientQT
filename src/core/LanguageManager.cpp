#include "LanguageManager.h"

#include "dscc/common/notification.h"

#include <QCoreApplication>
#include <QLocale>
#include <QSettings>
#include <QDebug>

static const QString kSettingsKeyLanguage = QStringLiteral("app/language");

static bool isSupportedLanguage(const QString &code)
{
    return code == QLatin1String("en") || code == QLatin1String("zh_cn");
}

static QString systemDefaultLanguage()
{
    return QLocale::system().language() == QLocale::Chinese
               ? QStringLiteral("zh_cn")
               : QStringLiteral("en");
}

LanguageManager::LanguageManager(QObject *parent)
    : QObject(parent)
{}

void LanguageManager::applyInitialLanguage()
{
    installNotificationTranslator();

    QSettings settings;
    const QString saved = settings.value(kSettingsKeyLanguage).toString();
    const QString language = isSupportedLanguage(saved) ? saved : systemDefaultLanguage();
    loadLanguage(language);
}

void LanguageManager::switchLanguage(const QString &languageCode)
{
    if (languageCode == m_currentLanguage)
        return;

    loadLanguage(languageCode);

    QSettings settings;
    settings.setValue(kSettingsKeyLanguage, languageCode);
}

void LanguageManager::loadLanguage(const QString &languageCode)
{
    if (!m_currentLanguage.isEmpty()) {
        QCoreApplication::removeTranslator(&m_translator);
        QCoreApplication::removeTranslator(&m_qmlTranslator);
    }

    if (languageCode != QLatin1String("en")) {
        const QString qmPath = QStringLiteral(":/translations/notification_%1.qm").arg(languageCode);
        if (m_translator.load(qmPath)) {
            QCoreApplication::installTranslator(&m_translator);
            qInfo() << "[LanguageManager] Loaded translation:" << qmPath;
        } else {
            qWarning() << "[LanguageManager] Translation file not found:" << qmPath
                       << "- falling back to default text";
        }

        // App-side UI translator (separate context from dscc notification translator)
        const QString qmlQmPath = QStringLiteral(":/translations/qml_%1.qm").arg(languageCode);
        if (m_qmlTranslator.load(qmlQmPath)) {
            QCoreApplication::installTranslator(&m_qmlTranslator);
            qInfo() << "[LanguageManager] Loaded QML translation:" << qmlQmPath;
        } else {
            qWarning() << "[LanguageManager] QML translation file not found:" << qmlQmPath;
        }
    }

    m_currentLanguage = languageCode;
    emit languageChanged(m_currentLanguage);
}

void LanguageManager::installNotificationTranslator()
{
    dscc::Notification::SetTranslator([](const QString &sourceText) -> QString {
        return QCoreApplication::translate("Notification", sourceText.toUtf8().constData());
    });
}
