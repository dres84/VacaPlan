#include "exporter.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QVariantMap>
#include <QDateTime>
#include <QDate>
#include <QUuid>
#include <QPdfWriter>
#include <QPageSize>
#include <QPainter>

Exporter::Exporter(QObject *parent) : QObject(parent) {
}

QString Exporter::downloadPath(const QString &filename) const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    QDir().mkpath(dir);
    return dir + "/" + filename;
}

QString Exporter::translateEstado(const QString &estado) {
    if (estado == "planned") return "planeado";
    if (estado == "confirmed") return "confirmado";
    if (estado == "used") return "gastado";
    return estado;
}

QString Exporter::translateAmbito(const QString &ambito) {
    if (ambito == "personal") return "vacaciones";
    return ambito;
}

QString Exporter::exportCsv(const QVariantList &rows, const QVariantList &holidays, int year) {
    QString path = downloadPath(QString("vacaplan-%1.csv").arg(year));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return QString();
    }

    // UTF-8 BOM so Excel doesn't mangle accented characters.
    file.write("\xEF\xBB\xBF");

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "fecha,estado,ambito\n";
    for (const QVariant &v : rows) {
        QVariantMap row = v.toMap();
        out << row.value("date").toString() << ","
            << translateEstado(row.value("estado").toString()) << ","
            << translateAmbito(row.value("ambito").toString()) << "\n";
    }
    for (const QVariant &v : holidays) {
        QVariantMap row = v.toMap();
        out << row.value("date").toString() << ","
            << "festivo" << ","
            << row.value("scope").toString() << "\n";
    }
    file.close();
    return path;
}

QString Exporter::exportIcs(const QVariantList &rows, int year) {
    QString path = downloadPath(QString("vacaplan-%1.ics").arg(year));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return QString();
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "BEGIN:VCALENDAR\r\n";
    out << "VERSION:2.0\r\n";
    out << "PRODID:-//Vacaplan//ES\r\n";

    const QString stamp = QDateTime::currentDateTimeUtc().toString("yyyyMMddTHHmmssZ");
    for (const QVariant &v : rows) {
        QVariantMap row = v.toMap();
        const QString date = row.value("date").toString(); // YYYY-MM-DD
        const QDate d = QDate::fromString(date, "yyyy-MM-dd");
        if (!d.isValid()) continue;

        QString startCompact = date;
        startCompact.remove('-');
        const QString endCompact = d.addDays(1).toString("yyyyMMdd");

        const QString estado = row.value("estado").toString();
        const QString status = estado == "confirmed" ? "CONFIRMED" : "TENTATIVE";

        out << "BEGIN:VEVENT\r\n";
        out << "UID:" << QUuid::createUuid().toString(QUuid::WithoutBraces) << "@vacaplan\r\n";
        out << "DTSTAMP:" << stamp << "\r\n";
        out << "DTSTART;VALUE=DATE:" << startCompact << "\r\n";
        out << "DTEND;VALUE=DATE:" << endCompact << "\r\n";
        out << "SUMMARY:Vacaciones (Vacaplan)\r\n";
        out << "STATUS:" << status << "\r\n";
        out << "END:VEVENT\r\n";
    }
    out << "END:VCALENDAR\r\n";
    file.close();
    return path;
}

QString Exporter::exportPdf(const QVariantList &rows, const QVariantMap &summary, int year) {
    QString path = downloadPath(QString("vacaplan-%1.pdf").arg(year));

    QPdfWriter writer(path);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setResolution(150);

    QPainter painter;
    if (!painter.begin(&writer)) {
        return QString();
    }

    const int margin = 150;
    int y = margin;

    QFont titleFont("Helvetica", 18, QFont::Bold);
    painter.setFont(titleFont);
    painter.drawText(margin, y, QString("Vacaplan — Planificación %1").arg(year));
    y += 40;

    const QString location = summary.value("location").toString();
    if (!location.isEmpty()) {
        QFont locationFont("Helvetica", 11);
        painter.setFont(locationFont);
        painter.drawText(margin, y, location);
        y += 30;
    }
    y += 20;

    QFont breakdownFont("Helvetica", 11);
    painter.setFont(breakdownFont);
    const QString breakdown = QString("Gastados: %1   Confirmados: %2   Planeados: %3   Disponibles: %4")
        .arg(summary.value("used").toInt())
        .arg(summary.value("confirmed").toInt())
        .arg(summary.value("planned").toInt())
        .arg(summary.value("available").toInt());
    painter.drawText(margin, y, breakdown);
    y += 50;

    static const char *months[] = {"enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"};

    QFont sectionFont("Helvetica", 13, QFont::Bold);
    painter.setFont(sectionFont);
    painter.drawText(margin, y, "Días planeados");
    y += 40;

    QFont rowFont("Helvetica", 11);
    painter.setFont(rowFont);
    for (const QVariant &v : rows) {
        QVariantMap row = v.toMap();
        const QDate d = QDate::fromString(row.value("date").toString(), "yyyy-MM-dd");
        const QString longDate = d.isValid()
            ? QString("%1 de %2 de %3").arg(d.day()).arg(months[d.month() - 1]).arg(d.year())
            : row.value("date").toString();
        const QString line = QString("%1  (%2)").arg(longDate, translateEstado(row.value("estado").toString()));
        painter.drawText(margin, y, line);
        y += 36;
        if (y > writer.height() - margin) {
            writer.newPage();
            y = margin;
        }
    }
    painter.end();
    return path;
}
