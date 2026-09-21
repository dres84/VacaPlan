#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickStyle>
#include "datacenter.h"
#include "holidayprovider.h"
#include "clipboard.h"
#include "exporter.h"
#include "languagemanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // "Basic" style to fully customize buttons and controls with the
    // same look on macOS and Android.
    QQuickStyle::setStyle("Basic");

    app.setOrganizationName("dreSoft");
    app.setOrganizationDomain("");
    app.setApplicationName("Vacaplan");

    QQmlApplicationEngine engine;

    // Backs the language picker in Settings. Reads the persisted choice and
    // installs the matching translator before any QML loads; switching it
    // later re-translates the whole running UI in place.
    LanguageManager languageManager(&engine);
    qmlRegisterSingletonInstance<LanguageManager>("Vacaplan", 1, 0, "LanguageManager", &languageManager);

    qmlRegisterType<DataCenter>("Vacaplan", 1, 0, "DataCenter");
    qmlRegisterType<HolidayProvider>("Vacaplan", 1, 0, "HolidayProvider");
    qmlRegisterType<Clipboard>("Vacaplan", 1, 0, "Clipboard");
    qmlRegisterType<Exporter>("Vacaplan", 1, 0, "Exporter");

    engine.loadFromModule("Vacaplan", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
