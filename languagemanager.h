#ifndef LANGUAGEMANAGER_H
#define LANGUAGEMANAGER_H

#include <QObject>
#include <QTranslator>

class QQmlApplicationEngine;

// Backs the language picker in Settings (Automático/Español/English).
// mode 0 follows the system locale (falls back to Spanish, the source
// language, if it doesn't match a shipped translation); 1 forces Spanish
// by installing no translator at all; 2 forces English via Vacaplan_en.qm.
// Switching mode calls QQmlApplicationEngine::retranslate() so every live
// qsTr() binding updates immediately — no restart needed.
class LanguageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int mode READ mode WRITE setMode NOTIFY modeChanged)

public:
    explicit LanguageManager(QQmlApplicationEngine *engine, QObject *parent = nullptr);

    int mode() const;
    void setMode(int mode);

signals:
    void modeChanged();

private:
    void applyTranslator();

    QQmlApplicationEngine *m_engine;
    QTranslator m_translator;
    int m_mode = 0;
};

#endif // LANGUAGEMANAGER_H
