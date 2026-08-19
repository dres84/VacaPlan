#include "holidayprovider.h"
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <algorithm>

static const QString kApiBase = "https://calendariosnacionales.com/es/v1";

HolidayProvider::HolidayProvider(QObject *parent) : QObject(parent) {
}

QString HolidayProvider::cacheFilePath(int year) const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return QString("%1/holidays_%2.json").arg(dir).arg(year);
}

void HolidayProvider::saveHolidaysToCache(int year, const QVariantList &holidays) const {
    QFile file(cacheFilePath(year));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(QJsonArray::fromVariantList(holidays)).toJson(QJsonDocument::Indented));
        file.close();
    }
}

QVariantList HolidayProvider::loadCachedHolidays(int year) const {
    QFile file(cacheFilePath(year));
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return {};
    }
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    if (!doc.isArray()) {
        return {};
    }
    return doc.array().toVariantList();
}

void HolidayProvider::saveManualHolidays(int year, const QVariantList &holidays) {
    QVariantList sorted = holidays;
    std::sort(sorted.begin(), sorted.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("date").toString() < b.toMap().value("date").toString();
    });
    saveHolidaysToCache(year, sorted);
    emit holidaysReady(year, sorted);
}

void HolidayProvider::fetchComunidades(int year) {
    QUrl url(QString("%1/%2/comunidades.json").arg(kApiBase).arg(year));
    QNetworkReply *reply = m_net.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, year]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit holidaysError(year, reply->errorString());
            return;
        }
        QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        QVariantList result;
        for (const auto &v : root.value("communities").toArray()) {
            QJsonObject c = v.toObject();
            result.append(QVariantMap{{"slug", c.value("slug").toString()},
                                       {"name", c.value("name").toString()}});
        }
        emit comunidadesReady(year, result);
    });
}

void HolidayProvider::fetchProvincias(int year, const QString &ccaaSlug) {
    QUrl url(QString("%1/%2/regiones/%3/provincias.json").arg(kApiBase).arg(year).arg(ccaaSlug));
    QNetworkReply *reply = m_net.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, year]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit holidaysError(year, reply->errorString());
            return;
        }
        QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        QVariantList result;
        for (const auto &v : root.value("provinces").toArray()) {
            QJsonObject p = v.toObject();
            result.append(QVariantMap{{"slug", p.value("slug").toString()},
                                       {"name", p.value("name").toString()}});
        }
        emit provinciasReady(year, result);
    });
}

void HolidayProvider::fetchMunicipios(int year, const QString &ccaaSlug, const QString &provinciaSlug) {
    QUrl url(QString("%1/%2/regiones/%3/provincias/%4/localidades.json")
                 .arg(kApiBase).arg(year).arg(ccaaSlug).arg(provinciaSlug));
    QNetworkReply *reply = m_net.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, year]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit holidaysError(year, reply->errorString());
            return;
        }
        QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        QVariantList result;
        for (const auto &v : root.value("municipalities").toArray()) {
            QJsonObject m = v.toObject();
            result.append(QVariantMap{{"slug", m.value("slug").toString()},
                                       {"name", m.value("name").toString()}});
        }
        emit municipiosReady(year, result);
    });
}

void HolidayProvider::fetchHolidays(int year, const QString &ccaaSlug,
                                     const QString &provinciaSlug, const QString &municipioSlug) {
    QString path;
    if (!municipioSlug.isEmpty() && !provinciaSlug.isEmpty() && !ccaaSlug.isEmpty()) {
        path = QString("localidades/%1/%2/%3").arg(ccaaSlug, provinciaSlug, municipioSlug);
    } else if (!ccaaSlug.isEmpty()) {
        path = QString("regiones/%1").arg(ccaaSlug);
    } else {
        path = "nacionales";
    }

    QUrl url(QString("%1/%2/%3.json").arg(kApiBase).arg(year).arg(path));
    QNetworkReply *reply = m_net.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, year]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit holidaysError(year, reply->errorString());
            return;
        }

        QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        QJsonValue holidaysValue = root.value("holidays");
        QJsonArray holidaysArray;

        if (holidaysValue.isArray()) {
            holidaysArray = holidaysValue.toArray();
        } else if (holidaysValue.isObject()) {
            QJsonObject holidaysObj = holidaysValue.toObject();
            holidaysArray = holidaysObj.value("calendar").toArray();
            if (holidaysArray.isEmpty()) {
                holidaysArray = holidaysObj.value("national").toArray();
            }
        }

        if (holidaysArray.isEmpty()) {
            emit holidaysError(year, "La API no devolvió festivos para esta ubicación");
            return;
        }

        QVariantList result;
        for (const auto &v : holidaysArray) {
            QJsonObject h = v.toObject();
            result.append(QVariantMap{{"date", h.value("date").toString()},
                                       {"name", h.value("name").toString()},
                                       {"scope", h.value("scope").toString()}});
        }
        std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value("date").toString() < b.toMap().value("date").toString();
        });

        saveHolidaysToCache(year, result);
        emit holidaysReady(year, result);
    });
}
