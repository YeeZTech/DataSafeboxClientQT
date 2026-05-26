#ifndef LANGUAGEMANAGER_H
#define LANGUAGEMANAGER_H

#include <QObject>
#include <QTranslator>
#include <QString>

/**
 * LanguageManager
 *
 * Supported language codes: "en", "zh_cn".
 * On first launch, the system locale determines the default (Chinese → zh_cn, else en).
 * A saved preference in QSettings takes priority if it is a supported code.
 */
class LanguageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentLanguage READ currentLanguage NOTIFY languageChanged)

public:
    explicit LanguageManager(QObject *parent = nullptr);
    ~LanguageManager() override = default;

    QString currentLanguage() const { return m_currentLanguage; }

    void applyInitialLanguage();
    Q_INVOKABLE void switchLanguage(const QString &languageCode);

signals:
    void languageChanged(QString languageCode);

private:
    void loadLanguage(const QString &languageCode);
    void installNotificationTranslator();

    QTranslator m_translator;
    QTranslator m_qmlTranslator;
    QString     m_currentLanguage;
};

#endif // LANGUAGEMANAGER_H
