import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

// Manual holidays editor: a single persistent calendar (not a picker
// hidden behind a button) where tapping a day adds it directly to the
// list below — the same direct-manipulation pattern used everywhere else
// in the app (OnboardingUsedDaysPage, PlanCalendarPage), instead of a
// separate "add row, then open its own picker" flow. Already-known
// holidays and weekends are shown so it's obvious what's already covered.
ColumnLayout {
    id: root
    property int year: 2026
    property var holidayProvider
    signal saved()

    readonly property var months: [qsTr("enero"), qsTr("febrero"), qsTr("marzo"), qsTr("abril"), qsTr("mayo"), qsTr("junio"),
        qsTr("julio"), qsTr("agosto"), qsTr("septiembre"), qsTr("octubre"), qsTr("noviembre"), qsTr("diciembre")]
    readonly property var weekdays: [qsTr("L"), qsTr("M"), qsTr("X"), qsTr("J"), qsTr("V"), qsTr("S"), qsTr("D")]

    spacing: Style.smallSpace

    property int pickerMonth: (root.year === new Date().getFullYear()) ? new Date().getMonth() : 0
    property string highlightKey: ""

    ListModel { id: entriesModel }

    readonly property var knownHolidays: root.holidayProvider ? root.holidayProvider.loadCachedHolidays(root.year) : []

    function isoFor(day, month) {
        return root.year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }
    function fullLabel(iso) {
        var p = iso.split("-")
        return qsTr("%1 de %2", "day of month").arg(parseInt(p[2])).arg(root.months[parseInt(p[1]) - 1])
    }
    function holidayForDate(iso) {
        for (var i = 0; i < root.knownHolidays.length; i++) {
            if (root.knownHolidays[i].date === iso) return root.knownHolidays[i]
        }
        return null
    }
    function entryIndexFor(iso) {
        for (var i = 0; i < entriesModel.count; i++) {
            if (entriesModel.get(i).date === iso) return i
        }
        return -1
    }
    function holidayTintBg(scope) {
        return Style.withAlpha(Style.scopeColor(scope), 0.16863) // fill + 2b (17%)
    }
    function holidayTintBorder(scope) {
        return Style.withAlpha(Style.scopeColor(scope), 0.34902) // fill + 59 (35%)
    }

    function toggleDay(day, month) {
        var iso = root.isoFor(day, month)
        if (root.holidayForDate(iso)) return // already a known holiday, nothing to add
        var idx = root.entryIndexFor(iso)
        if (idx !== -1) entriesModel.remove(idx)
        else entriesModel.append({ date: iso, name: qsTr("Festivo local") })
    }

    function calendarCells() {
        var first = new Date(root.year, root.pickerMonth, 1)
        var lead = (first.getDay() + 6) % 7
        var days = new Date(root.year, root.pickerMonth + 1, 0).getDate()
        var cells = []
        for (var i = 0; i < lead; i++) cells.push({ day: 0 })
        for (var d = 1; d <= days; d++) cells.push({ day: d })
        return cells
    }

    Text {
        text: qsTr("Festivos de %1").arg(root.year)
        font.family: Style.fontFamily
        font.pixelSize: Style.semi
        font.weight: Font.Bold
        color: Style.text
    }
    Text {
        Layout.fillWidth: true
        text: qsTr("Toca un día para añadirlo. Los festivos ya conocidos y los fines de semana se marcan para que no se te dupliquen.")
        font.family: Style.fontFamily
        font.pixelSize: 12
        color: Style.textSecondary
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: calCol.implicitHeight + 24
        radius: 16
        color: Style.background
        border.color: Style.divider
        border.width: 1

        ColumnLayout {
            id: calCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitWidth: 28; implicitHeight: 28
                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                    contentItem: Image {
                        anchors.centerIn: parent
                        source: Style.icon("chevron-right")
                        width: 15; height: 15
                        sourceSize: Qt.size(15, 15)
                        rotation: 180
                    }
                    onClicked: root.pickerMonth = (root.pickerMonth + 11) % 12
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("%1 de %2", "month of year").arg(root.months[root.pickerMonth]).arg(root.year)
                    font.family: Style.fontFamily
                    font.pixelSize: Style.semi
                    font.weight: Font.Bold
                    color: Style.text
                    horizontalAlignment: Text.AlignHCenter
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitWidth: 28; implicitHeight: 28
                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                    contentItem: Image {
                        anchors.centerIn: parent
                        source: Style.icon("chevron-right")
                        width: 15; height: 15
                        sourceSize: Qt.size(15, 15)
                    }
                    onClicked: root.pickerMonth = (root.pickerMonth + 1) % 12
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: dayGrid.implicitHeight

                // Plain Grid, not GridLayout: GridLayout sizes each column
                // from its items' Layout.fillWidth, which can misalign
                // columns once two separate Repeaters (weekdays + day
                // cells) feed into the same grid. A Grid with each cell's
                // width fixed to gridWidth/7 sidesteps that entirely.
                Grid {
                    id: dayGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    columns: 7
                    rowSpacing: 3
                    columnSpacing: 3

                    Repeater {
                        model: root.weekdays
                        delegate: Text {
                            required property string modelData
                            width: (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Style.fontFamily
                            font.pixelSize: 10
                            color: Style.textSecondary
                        }
                    }

                    Repeater {
                        model: root.calendarCells()
                        delegate: Item {
                            id: dayCell
                            required property var modelData
                            width: (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                            height: 32

                            readonly property string iso: modelData.day > 0 ? root.isoFor(modelData.day, root.pickerMonth) : ""
                            readonly property var holiday: modelData.day > 0 ? root.holidayForDate(iso) : null
                            readonly property bool isAdded: modelData.day > 0 && root.entryIndexFor(iso) !== -1
                            readonly property bool isWeekend: modelData.day > 0 && [0, 6].indexOf(new Date(root.year, root.pickerMonth, modelData.day).getDay()) !== -1

                            Rectangle {
                                anchors.fill: parent
                                visible: dayCell.modelData.day > 0
                                radius: 9
                                color: dayCell.isAdded ? Style.primary
                                       : dayCell.holiday ? root.holidayTintBg(dayCell.holiday.scope)
                                       : dayCell.isWeekend ? Style.weekend
                                       : Style.surface
                                border.color: dayCell.isAdded ? Style.primary
                                       : dayCell.holiday ? root.holidayTintBorder(dayCell.holiday.scope)
                                       : Style.divider
                                border.width: 1
                                opacity: dayTap.pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.modelData.day
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: (dayCell.isAdded || dayCell.holiday) ? Font.Bold : Font.Medium
                                    color: dayCell.isAdded ? "white"
                                           : dayCell.holiday ? Style.scopeInk(dayCell.holiday.scope)
                                           : dayCell.isWeekend ? Style.textGhost : Style.text
                                }
                                TapHandler {
                                    id: dayTap
                                    enabled: !dayCell.holiday
                                    onTapped: root.toggleDay(dayCell.modelData.day, root.pickerMonth)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12
                RowLayout {
                    spacing: 5
                    Rectangle { width: 8; height: 8; radius: 4; color: Style.primary }
                    Text { text: qsTr("Añadido"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                }
                RowLayout {
                    spacing: 5
                    Rectangle { width: 8; height: 8; radius: 4; color: Style.scopeColor("nacional") }
                    Text { text: qsTr("Ya conocido"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                }
                RowLayout {
                    spacing: 5
                    Rectangle { width: 8; height: 8; radius: 4; color: Style.textGhost }
                    Text { text: qsTr("Fin de semana"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    ColumnLayout {
        visible: entriesModel.count > 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0

        Repeater {
            model: entriesModel
            delegate: RowLayout {
                id: entryRow
                required property int index
                required property string date
                required property string name

                Layout.fillWidth: true
                Layout.topMargin: entryRow.index === 0 ? 0 : 8
                spacing: 10

                Text {
                    text: root.fullLabel(entryRow.date)
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Style.text
                }
                TextField {
                    Layout.fillWidth: true
                    text: entryRow.name
                    placeholderText: qsTr("Nombre del festivo")
                    placeholderTextColor: Style.textFaint
                    color: Style.text
                    font.family: Style.fontFamily
                    background: Rectangle {
                        radius: Style.mediumRadius
                        color: Style.sunken
                        border.color: Style.divider
                        border.width: 1
                    }
                    onTextEdited: entriesModel.setProperty(entryRow.index, "name", text)
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitWidth: 26; implicitHeight: 26
                    background: Rectangle { color: "transparent" }
                    contentItem: Text { text: "✕"; font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textDisabled; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: entriesModel.remove(entryRow.index)
                }
            }
        }
    }

    Text {
        visible: entriesModel.count === 0
        text: qsTr("Añade al menos un festivo local tocando un día en el calendario de arriba.")
        color: Style.textSecondary
        font.family: Style.fontFamily
        font.pixelSize: Style.caption
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Button {
        opacity: pressed ? 0.6 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Layout.topMargin: 4
        implicitHeight: 38
        implicitWidth: saveLabel.implicitWidth + 34
        enabled: entriesModel.count > 0
        background: Rectangle { radius: 999; color: parent.enabled ? Style.primary : Style.primaryDisabled }
        contentItem: Text {
            id: saveLabel
            text: qsTr("Guardar %1").arg(root.year)
            font.family: Style.fontFamily
            font.pixelSize: Style.caption
            font.weight: Font.Bold
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
            var newEntries = []
            for (var i = 0; i < entriesModel.count; i++) {
                var item = entriesModel.get(i)
                newEntries.push({ date: item.date, name: item.name || qsTr("Festivo local"), scope: "manual" })
            }
            // Merged with whatever was already cached (official holidays
            // already fetched, or previous manual entries) instead of
            // overwriting: this editor is also used to complete a calendar
            // that already loaded fine but is missing local holidays, not
            // just for the total-failure case.
            var existing = root.holidayProvider.loadCachedHolidays(root.year)
            var seenDates = {}
            var combined = []
            for (var e = 0; e < existing.length; e++) {
                combined.push(existing[e])
                seenDates[existing[e].date] = true
            }
            for (var n = 0; n < newEntries.length; n++) {
                if (!seenDates[newEntries[n].date]) {
                    combined.push(newEntries[n])
                    seenDates[newEntries[n].date] = true
                }
            }
            root.holidayProvider.saveManualHolidays(root.year, combined)
            root.saved()
        }
    }
}
