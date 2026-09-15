import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

// Full-screen "Planificar" view: a brush-based calendar to mark days as
// planned / confirmed / used, per year (years never share a balance —
// switching the year tab switches which year's marks and budget you see).
Page {
    id: root
    property var dataCenter
    property var holidayProvider
    property var clipboard
    property var exporter
    signal back()

    background: Rectangle { color: Style.background }

    readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var weekdaysShort: ["L", "M", "X", "J", "V", "S", "D"]
    readonly property int realYear: new Date().getFullYear()
    readonly property int realMonth: new Date().getMonth()
    readonly property int realDay: new Date().getDate()
    readonly property int nextYear: realYear + 1

    property int calYear: realYear
    property int month: realMonth
    property string brush: "planned"
    property string highlightKey: ""
    property bool shareOpen: true

    readonly property var dayStates: ({
        used: { color: Style.textSecondary, label: "Gastados" },
        confirmed: { color: Style.primary, label: "Confirmados" },
        planned: { color: Style.accent, label: "Planeados" }
    })
    readonly property var stateOrder: ["used", "confirmed", "planned"]

    readonly property int totalDays: dataCenter ? dataCenter.data.totalVacationDays : 0
    readonly property int usedCountYear: (dataCenter && dataCenter.data) ? dataCenter.dayMarkCount(calYear, "used") : 0
    readonly property int confirmedCountYear: (dataCenter && dataCenter.data) ? dataCenter.dayMarkCount(calYear, "confirmed") : 0
    readonly property int plannedCountYear: (dataCenter && dataCenter.data) ? dataCenter.dayMarkCount(calYear, "planned") : 0
    readonly property int availableCountYear: totalDays - usedCountYear - confirmedCountYear - plannedCountYear

    // Rows for the share sheet (email body / CSV / ICS / PDF): each
    // planned day, tagged with its holiday scope if it happens to land on
    // one, "personal" otherwise.
    readonly property var plannedRows: root.yearMarks
        .filter(function(m) { return m.state === "planned" })
        .map(function(m) {
            var h = root.holidayForDate(m.date)
            return { date: m.date, estado: m.state, ambito: h ? h.scope : "personal" }
        })
    // Reading dataCenter.data (which does emit dataChanged) inside these
    // bindings is what makes them re-run whenever a mark is added/removed —
    // the Q_INVOKABLE calls themselves aren't observable properties.
    readonly property var yearMarks: (dataCenter && dataCenter.data) ? dataCenter.dayMarksForYear(root.calYear) : []
    readonly property var holidaysThisYear: (holidayProvider && dataCenter && dataCenter.data) ? holidayProvider.loadCachedHolidays(root.calYear) : []

    function isoFor(day, month, year) {
        return year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }
    function markFor(iso) {
        for (var i = 0; i < root.yearMarks.length; i++) {
            if (root.yearMarks[i].date === iso) return root.yearMarks[i]
        }
        return null
    }
    function holidayForDate(iso) {
        for (var i = 0; i < root.holidaysThisYear.length; i++) {
            if (root.holidaysThisYear[i].date === iso) return root.holidaysThisYear[i]
        }
        return null
    }
    function dotColorFor(scope) {
        if (scope === "nacional") return Style.scopeColor("nacional")
        if (scope === "autonomico" || scope === "regional") return Style.scopeColor("autonomico")
        return Style.scopeColor("manual")
    }
    function holidayTintBg(scope) {
        var c = Qt.color(root.dotColorFor(scope))
        return Qt.rgba(c.r, c.g, c.b, 0.15)
    }
    function holidayTintBorder(scope) {
        var c = Qt.color(root.dotColorFor(scope))
        return Qt.rgba(c.r, c.g, c.b, 0.33)
    }
    function isWeekend(day, month, year) {
        var dow = new Date(year, month, day).getDay()
        return dow === 0 || dow === 6
    }
    function shortChipLabel(dm) {
        return dm.day + " " + root.months[dm.month].slice(0, 3) + (dm.year !== root.realYear ? " '" + String(dm.year).slice(2) : "")
    }

    // Same isoluminant-ish hue rotation as OnboardingUsedDaysPage's
    // monthColors (oklch(58% 0.10 hue) approximated with HSL, which QML
    // supports natively) — kept identical so a given month reads as the
    // same color everywhere in the app, not a separate ad-hoc palette.
    readonly property var monthColors: {
        var arr = []
        for (var i = 0; i < 12; i++) {
            var hue = ((160 + i * 32) % 360) / 360
            arr.push(Qt.hsla(hue, 0.38, 0.40, 1))
        }
        return arr
    }
    function monthDotColor(month) {
        return root.monthColors[month]
    }

    function calendarCells() {
        var y = root.calYear, m = root.month
        var first = new Date(y, m, 1)
        var lead = (first.getDay() + 6) % 7
        var days = new Date(y, m + 1, 0).getDate()
        var cells = []
        for (var i = 0; i < lead; i++) cells.push({ day: 0 })
        for (var d = 1; d <= days; d++) cells.push({ day: d })
        return cells
    }

    // Jumps to the year/month of a mark and briefly outlines that cell —
    // same pattern as OnboardingUsedDaysPage's goToDay.
    function goToDay(day, month, year) {
        root.calYear = year
        root.month = month
        root.highlightKey = year + ":" + month + ":" + day
        highlightTimer.restart()
    }
    Timer {
        id: highlightTimer
        interval: 1400
        onTriggered: root.highlightKey = ""
    }

    Timer {
        id: ensureVisibleTimer
        property var targetItem: null
        interval: 60
        onTriggered: root.ensureVisible(targetItem)
    }
    function scheduleEnsureVisible(item) {
        ensureVisibleTimer.targetItem = item
        ensureVisibleTimer.restart()
    }
    function ensureVisible(item) {
        if (!item) return
        var flick = scrollView
        var pad = 16
        var pos = item.mapToItem(flick, 0, 0)
        var itemTop = pos.y
        var target = Math.max(0, Math.min(flick.contentY + itemTop - pad,
                                           Math.max(0, flick.contentHeight - flick.height)))
        scrollAnimation.to = target
        scrollAnimation.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: Style.smallSpace }

        // Header: back, title, year tabs
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.mediumMargin
            Layout.rightMargin: Style.mediumMargin
            Layout.bottomMargin: 10
            spacing: 10

            Button {
                opacity: pressed ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                implicitWidth: 32; implicitHeight: 32
                background: Rectangle { color: "transparent" }
                contentItem: Image {
                    anchors.centerIn: parent
                    source: Style.icon("chevron-right")
                    width: 19; height: 19
                    sourceSize: Qt.size(19, 19)
                    rotation: 180
                }
                onClicked: root.back()
            }
            Text {
                text: "Planificar"
                font.family: Style.fontFamily
                font.pixelSize: Style.heading2
                font.weight: Font.Bold
                color: Style.text
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: yearTabsRow.implicitWidth + 6
                implicitHeight: yearTabsRow.implicitHeight + 6
                radius: 999
                color: "#F1EBE0"

                RowLayout {
                    id: yearTabsRow
                    anchors.centerIn: parent
                    spacing: 2

                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        implicitHeight: 28
                        implicitWidth: calYearAText.implicitWidth + 26
                        background: Rectangle {
                            radius: 999
                            color: root.calYear === root.realYear ? Style.surface : "transparent"
                            layer.enabled: root.calYear === root.realYear
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                        }
                        contentItem: Text {
                            id: calYearAText
                            text: String(root.realYear)
                            font.family: Style.fontFamily
                            font.pixelSize: Style.caption
                            font.weight: Font.Bold
                            color: root.calYear === root.realYear ? Style.primary : Style.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: { root.calYear = root.realYear; root.month = root.realMonth }
                    }
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        implicitHeight: 28
                        implicitWidth: calYearBText.implicitWidth + 26
                        background: Rectangle {
                            radius: 999
                            color: root.calYear === root.nextYear ? Style.surface : "transparent"
                            layer.enabled: root.calYear === root.nextYear
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                        }
                        contentItem: Text {
                            id: calYearBText
                            text: String(root.nextYear)
                            font.family: Style.fontFamily
                            font.pixelSize: Style.caption
                            font.weight: Font.Bold
                            color: root.calYear === root.nextYear ? Style.primary : Style.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: { root.calYear = root.nextYear; root.month = 0 }
                    }
                }
            }
        }

        // Month nav + brush selector
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.mediumMargin
            Layout.rightMargin: Style.mediumMargin
            Layout.bottomMargin: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitWidth: 34; implicitHeight: 34
                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                    contentItem: Image { anchors.centerIn: parent; source: Style.icon("chevron-right"); width: 16; height: 16; sourceSize: Qt.size(16, 16); rotation: 180 }
                    onClicked: root.month = (root.month + 11) % 12
                }
                Text {
                    Layout.fillWidth: true
                    text: root.months[root.month][0].toUpperCase() + root.months[root.month].slice(1) + " " + root.calYear
                    font.family: Style.fontFamily
                    font.pixelSize: Style.body
                    font.weight: Font.Bold
                    font.letterSpacing: -0.3
                    color: root.monthColors[root.month]
                    horizontalAlignment: Text.AlignHCenter
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitWidth: 34; implicitHeight: 34
                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                    contentItem: Image { anchors.centerIn: parent; source: Style.icon("chevron-right"); width: 16; height: 16; sourceSize: Qt.size(16, 16) }
                    onClicked: root.month = (root.month + 1) % 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: root.stateOrder
                    delegate: Button {
                        id: brushButton
                        required property string modelData
                        readonly property bool active: root.brush === modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        background: Rectangle {
                            radius: 999
                            color: brushButton.active ? root.dayStates[brushButton.modelData].color : Style.surface
                            border.color: brushButton.active ? root.dayStates[brushButton.modelData].color : Style.divider
                            border.width: 1
                        }
                        contentItem: Item {
                            implicitWidth: brushRow.implicitWidth
                            implicitHeight: brushRow.implicitHeight
                            Row {
                                id: brushRow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8; height: 8; radius: 4
                                    color: brushButton.active ? Qt.rgba(1, 1, 1, 0.85) : root.dayStates[brushButton.modelData].color
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.dayStates[brushButton.modelData].label.slice(0, -1)
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: brushButton.active ? "white" : Style.textSecondary
                                }
                            }
                        }
                        onClicked: root.brush = brushButton.modelData
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

        Flickable {
            id: scrollView
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: pageColumn.implicitHeight
            boundsBehavior: Flickable.DragOverBounds
            interactive: contentHeight > height

            ScrollBar.vertical: ScrollBar {}

            NumberAnimation {
                id: scrollAnimation
                target: scrollView
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            ColumnLayout {
                id: pageColumn
                width: root.width
                spacing: 14

                // Sin confirmar
                ColumnLayout {
                    id: plannedSection
                    visible: plannedList.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 9

                    readonly property var plannedList: root.yearMarks.filter(function(m) { return m.state === "planned" })
                    readonly property bool anySent: plannedList.some(function(m) { return m.sent })

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: plannedSection.anySent ? "Pendiente de aprobación" : "Sin confirmar"
                            font.family: Style.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Style.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            implicitHeight: 30
                            implicitWidth: confirmAllRow.implicitWidth + 22
                            background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                            contentItem: Item {
                                implicitWidth: confirmAllRow.implicitWidth
                                implicitHeight: confirmAllRow.implicitHeight
                                Row {
                                    id: confirmAllRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image { anchors.verticalCenter: parent.verticalCenter; source: Style.icon("check"); width: 13; height: 13; sourceSize: Qt.size(13, 13) }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Aprobar los " + plannedSection.plannedList.length
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: Style.primary
                                    }
                                }
                            }
                            onClicked: {
                                // Snapshot first: each setDayMark() emits
                                // dataChanged(), which makes plannedList
                                // re-evaluate mid-loop (it's a live filter
                                // over yearMarks) — iterating the live list
                                // directly skipped entries as it shrank.
                                var list = plannedSection.plannedList.slice()
                                for (var i = 0; i < list.length; i++) {
                                    root.dataCenter.setDayMark(list[i].date, "confirmed")
                                }
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: plannedSection.plannedList
                            delegate: Rectangle {
                                id: plannedChip
                                required property var modelData
                                readonly property var dm: {
                                    var p = modelData.date.split("-")
                                    return { year: parseInt(p[0]), month: parseInt(p[1]) - 1, day: parseInt(p[2]) }
                                }
                                readonly property bool isHl: root.highlightKey === (dm.year + ":" + dm.month + ":" + dm.day)

                                radius: 999
                                color: modelData.sent ? "#C9553A" : Style.accent
                                implicitHeight: 28
                                implicitWidth: monthDot.width + 6 + chipLabel.implicitWidth + 16 + 22 + 6
                                border.width: isHl ? 2.5 : 0
                                border.color: Style.text

                                Item {
                                    id: labelArea
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: monthDot.width + 6 + chipLabel.implicitWidth
                                    implicitHeight: chipLabel.implicitHeight
                                    opacity: labelTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }

                                    Rectangle {
                                        id: monthDot
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7; height: 7; radius: 3.5
                                        color: root.monthDotColor(plannedChip.dm.month)
                                    }
                                    Text {
                                        id: chipLabel
                                        anchors.left: monthDot.right
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.shortChipLabel(plannedChip.dm)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "white"
                                    }
                                    TapHandler { id: labelTap; onTapped: root.goToDay(plannedChip.dm.day, plannedChip.dm.month, plannedChip.dm.year) }
                                }
                                Rectangle {
                                    id: approveButton
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22; radius: 999
                                    color: "white"
                                    opacity: approveTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                    Image {
                                        anchors.centerIn: parent
                                        source: Style.icon("check")
                                        width: 13; height: 13
                                        sourceSize: Qt.size(13, 13)
                                    }
                                    TapHandler { id: approveTap; onTapped: root.dataCenter.setDayMark(plannedChip.modelData.date, "confirmed") }
                                }
                            }
                        }
                    }
                }

                // Calendar grid card
                Rectangle {
                    id: gridCard
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: gridCol.implicitHeight + 32
                    radius: Style.listRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }

                    ColumnLayout {
                        id: gridCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 13

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: dayGrid.implicitHeight

                            Grid {
                                id: dayGrid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                columns: 7
                                rowSpacing: 4
                                columnSpacing: 4

                                Repeater {
                                    model: root.weekdaysShort
                                    delegate: Text {
                                        required property string modelData
                                        width: (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                                        height: 18
                                        text: modelData
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
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
                                        height: 40

                                        readonly property string iso: modelData.day > 0 ? root.isoFor(modelData.day, root.month, root.calYear) : ""
                                        readonly property var holiday: modelData.day > 0 ? root.holidayForDate(iso) : null
                                        readonly property var mark: modelData.day > 0 ? root.markFor(iso) : null
                                        readonly property bool weekend: modelData.day > 0 && root.isWeekend(modelData.day, root.month, root.calYear)
                                        readonly property bool isToday: modelData.day > 0 && root.calYear === root.realYear && root.month === root.realMonth && modelData.day === root.realDay
                                        readonly property bool isHighlighted: modelData.day > 0 && root.highlightKey === (root.calYear + ":" + root.month + ":" + modelData.day)

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: dayCell.modelData.day > 0
                                            radius: 12
                                            color: dayCell.mark ? root.dayStates[dayCell.mark.state].color
                                                   : dayCell.holiday ? root.holidayTintBg(dayCell.holiday.scope)
                                                   : dayCell.weekend ? "#F4EFE5"
                                                   : Style.background
                                            border.color: dayCell.isHighlighted ? Style.text
                                                   : dayCell.mark ? root.dayStates[dayCell.mark.state].color
                                                   : dayCell.holiday ? root.holidayTintBorder(dayCell.holiday.scope)
                                                   : "#EFEADF"
                                            border.width: dayCell.isHighlighted ? 2.5 : 1

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 12
                                                color: "transparent"
                                                border.width: 2
                                                border.color: Style.text
                                                visible: dayCell.isToday && !dayCell.mark && !dayCell.isHighlighted
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: dayCell.modelData.day
                                                font.family: Style.fontFamily
                                                font.pixelSize: 14
                                                font.weight: (dayCell.mark || dayCell.holiday) ? Font.Bold : Font.Medium
                                                color: dayCell.mark ? "white"
                                                       : dayCell.holiday ? root.dotColorFor(dayCell.holiday.scope)
                                                       : dayCell.weekend ? "#B9C2C4" : Style.text
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: dayGrid
                                preventStealing: true
                                property bool dragAdd: true
                                readonly property real headerRowHeight: 18 + dayGrid.rowSpacing

                                function cellDayAt(mx, my) {
                                    var cellW = (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                                    var col = Math.floor(mx / (cellW + dayGrid.columnSpacing))
                                    var row = Math.floor((my - headerRowHeight) / (40 + dayGrid.rowSpacing))
                                    if (col < 0 || col > 6 || row < 0) return -1
                                    var idx = row * 7 + col
                                    var cells = root.calendarCells()
                                    if (idx < 0 || idx >= cells.length) return -1
                                    return cells[idx].day
                                }

                                function applyAt(mx, my, decideMode) {
                                    var day = cellDayAt(mx, my)
                                    if (day <= 0) return
                                    var iso = root.isoFor(day, root.month, root.calYear)
                                    var holiday = root.holidayForDate(iso)
                                    var mark = root.markFor(iso)
                                    var weekend = root.isWeekend(day, root.month, root.calYear)
                                    var locked = !!holiday || (weekend && !mark)
                                    if (locked) return
                                    if (decideMode) dragArea.dragAdd = !mark || mark.state !== root.brush
                                    if (dragArea.dragAdd) root.dataCenter.setDayMark(iso, root.brush)
                                    else root.dataCenter.clearDayMark(iso)
                                }

                                onPressed: (mouse) => applyAt(mouse.x, mouse.y, true)
                                onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x, mouse.y, false) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 12

                            Repeater {
                                model: [
                                    { label: "Planeado", color: Style.accent },
                                    { label: "Confirmado", color: Style.primary },
                                    { label: "Gastado", color: Style.textSecondary },
                                    { label: "Festivo", color: Style.scopeColor("manual") },
                                    { label: "Hoy", color: Style.text }
                                ]
                                delegate: RowLayout {
                                    required property var modelData
                                    spacing: 5
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: modelData.color }
                                    Text { text: modelData.label; font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // Summary card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: summaryCol.implicitHeight + 32
                    radius: Style.cardRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }

                    ColumnLayout {
                        id: summaryCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 11

                        Text {
                            text: "Resumen " + root.calYear
                            font.family: Style.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Style.text
                        }

                        Repeater {
                            model: [
                                { key: "used", value: root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "used") : 0 },
                                { key: "confirmed", value: root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "confirmed") : 0 },
                                { key: "planned", value: root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "planned") : 0 }
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle { width: 9; height: 9; radius: 4.5; color: root.dayStates[modelData.key].color }
                                Text { Layout.fillWidth: true; text: root.dayStates[modelData.key].label; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.text }
                                Text { text: modelData.value; font.family: Style.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: root.dayStates[modelData.key].color }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            readonly property int available: Math.max(0, root.totalDays
                                - (root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "used") : 0)
                                - (root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "confirmed") : 0)
                                - (root.dataCenter ? root.dataCenter.dayMarkCount(root.calYear, "planned") : 0))
                            Rectangle { width: 9; height: 9; radius: 4.5; color: "#DCD5C7" }
                            Text { Layout.fillWidth: true; text: "Disponibles"; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.text }
                            Text { text: parent.available; font.family: Style.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Style.text }
                        }
                    }
                }

                // Confirmados: at the very bottom, separate from the
                // calendar/brush area — purely a way to undo an approval
                // (clears the mark back to available), it doesn't change
                // how the calendar grid itself behaves.
                ColumnLayout {
                    id: confirmedSection
                    visible: confirmedList.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 9

                    readonly property var confirmedList: root.yearMarks.filter(function(m) { return m.state === "confirmed" })

                    Text {
                        text: "Confirmados"
                        font.family: Style.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Style.textSecondary
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: confirmedSection.confirmedList
                            delegate: Rectangle {
                                id: confirmedChip
                                required property var modelData
                                readonly property var dm: {
                                    var p = modelData.date.split("-")
                                    return { year: parseInt(p[0]), month: parseInt(p[1]) - 1, day: parseInt(p[2]) }
                                }
                                readonly property bool isHl: root.highlightKey === (dm.year + ":" + dm.month + ":" + dm.day)

                                radius: 999
                                color: Style.primary
                                implicitHeight: 28
                                implicitWidth: confirmedDot.width + 6 + confirmedLabel.implicitWidth + 16 + 22 + 6
                                border.width: isHl ? 2.5 : 0
                                border.color: Style.text

                                Item {
                                    id: confirmedLabelArea
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: confirmedDot.width + 6 + confirmedLabel.implicitWidth
                                    implicitHeight: confirmedLabel.implicitHeight
                                    opacity: confirmedLabelTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }

                                    Rectangle {
                                        id: confirmedDot
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7; height: 7; radius: 3.5
                                        color: root.monthDotColor(confirmedChip.dm.month)
                                    }
                                    Text {
                                        id: confirmedLabel
                                        anchors.left: confirmedDot.right
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.shortChipLabel(confirmedChip.dm)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "white"
                                    }
                                    TapHandler { id: confirmedLabelTap; onTapped: root.goToDay(confirmedChip.dm.day, confirmedChip.dm.month, confirmedChip.dm.year) }
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22; radius: 999
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    opacity: cancelTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 12
                                        color: "white"
                                    }
                                    // Cancels the approval outright (clears
                                    // the mark back to available), rather
                                    // than demoting it back to "planned" —
                                    // matches the delete affordance already
                                    // used for used-day chips elsewhere.
                                    TapHandler { id: cancelTap; onTapped: root.dataCenter.clearDayMark(confirmedChip.modelData.date) }
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Style.smallSpace }
            }
        }

        // Bottom scroll-fade over the calendar/chips scroll area, same
        // gradual-opacity pattern as HomePage's — hints at more content
        // below without a hard cutoff right above the fixed bar.
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 52
            readonly property real remaining: scrollView.contentHeight - scrollView.contentY - scrollView.height
            opacity: Math.max(0, Math.min(1, (remaining - 4) / 70))
            Behavior on opacity { NumberAnimation { duration: 250 } }
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0.122, 0.165, 0.18, 0.07) }
                GradientStop { position: 1.0; color: Qt.rgba(0.122, 0.165, 0.18, 0.18) }
            }
        }
        }

        // Fixed bottom bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bottomRow.implicitHeight + 30
            color: Style.background

            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                height: 1
                color: Style.divider
            }

            RowLayout {
                id: bottomRow
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: Style.mediumMargin
                anchors.topMargin: 13
                spacing: 10

                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Layout.fillWidth: true
                    implicitHeight: 52
                    background: Rectangle { radius: 999; color: Style.primary }
                    contentItem: Text {
                        text: "Guardar"
                        font.family: Style.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.back()
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    implicitHeight: 52
                    implicitWidth: shareRow.implicitWidth + 40
                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                    contentItem: Item {
                        implicitWidth: shareRow.implicitWidth
                        implicitHeight: shareRow.implicitHeight
                        Row {
                            id: shareRow
                            anchors.centerIn: parent
                            spacing: 8
                            Image { anchors.verticalCenter: parent.verticalCenter; source: Style.icon("share"); width: 17; height: 17; sourceSize: Qt.size(17, 17) }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Enviar"
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Style.primary
                            }
                        }
                    }
                    onClicked: root.shareOpen = true
                }
            }
        }
    }

    ShareModal {
        anchors.fill: parent
        open: root.shareOpen
        dataCenter: root.dataCenter
        clipboard: root.clipboard
        exporter: root.exporter
        calYear: root.calYear
        months: root.months
        plannedRows: root.plannedRows
        holidaysThisYear: root.holidaysThisYear
        location: [root.dataCenter && root.dataCenter.data ? root.dataCenter.data.municipioName : "",
                   root.dataCenter && root.dataCenter.data ? root.dataCenter.data.ccaaName : ""].filter(function(s) { return s && s.length > 0 }).join(", ")
        totalDays: root.totalDays
        usedCount: root.usedCountYear
        confirmedCount: root.confirmedCountYear
        plannedCount: root.plannedCountYear
        availableCount: root.availableCountYear
        onClosed: root.shareOpen = false
    }
}
