#ifndef DATACENTER_H
#define DATACENTER_H

#include <QObject>
#include <QJsonObject>

class DataCenter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QJsonObject data READ data NOTIFY dataChanged)

public:
    explicit DataCenter(QObject *parent = nullptr);

    QJsonObject data() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void save();

    Q_INVOKABLE bool onboardingCompleted() const;
    Q_INVOKABLE void completeOnboarding();
    Q_INVOKABLE void resetOnboarding();

    // Step 1: location
    Q_INVOKABLE void setLocation(const QString &country,
                                  const QString &ccaaSlug, const QString &ccaaName,
                                  const QString &provinciaSlug, const QString &provinciaName,
                                  const QString &municipioSlug, const QString &municipioName);

    // Step 2: total vacation days
    Q_INVOKABLE void setTotalVacationDays(int days);

    // Step 3: days already used
    Q_INVOKABLE void setUsedVacationMode(const QString &mode); // "count" | "dates"
    Q_INVOKABLE void setUsedVacationCount(int count);
    Q_INVOKABLE void addUsedVacationDate(const QString &isoDate);
    Q_INVOKABLE void removeUsedVacationDate(const QString &isoDate);

    // Loose hours (less than a full day): stored separately, one entry
    // per date. Not yet factored into the used/remaining days
    // calculation.
    Q_INVOKABLE void addUsedVacationHours(const QString &isoDate, int hours);
    Q_INVOKABLE void removeUsedVacationHours(const QString &isoDate);

signals:
    void dataChanged();

private:
    QString getFilePath() const;
    QJsonObject m_data;
    void loadEmptyData();
};

#endif // DATACENTER_H
