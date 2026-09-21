#include "languagemanager.h"
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QLocale>

LanguageManager::LanguageManager(QQmlApplicationEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine)
{
    QSettings settings;
    settings.beginGroup("appearance");
    m_mode = settings.value("languageMode", 0).toInt();
    settings.endGroup();
    applyTranslator();
}

int LanguageManager::mode() const {
    return m_mode;
}

void LanguageManager::setMode(int mode) {
    if (m_mode == mode) return;
    m_mode = mode;

    QSettings settings;
    settings.beginGroup("appearance");
    settings.setValue("languageMode", m_mode);
    settings.endGroup();

    applyTranslator();
    emit modeChanged();
}

void LanguageManager::applyTranslator() {
    QCoreApplication::removeTranslator(&m_translator);

    bool loaded = false;
    if (m_mode == 2) {
        loaded = m_translator.load(QLocale(QLocale::English), "Vacaplan", "_", ":/i18n");
    } else if (m_mode == 0) {
        loaded = m_translator.load(QLocale::system(), "Vacaplan", "_", ":/i18n");
    }
    // mode == 1 (force Spanish): install no translator — qsTr() falls
    // through to the Spanish source text on its own.
    if (loaded) {
        QCoreApplication::installTranslator(&m_translator);
    }

    if (m_engine) {
        m_engine->retranslate();
    }
}
