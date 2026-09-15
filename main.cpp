#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include "datacenter.h"
#include "holidayprovider.h"
#include "clipboard.h"
#include "exporter.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // "Basic" style to fully customize buttons and controls with the
    // same look on macOS and Android.
    QQuickStyle::setStyle("Basic");

    app.setOrganizationName("dreSoft");
    app.setOrganizationDomain("");
    app.setApplicationName("Vacaplan");

    qmlRegisterType<DataCenter>("Vacaplan", 1, 0, "DataCenter");
    qmlRegisterType<HolidayProvider>("Vacaplan", 1, 0, "HolidayProvider");
    qmlRegisterType<Clipboard>("Vacaplan", 1, 0, "Clipboard");
    qmlRegisterType<Exporter>("Vacaplan", 1, 0, "Exporter");

    QQmlApplicationEngine engine;
    engine.loadFromModule("Vacaplan", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
