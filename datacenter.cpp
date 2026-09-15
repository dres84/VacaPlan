#include "datacenter.h"
#include <QFile>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDir>
#include <QDebug>
#include <algorithm>

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
        {"usedVacationHourEntries", QJsonArray{}},
        {"dayMarks", QJsonArray{}},
        {"shareRecipientName", ""},
        {"shareRecipientEmail", ""},
        {"shareSenderEmail", ""}
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

    // Migrate older profiles (from before day-state tracking existed):
    // seed dayMarks from the flat used-dates list, once.
    if (!m_data.contains("dayMarks")) {
        QJsonArray marks;
        if (m_data.value("usedVacationMode").toString() == "dates") {
            const QJsonArray dates = m_data.value("usedVacationDates").toArray();
            for (const auto &v : dates) {
                marks.append(QJsonObject{
                    {"date", v.toString()}, {"state", "used"}, {"sent", false}
                });
            }
        }
        m_data["dayMarks"] = marks;
    }
    if (!m_data.contains("shareRecipientName")) m_data["shareRecipientName"] = "";
    if (!m_data.contains("shareRecipientEmail")) m_data["shareRecipientEmail"] = "";
    if (!m_data.contains("shareSenderEmail")) m_data["shareSenderEmail"] = "";

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
    loadEmptyData();
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

void DataCenter::setDayMark(const QString &isoDate, const QString &state) {
    QJsonArray marks = m_data["dayMarks"].toArray();
    QJsonArray filtered;
    for (const auto &v : marks) {
        if (v.toObject().value("date").toString() != isoDate) {
            filtered.append(v);
        }
    }
    filtered.append(QJsonObject{{"date", isoDate}, {"state", state}, {"sent", false}});
    m_data["dayMarks"] = filtered;
    save();
    emit dataChanged();
}

void DataCenter::clearDayMark(const QString &isoDate) {
    QJsonArray marks = m_data["dayMarks"].toArray();
    QJsonArray filtered;
    for (const auto &v : marks) {
        if (v.toObject().value("date").toString() != isoDate) {
            filtered.append(v);
        }
    }
    m_data["dayMarks"] = filtered;
    save();
    emit dataChanged();
}

void DataCenter::setDaySent(const QString &isoDate, bool sent) {
    QJsonArray marks = m_data["dayMarks"].toArray();
    QJsonArray updated;
    for (const auto &v : marks) {
        QJsonObject obj = v.toObject();
        if (obj.value("date").toString() == isoDate) {
            obj["sent"] = sent;
        }
        updated.append(obj);
    }
    m_data["dayMarks"] = updated;
    save();
    emit dataChanged();
}

int DataCenter::dayMarkCount(int year, const QString &state) const {
    const QString prefix = QString::number(year) + "-";
    const QJsonArray marks = m_data.value("dayMarks").toArray();
    int count = 0;
    for (const auto &v : marks) {
        QJsonObject obj = v.toObject();
        if (obj.value("date").toString().startsWith(prefix)
            && obj.value("state").toString() == state) {
            count++;
        }
    }
    return count;
}

void DataCenter::setShareContact(const QString &recipientName,
                                   const QString &recipientEmail,
                                   const QString &senderEmail) {
    m_data["shareRecipientName"] = recipientName;
    m_data["shareRecipientEmail"] = recipientEmail;
    m_data["shareSenderEmail"] = senderEmail;
    save();
    emit dataChanged();
}

QJsonArray DataCenter::dayMarksForYear(int year) const {
    const QString prefix = QString::number(year) + "-";
    const QJsonArray marks = m_data.value("dayMarks").toArray();
    QList<QJsonValue> filtered;
    for (const auto &v : marks) {
        if (v.toObject().value("date").toString().startsWith(prefix)) {
            filtered.append(v);
        }
    }
    std::sort(filtered.begin(), filtered.end(), [](const QJsonValue &a, const QJsonValue &b) {
        return a.toObject().value("date").toString() < b.toObject().value("date").toString();
    });
    QJsonArray result;
    for (const auto &v : filtered) {
        result.append(v);
    }
    return result;
}
