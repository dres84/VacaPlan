#ifndef EXPORTER_H
#define EXPORTER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

// Writes the planned/confirmed/used days to a real file in the user's
// Downloads folder. No network involved — "exportar" means a local file,
// "enviar por email" (in ShareModal.qml) opens a mailto: draft instead.
class Exporter : public QObject
{
    Q_OBJECT

public:
    explicit Exporter(QObject *parent = nullptr);

    // Each row in `rows` is a map with "date" (YYYY-MM-DD), "estado" and
    // "ambito" keys, already resolved on the QML side. Returns the saved
    // file path, or an empty string if the file could not be written.
    // `holidays` (date + scope maps) are appended as extra "festivo" rows,
    // CSV only — the planned-days list stays holiday-free everywhere else.
    Q_INVOKABLE QString exportCsv(const QVariantList &rows, const QVariantList &holidays, int year);
    Q_INVOKABLE QString exportIcs(const QVariantList &rows, int year);
    // `summary` carries the PDF header/breakdown: "location" plus the
    // used/confirmed/planned/available day counts.
    Q_INVOKABLE QString exportPdf(const QVariantList &rows, const QVariantMap &summary, int year);

private:
    QString downloadPath(const QString &filename) const;
    static QString translateEstado(const QString &estado);
    static QString translateAmbito(const QString &ambito);
};

#endif // EXPORTER_H
