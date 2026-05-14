#ifndef LANGUAGEMANAGER_H
#define LANGUAGEMANAGER_H

#include <QObject>
#include <QTranslator>
#include <QString>

/**
 * LanguageManager
 *
 * 职责：
 *   1. 在启动时加载持久化的语言偏好（或系统默认），安装对应 QTranslator。
 *   2. 向 dscc::Notification::SetTranslator 注入 Qt 翻译函数，使核心库的错误
 *      消息经由 Notification::Localized() 返回本地化文本。
 *   3. 暴露 Q_INVOKABLE switchLanguage(code) 供 QML 在设置页切换语言。
 *
 * 支持的语言代码：
 *   "zh_CN"  简体中文（默认）
 *   "en"     英文（使用核心库内置英文模板，不加载翻译文件）
 */
class LanguageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentLanguage READ currentLanguage NOTIFY languageChanged)

public:
    explicit LanguageManager(QObject *parent = nullptr);
    ~LanguageManager() override = default;

    QString currentLanguage() const { return m_currentLanguage; }

    /** 启动时调用一次，从 QSettings 读取上次保存的语言并生效 */
    void applyInitialLanguage();

    /** QML 调用：切换语言并持久化到 QSettings */
    Q_INVOKABLE void switchLanguage(const QString &languageCode);

signals:
    void languageChanged(QString languageCode);

private:
    void loadLanguage(const QString &languageCode);
    void installNotificationTranslator();

    QTranslator m_translator;
    QString     m_currentLanguage;
};

#endif // LANGUAGEMANAGER_H
