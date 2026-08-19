#ifndef HOLIDAYPROVIDER_H
#define HOLIDAYPROVIDER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>

// Fetches Spain's national/regional/local holidays using the free public
// API from calendariosnacionales.com. If the request fails, the UI should
// fall back to the manual holiday entry screen.
class HolidayProvider : public QObject
{
    Q_OBJECT

public:
    explicit HolidayProvider(QObject *parent = nullptr);

    Q_INVOKABLE void fetchComunidades(int year);
    Q_INVOKABLE void fetchProvincias(int year, const QString &ccaaSlug);
    Q_INVOKABLE void fetchMunicipios(int year, const QString &ccaaSlug, const QString &provinciaSlug);

    // Requests holidays at the most specific level available (municipio > CCAA > national).
    // The API already returns the combined, deduplicated calendar in holidays.calendar.
    Q_INVOKABLE void fetchHolidays(int year, const QString &ccaaSlug,
                                    const QString &provinciaSlug, const QString &municipioSlug);

    Q_INVOKABLE QVariantList loadCachedHolidays(int year) const;
    Q_INVOKABLE void saveManualHolidays(int year, const QVariantList &holidays);

signals:
    void comunidadesReady(int year, const QVariantList &comunidades);
    void provinciasReady(int year, const QVariantList &provincias);
    void municipiosReady(int year, const QVariantList &municipios);
    void holidaysReady(int year, const QVariantList &holidays);
    void holidaysError(int year, const QString &message);

private:
    QNetworkAccessManager m_net;
    QString cacheFilePath(int year) const;
    void saveHolidaysToCache(int year, const QVariantList &holidays) const;
};

#endif // HOLIDAYPROVIDER_H
