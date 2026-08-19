#include "datacenter.h"
#include <QFile>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDir>
#include <QDebug>

DataCenter::DataCenter(QObject *parent) : QObject(parent) {
    load();
}

QJsonObject DataCenter::data() const {
    return m_data;
}

QString DataCenter::getFilePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/profile.json";
}

void DataCenter::loadEmptyData() {
    m_data = QJsonObject{
        {"onboardingCompleted", false},
        {"country", ""},
        {"ccaaSlug", ""},
        {"ccaaName", ""},
        {"provinciaSlug", ""},
        {"provinciaName", ""},
        {"municipioSlug", ""},
        {"municipioName", ""},
        {"totalVacationDays", 22},
        {"usedVacationMode", "dates"},
        {"usedVacationCount", 0},
        {"usedVacationDates", QJsonArray{}},
        {"usedVacationHourEntries", QJsonArray{}}
    };
}

void DataCenter::load() {
    QFile file(getFilePath());

    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();

        if (!doc.isNull() && doc.isObject()) {
            m_data = doc.object();
        } else {
            loadEmptyData();
        }
    } else {
        loadEmptyData();
    }

    save();
    emit dataChanged();
}

void DataCenter::save() {
    QFile file(getFilePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
        file.close();
    } else {
        qWarning() << "No se pudo guardar profile.json en" << getFilePath();
    }
}

bool DataCenter::onboardingCompleted() const {
    return m_data.value("onboardingCompleted").toBool(false);
}

void DataCenter::completeOnboarding() {
    m_data["onboardingCompleted"] = true;
    save();
    emit dataChanged();
}

void DataCenter::resetOnboarding() {
    m_data["onboardingCompleted"] = false;
    save();
    emit dataChanged();
}

void DataCenter::setLocation(const QString &country,
                              const QString &ccaaSlug, const QString &ccaaName,
                              const QString &provinciaSlug, const QString &provinciaName,
                              const QString &municipioSlug, const QString &municipioName) {
    m_data["country"] = country;
    m_data["ccaaSlug"] = ccaaSlug;
    m_data["ccaaName"] = ccaaName;
    m_data["provinciaSlug"] = provinciaSlug;
    m_data["provinciaName"] = provinciaName;
    m_data["municipioSlug"] = municipioSlug;
    m_data["municipioName"] = municipioName;
    save();
    emit dataChanged();
}

void DataCenter::setTotalVacationDays(int days) {
    m_data["totalVacationDays"] = days;
    save();
    emit dataChanged();
}

void DataCenter::setUsedVacationMode(const QString &mode) {
    m_data["usedVacationMode"] = mode;
    save();
    emit dataChanged();
}

void DataCenter::setUsedVacationCount(int count) {
    m_data["usedVacationCount"] = count;
    save();
    emit dataChanged();
}

void DataCenter::addUsedVacationDate(const QString &isoDate) {
    QJsonArray dates = m_data["usedVacationDates"].toArray();
    for (const auto &v : dates) {
        if (v.toString() == isoDate) {
            return; // already exists
        }
    }
    dates.append(isoDate);
    m_data["usedVacationDates"] = dates;
    save();
    emit dataChanged();
}

void DataCenter::removeUsedVacationDate(const QString &isoDate) {
    QJsonArray dates = m_data["usedVacationDates"].toArray();
    QJsonArray filtered;
    for (const auto &v : dates) {
        if (v.toString() != isoDate) {
            filtered.append(v);
        }
    }
    m_data["usedVacationDates"] = filtered;
    save();
    emit dataChanged();
}

void DataCenter::addUsedVacationHours(const QString &isoDate, int hours) {
    QJsonArray entries = m_data["usedVacationHourEntries"].toArray();
    QJsonArray filtered;
    for (const auto &v : entries) {
        if (v.toObject().value("date").toString() != isoDate) {
            filtered.append(v);
        }
    }
    filtered.append(QJsonObject{{"date", isoDate}, {"hours", hours}});
    m_data["usedVacationHourEntries"] = filtered;
    save();
    emit dataChanged();
}

void DataCenter::removeUsedVacationHours(const QString &isoDate) {
    QJsonArray entries = m_data["usedVacationHourEntries"].toArray();
    QJsonArray filtered;
    for (const auto &v : entries) {
        if (v.toObject().value("date").toString() != isoDate) {
            filtered.append(v);
        }
    }
    m_data["usedVacationHourEntries"] = filtered;
    save();
    emit dataChanged();
}
