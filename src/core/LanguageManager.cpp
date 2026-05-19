#include "LanguageManager.h"

#include "dscc/common/notification.h"

#include <QCoreApplication>
#include <QSettings>
#include <QDebug>

static const QString kSettingsKeyLanguage = QStringLiteral("app/language");
static const QString kDefaultLanguage     = QStringLiteral("zh_CN");

LanguageManager::LanguageManager(QObject *parent)
    : QObject(parent)
{}

void LanguageManager::applyInitialLanguage()
{
    // 注入翻译函数只需一次：lambda 始终查询当前已安装的 QTranslator，
    // 后续切换语言只需换 QTranslator，不需要重新 SetTranslator。
    installNotificationTranslator();

    QSettings settings;
    const QString saved = settings.value(kSettingsKeyLanguage, kDefaultLanguage).toString();
    loadLanguage(saved);
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
    // 移除旧的翻译器
    if (!m_currentLanguage.isEmpty()) {
        QCoreApplication::removeTranslator(&m_translator);
        QCoreApplication::removeTranslator(&m_qmlTranslator);
    }

    // 英文使用内置英文模板，不需要加载翻译文件
    if (languageCode != QLatin1String("en")) {
        const QString qmPath = QStringLiteral(":/translations/notification_%1.qm").arg(languageCode);
        if (m_translator.load(qmPath)) {
            QCoreApplication::installTranslator(&m_translator);
            qInfo() << "[LanguageManager] Loaded translation:" << qmPath;
        } else {
            qWarning() << "[LanguageManager] Translation file not found:" << qmPath
                       << "- falling back to default text";
        }

        // 加载 QML UI 翻译文件（与 dscc 通知翻译互不干扰，上下文不同）
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
    // 向核心库注入翻译函数。
    // 核心库 Localized() 传入的是已转换为 %1/%2/... 格式的源字符串，
    // 这里用 QCoreApplication::translate 在当前已安装的 QTranslator 中查找翻译。
    dscc::Notification::SetTranslator([](const QString &sourceText) -> QString {
        return QCoreApplication::translate("Notification", sourceText.toUtf8().constData());
    });
}
