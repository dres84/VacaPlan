import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

Page {
    id: root
    property var dataCenter
    property var holidayProvider
    signal restartOnboarding()
    signal openPlanner()

    background: Rectangle { color: Style.background }

    readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var monthAbbrs: ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    readonly property var monthLetters: ["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    readonly property var weekdaysDow: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]

    readonly property int currentYear: new Date().getFullYear()
    readonly property int nextYear: currentYear + 1
    property int selectedYear: currentYear

    property var profile: dataCenter ? dataCenter.data : ({})
    readonly property int totalDays: profile.totalVacationDays !== undefined ? profile.totalVacationDays : 0
    readonly property int markCount: profile.dayMarks ? profile.dayMarks.length : 0

    // Reading `profile` (bound to dataCenter.data, which does emit
    // dataChanged) inside these bindings is what makes them recompute
    // whenever a mark is added/removed from the Planificar screen — the
    // Q_INVOKABLE calls themselves aren't observable on their own.
    readonly property int usedFromMarks: (profile && dataCenter) ? dataCenter.dayMarkCount(currentYear, "used") : 0
    readonly property int usedFromCount: profile.usedVacationMode === "count" ? (profile.usedVacationCount || 0) : 0
    readonly property int usedCount: usedFromMarks + usedFromCount
    readonly property int confirmedCount: (profile && dataCenter) ? dataCenter.dayMarkCount(currentYear, "confirmed") : 0
    readonly property int plannedCount: (profile && dataCenter) ? dataCenter.dayMarkCount(currentYear, "planned") : 0
    // Not floored at 0: going over the total is a real, visible state
    // (shown in coral on the hero), not silently hidden.
    readonly property int availableCount: totalDays - usedCount - confirmedCount - plannedCount

    readonly property var heroCounts: ({ used: usedCount, confirmed: confirmedCount, planned: plannedCount, available: availableCount })
    readonly property var stateOrder: ["used", "confirmed", "planned", "available"]
    readonly property var stateLabels: ({ used: "Gastados", confirmed: "Confirmados", planned: "Planeados", available: "Disponibles" })
    readonly property var stateHints: ({
        used: "Ya disfrutados este año",
        confirmed: "Aprobados y en el calendario",
        planned: "Marcados pero todavía sin confirmar",
        available: "Libres para planificar lo que quede de año"
    })
    readonly property var heroBarColor: ({ used: "#0F4B4E", confirmed: "#FFFFFF", planned: Style.accent, available: Qt.rgba(1, 1, 1, 0.32) })

    property string focusState: "available"
    property int monthFilter: -1 // -1 = sin filtro
    property bool resetConfirmOpen: false

    property var holidaysList: []
    property bool showManualEditor: false

    function isoToday() {
        var d = new Date()
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function shortDate(iso) {
        if (!iso) return ""
        var parts = iso.split("-")
        var abbrs = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        return parseInt(parts[2]) + " " + abbrs[parseInt(parts[1]) - 1]
    }

    function fullDate(iso) {
        if (!iso) return ""
        var parts = iso.split("-")
        return parseInt(parts[2]) + " de " + root.months[parseInt(parts[1]) - 1]
    }

    function weekdayName(iso) {
        var p = iso.split("-")
        var dt = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        return weekdaysDow[dt.getDay()]
    }

    function nextInLabel(daysUntil) {
        if (daysUntil <= 0) return "Hoy"
        if (daysUntil === 1) return "Mañana"
        return "En " + daysUntil + " días"
    }

    function daysCountLabel(length) {
        return length === 1 ? "1 día" : length + " días seguidos"
    }

    function monthBarsData() {
        var counts = new Array(12).fill(0)
        var firstScope = new Array(12).fill(null)
        for (var i = 0; i < root.holidaysList.length; i++) {
            var h = root.holidaysList[i]
            var m = parseInt(h.date.split("-")[1]) - 1
            counts[m]++
            if (!firstScope[m]) firstScope[m] = h.scope
        }
        var out = []
        for (var i2 = 0; i2 < 12; i2++) {
            out.push({
                letter: root.monthLetters[i2],
                count: counts[i2],
                color: counts[i2] ? Style.scopeColor(firstScope[i2]) : "#EFEADF"
            })
        }
        return out
    }

    function reloadHolidays() {
        holidaysList = holidayProvider.loadCachedHolidays(selectedYear)
    }

    // Finds the next block of consecutive days off — weekends, official
    // holidays, and the user's own confirmed/planned vacation days all
    // count, so a Friday holiday next to a weekend shows up as one 3-day
    // block instead of a lone Friday. Reads `root.profile` (reactive to
    // dataCenter's dataChanged) so it recomputes after marking days in
    // Planificar, even though HomePage itself is never recreated.
    function computeNextOff() {
        if (!root.holidayProvider) return null
        var holidaySet = {}
        var holidayInfo = {}
        var combined = root.holidayProvider.loadCachedHolidays(root.currentYear)
            .concat(root.holidayProvider.loadCachedHolidays(root.nextYear))
        for (var i = 0; i < combined.length; i++) {
            holidaySet[combined[i].date] = true
            holidayInfo[combined[i].date] = combined[i]
        }
        var personalSet = {}
        var personalState = {}
        var marks = root.profile.dayMarks || []
        for (var j = 0; j < marks.length; j++) {
            if (marks[j].state === "confirmed" || marks[j].state === "planned") {
                personalSet[marks[j].date] = true
                personalState[marks[j].date] = marks[j].state
            }
        }

        function isoOf(d) {
            return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
        }
        function isSpecial(iso) {
            return !!holidaySet[iso] || !!personalSet[iso]
        }
        function isOffDay(d) {
            var dow = d.getDay()
            return dow === 0 || dow === 6 || isSpecial(isoOf(d))
        }

        var today = new Date()
        today.setHours(0, 0, 0, 0)
        var cursor = new Date(today)
        var anchorIso = null
        for (var k = 0; k < 400; k++) {
            var iso = isoOf(cursor)
            if (isSpecial(iso)) { anchorIso = iso; break }
            cursor.setDate(cursor.getDate() + 1)
        }
        if (!anchorIso) return null

        var start = new Date(cursor)
        var end = new Date(cursor)
        var back = new Date(start)
        back.setDate(back.getDate() - 1)
        while (isOffDay(back)) {
            start = new Date(back)
            back.setDate(back.getDate() - 1)
        }
        var fwd = new Date(end)
        fwd.setDate(fwd.getDate() + 1)
        while (isOffDay(fwd)) {
            end = new Date(fwd)
            fwd.setDate(fwd.getDate() + 1)
        }

        var length = Math.round((end - start) / 86400000) + 1
        var daysUntil = Math.max(0, Math.round((start - today) / 86400000))

        var hol = holidayInfo[anchorIso]
        var name, subtitle
        if (hol) {
            name = hol.name
            subtitle = Style.scopeLabel(hol.scope)
        } else {
            var st = personalState[anchorIso]
            name = st === "confirmed" ? "Vacaciones confirmadas" : "Vacaciones planeadas"
            subtitle = st === "confirmed" ? "Confirmado" : "Planeado"
        }

        return { date: isoOf(start), name: name, subtitle: subtitle, length: length, daysUntil: daysUntil }
    }

    readonly property var nextOff: root.computeNextOff()

    onSelectedYearChanged: {
        showManualEditor = false
        monthFilter = -1
        reloadHolidays()
    }

    readonly property var filteredHolidays: root.monthFilter === -1
        ? root.holidaysList
        : root.holidaysList.filter(function(h) { return parseInt(h.date.split("-")[1]) - 1 === root.monthFilter })
    Component.onCompleted: reloadHolidays()

    // Selecting a month should bring its (usually short) filtered list
    // fully into view without extra scrolling — the full unfiltered list
    // is fine to require scrolling since it's naturally long.
    Timer {
        id: monthFilterScrollTimer
        interval: 60
        onTriggered: root.ensureListVisible()
    }
    onMonthFilterChanged: {
        if (monthFilter !== -1) monthFilterScrollTimer.restart()
    }
    function ensureListVisible() {
        if (!holidaysListCard) return
        var flick = homeFlickable
        var pad = 16
        var pos = holidaysListCard.mapToItem(flick, 0, 0)
        var itemTop = pos.y
        var itemBottom = itemTop + holidaysListCard.height
        var viewH = flick.height
        var delta = 0
        var fitsInView = (holidaysListCard.height + pad * 2) <= viewH
        if (fitsInView) {
            if (itemBottom + pad > viewH) delta = itemBottom + pad - viewH
            else if (itemTop - pad < 0) delta = itemTop - pad
        } else if (itemTop < 0 || itemBottom > viewH) {
            delta = itemTop - pad
        }
        if (delta === 0) return
        var target = flick.contentY + delta
        target = Math.max(0, Math.min(target, Math.max(0, flick.contentHeight - flick.height)))
        homeScrollAnimation.to = target
        homeScrollAnimation.restart()
    }

    Flickable {
        id: homeFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: homeColumn.implicitHeight
        boundsBehavior: Flickable.DragOverBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {}

        NumberAnimation {
            id: homeScrollAnimation
            target: homeFlickable
            property: "contentY"
            duration: 260
            easing.type: Easing.OutCubic
        }

        ColumnLayout {
            id: homeColumn
            width: root.width
            spacing: Style.mediumSpace

            Item { Layout.preferredHeight: Style.smallSpace }

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                spacing: Style.smallSpace

                Image { source: Style.icon("plane"); width: 24; height: 24; sourceSize: Qt.size(24, 24) }
                Text {
                    text: "Vacaplan"
                    font.family: Style.fontFamily
                    font.pixelSize: Style.heading2
                    font.weight: Font.Bold
                    color: Style.text
                }
                Item { Layout.fillWidth: true }

                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    id: resetButton
                    implicitHeight: 34
                    implicitWidth: resetRow.implicitWidth + 25
                    background: Rectangle {
                        radius: 999
                        color: Style.surface
                        border.color: resetButton.pressed ? Style.primary : Style.divider
                        border.width: 1
                    }
                    contentItem: RowLayout {
                        id: resetRow
                        spacing: 6
                        Image { source: Style.icon("rotate-ccw"); width: 15; height: 15; sourceSize: Qt.size(15, 15) }
                        Text {
                            text: "Reiniciar"
                            font.family: Style.fontFamily
                            font.pixelSize: Style.caption
                            font.weight: Font.Medium
                            color: Style.textSecondary
                        }
                    }
                    onClicked: root.resetConfirmOpen = true
                }
            }

            // Location
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                spacing: 9

                Image { source: Style.icon("location-pin"); width: 17; height: 17; sourceSize: Qt.size(17, 17) }
                Text {
                    text: (root.profile.municipioName || root.profile.provinciaName || root.profile.ccaaName || "Tu ubicación")
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Style.text
                }
                Text {
                    text: "· " + [root.profile.provinciaName, root.profile.ccaaName].filter(Boolean).join(" · ")
                    visible: text.length > 2
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    color: Style.textSecondary
                }
                Item { Layout.fillWidth: true }
                Image { source: Style.icon("chevron-right"); width: 16; height: 16; sourceSize: Qt.size(16, 16); opacity: 0.45 }
            }

            // Hero card: 4-state counter
            Rectangle {
                id: heroCard
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                Layout.preferredHeight: heroContent.implicitHeight + 44
                radius: Style.heroRadius
                color: Style.primary
                clip: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Style.primary
                    shadowOpacity: 0.22
                    shadowBlur: 0.6
                    shadowVerticalOffset: 8
                }

                Rectangle {
                    width: 132; height: 132; radius: 66
                    color: "#FFFFFF"; opacity: 0.07
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: -26; anchors.topMargin: -26
                }
                Image {
                    source: Style.icon("sun-white")
                    width: 34; height: 34; sourceSize: Qt.size(34, 34)
                    opacity: 0.5
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: 14; anchors.topMargin: 16
                }

                ColumnLayout {
                    id: heroContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: Style.bigSpace
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text {
                            text: root.stateLabels[root.focusState].toUpperCase()
                            font.family: Style.fontFamily
                            font.pixelSize: Style.caption
                            font.weight: Font.Medium
                            font.letterSpacing: 0.7
                            color: "#E8F5F4"
                        }
                        RowLayout {
                            spacing: 9
                            Text {
                                text: root.heroCounts[root.focusState]
                                font.family: Style.fontFamily
                                font.pixelSize: Style.heroSize
                                font.weight: Font.Bold
                                font.letterSpacing: -3.4
                                color: root.heroCounts[root.focusState] < 0 ? Style.accent : "white"
                            }
                            Text {
                                text: "de " + root.totalDays + " días"
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: "#E8F5F4"
                                Layout.alignment: Qt.AlignBaseline
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.stateHints[root.focusState]
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            color: "#E8F5F4"
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Segmented bar: 4 tappable weighted segments
                    Item {
                        id: heroBarTrack
                        Layout.fillWidth: true
                        implicitHeight: 11
                        readonly property real totalWeight: root.stateOrder.reduce(function(sum, k) {
                            return sum + Math.max(root.heroCounts[k], 0.35)
                        }, 0)

                        Row {
                            anchors.fill: parent
                            spacing: 2
                            Repeater {
                                model: root.stateOrder
                                delegate: Rectangle {
                                    id: barSeg
                                    required property string modelData
                                    readonly property real weight: Math.max(root.heroCounts[modelData], 0.35)
                                    width: (heroBarTrack.width - 2 * (root.stateOrder.length - 1)) * (weight / heroBarTrack.totalWeight)
                                    height: 11
                                    radius: 99
                                    color: root.heroBarColor[modelData]
                                    opacity: (root.focusState === modelData ? 1 : 0.78) * (barTap.pressed ? 0.6 : 1.0)
                                    Behavior on opacity { NumberAnimation { duration: Style.animationTime } }
                                    TapHandler { id: barTap; onTapped: root.focusState = barSeg.modelData }
                                }
                            }
                        }
                    }

                    // Legend: 2x2, tappable
                    Grid {
                        id: legendGrid
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 10

                        Repeater {
                            model: root.stateOrder
                            delegate: Rectangle {
                                id: legendItem
                                required property string modelData
                                readonly property bool active: root.focusState === modelData
                                width: (legendGrid.width - legendGrid.columnSpacing) / 2
                                height: 30
                                radius: 999
                                color: active ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                border.color: active ? Qt.rgba(1, 1, 1, 0.34) : "transparent"
                                border.width: 1
                                opacity: legendTap.pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 10
                                    spacing: 7
                                    Rectangle { width: 8; height: 8; radius: 4; color: root.heroBarColor[legendItem.modelData] }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.stateLabels[legendItem.modelData]
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: root.heroCounts[legendItem.modelData]
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "white"
                                    }
                                }
                                TapHandler { id: legendTap; onTapped: root.focusState = legendItem.modelData }
                            }
                        }
                    }
                }
            }

            // Planificar mis días
            Button {
                opacity: pressed ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                implicitHeight: plannerRow.implicitHeight + 32
                topPadding: 16
                bottomPadding: 16
                leftPadding: 16
                rightPadding: 16
                background: Rectangle {
                    radius: 22
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }
                }
                contentItem: RowLayout {
                    id: plannerRow
                    spacing: 13

                    Rectangle {
                        width: 44; height: 44; radius: 14
                        color: Style.accent
                        Image { anchors.centerIn: parent; source: Style.icon("calendar"); width: 22; height: 22; sourceSize: Qt.size(22, 22) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "Planificar mis días"
                            font.family: Style.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Style.text
                        }
                        Text {
                            text: "Calendario completo · " + root.currentYear + " y " + root.nextYear
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            color: Style.textSecondary
                        }
                    }
                    Image { source: Style.icon("chevron-right"); width: 18; height: 18; sourceSize: Qt.size(18, 18); opacity: 0.45 }
                }
                onClicked: root.openPlanner()
            }

            // Próximo día libre
            ColumnLayout {
                visible: root.nextOff !== null
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                spacing: 11

                Text {
                    text: "Tu próximo día libre"
                    font.family: Style.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Style.text
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: nextRow.implicitHeight + 36
                    radius: 22
                    color: "#FFF3EE"
                    border.color: Qt.rgba(1, 0.42, 0.29, 0.3)
                    border.width: 1

                    RowLayout {
                        id: nextRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: dateBlockCol.implicitHeight + 19
                            radius: 16
                            color: Style.accent
                            ColumnLayout {
                                id: dateBlockCol
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.nextOff ? root.monthAbbrs[parseInt(root.nextOff.date.split("-")[1]) - 1] : ""
                                    font.family: Style.fontFamily
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.4
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.nextOff ? parseInt(root.nextOff.date.split("-")[2]) : ""
                                    font.family: Style.fontFamily
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                    font.letterSpacing: -0.6
                                    color: "white"
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: root.nextOff ? root.nextOff.name : ""
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Style.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.nextOff
                                      ? (root.weekdayName(root.nextOff.date) + " · " + root.nextOff.subtitle)
                                      : ""
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                color: Style.textSecondary
                            }
                            Text {
                                text: root.nextOff
                                      ? (root.daysCountLabel(root.nextOff.length) + " · " + root.nextInLabel(root.nextOff.daysUntil))
                                      : ""
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Style.accent
                            }
                        }
                    }
                }
            }

            // Holidays section header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                Layout.topMargin: Style.smallSpace
                spacing: Style.smallSpace

                Text {
                    text: "Festivos " + root.selectedYear
                    font.family: Style.fontFamily
                    font.pixelSize: Style.heading2
                    font.weight: Font.Bold
                    color: Style.text
                }
                Text {
                    text: root.monthFilter === -1
                          ? (root.holidaysList.length ? root.holidaysList.length + " en total" : "")
                          : (root.filteredHolidays.length + " en " + root.months[root.monthFilter])
                    font.family: Style.fontFamily
                    font.pixelSize: Style.caption
                    color: Style.textSecondary
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
                            implicitWidth: thisYearText.implicitWidth + 26
                            background: Rectangle {
                                radius: 999
                                color: root.selectedYear === root.currentYear ? Style.surface : "transparent"
                                layer.enabled: root.selectedYear === root.currentYear
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text {
                                id: thisYearText
                                text: String(root.currentYear)
                                font.family: Style.fontFamily
                                font.pixelSize: Style.caption
                                font.weight: Font.Bold
                                color: root.selectedYear === root.currentYear ? Style.primary : Style.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.selectedYear = root.currentYear
                        }
                        Button {
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            implicitHeight: 28
                            implicitWidth: nextYearText.implicitWidth + 26
                            background: Rectangle {
                                radius: 999
                                color: root.selectedYear === root.nextYear ? Style.surface : "transparent"
                                layer.enabled: root.selectedYear === root.nextYear
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text {
                                id: nextYearText
                                text: String(root.nextYear)
                                font.family: Style.fontFamily
                                font.pixelSize: Style.caption
                                font.weight: Font.Bold
                                color: root.selectedYear === root.nextYear ? Style.primary : Style.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.selectedYear = root.nextYear
                        }
                    }
                }
            }

            // 12-month density strip
            Item {
                visible: root.holidaysList.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                implicitHeight: 62

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }
                }

                Row {
                    id: monthBarRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 12
                    height: 38
                    spacing: 5

                    Repeater {
                        model: root.monthBarsData()
                        delegate: Rectangle {
                            id: monthBarItem
                            required property var modelData
                            required property int index
                            width: (monthBarRow.width - monthBarRow.spacing * 11) / 12
                            height: 38
                            radius: 8

                            readonly property bool selected: root.monthFilter === index
                            readonly property bool clickable: modelData.count > 0
                            readonly property bool dimmed: !selected && root.monthFilter !== -1

                            color: selected ? "#0E7C7B" : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: "#0E7C7B"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            layer.enabled: selected
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: "#0E7C7B"
                                shadowOpacity: 0.35
                                shadowBlur: 0.4
                                shadowVerticalOffset: 2
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Item { width: parent.width; height: 18
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: monthBarItem.modelData.count ? Math.min(18, 6 + monthBarItem.modelData.count * 6) : 3
                                        radius: 3
                                        color: monthBarItem.selected ? "#FFFFFF" : monthBarItem.modelData.color
                                        opacity: monthBarItem.dimmed ? 0.28 : 1.0
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: monthBarItem.modelData.letter
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Style.fontFamily
                                    font.pixelSize: 8
                                    font.weight: monthBarItem.selected ? Font.Bold : Font.Normal
                                    color: monthBarItem.selected ? "#FFFFFF"
                                           : monthBarItem.dimmed ? "#C4CBCC"
                                           : (monthBarItem.modelData.count ? Style.text : "#B9C2C4")
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            TapHandler {
                                enabled: monthBarItem.clickable
                                onTapped: root.monthFilter = (root.monthFilter === monthBarItem.index) ? -1 : monthBarItem.index
                            }
                        }
                    }
                }
            }

            // Holidays list
            Rectangle {
                id: holidaysListCard
                visible: root.holidaysList.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                Layout.preferredHeight: holidaysColumn.implicitHeight + 8
                radius: Style.listRadius
                color: Style.surface
                border.color: Style.divider
                border.width: 1
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }

                ColumnLayout {
                    id: holidaysColumn
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 4
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 0

                    Repeater {
                        model: root.filteredHolidays
                        delegate: Rectangle {
                            id: holidayRow
                            required property var modelData
                            required property int index
                            property bool open: false

                            Layout.fillWidth: true
                            implicitHeight: 68
                            radius: 12
                            color: open ? Style.scopeChipBg(modelData.scope) : "transparent"
                            opacity: rowArea.pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            Rectangle {
                                visible: holidayRow.index > 0
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                height: 1
                                color: Style.divider
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                onClicked: holidayRow.open = !holidayRow.open
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 13

                                Rectangle {
                                    width: 34; height: 34; radius: 11
                                    color: Style.scopeChipBg(holidayRow.modelData.scope)
                                    Image {
                                        anchors.centerIn: parent
                                        visible: Style.scopeIcon(holidayRow.modelData.scope) !== ""
                                        source: Style.scopeIcon(holidayRow.modelData.scope)
                                        width: 19; height: 19
                                        sourceSize: Qt.size(19, 19)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: holidayRow.modelData.name
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.semi
                                        font.weight: Font.Medium
                                        color: Style.text
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: root.fullDate(holidayRow.modelData.date)
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.caption
                                        color: Style.textSecondary
                                    }
                                }

                                Rectangle {
                                    radius: 999
                                    color: Style.scopeChipBg(holidayRow.modelData.scope)
                                    implicitWidth: scopeChipText.implicitWidth + 18
                                    implicitHeight: scopeChipText.implicitHeight + 12
                                    Text {
                                        id: scopeChipText
                                        anchors.centerIn: parent
                                        text: Style.scopeLabel(holidayRow.modelData.scope)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Style.scopeColor(holidayRow.modelData.scope)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            ColumnLayout {
                visible: root.holidaysList.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                Layout.bottomMargin: Style.mediumMargin
                spacing: Style.mediumSpace

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: emptyContent.implicitHeight + 68
                    radius: Style.listRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1

                    ColumnLayout {
                        id: emptyContent
                        anchors.centerIn: parent
                        width: parent.width - 52
                        spacing: 12

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: Style.icon("palm-tree")
                            width: 46; height: 46
                            sourceSize: Qt.size(46, 46)
                            opacity: 0.35
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Todavía no hay festivos de " + root.selectedYear
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Style.text
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: "El calendario oficial suele publicarse en octubre. Mientras tanto, puedes añadir los tuyos a mano."
                            font.family: Style.fontFamily
                            font.pixelSize: 13
                            color: Style.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Button {
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            implicitHeight: 40
                            implicitWidth: addLabel.implicitWidth + 40
                            background: Rectangle { radius: 999; color: Style.accent }
                            contentItem: Text {
                                id: addLabel
                                text: "Añadir festivo manual"
                                font.family: Style.fontFamily
                                font.pixelSize: Style.semi
                                font.weight: Font.Bold
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.showManualEditor = !root.showManualEditor
                        }
                    }
                }

                ManualHolidaysEditor {
                    visible: root.showManualEditor
                    Layout.fillWidth: true
                    year: root.selectedYear
                    holidayProvider: root.holidayProvider
                    onSaved: {
                        root.showManualEditor = false
                        root.reloadHolidays()
                    }
                }
            }

            Item { Layout.preferredHeight: Style.mediumMargin }
        }
    }

    // Bottom scroll-fade: hints there's more below without a hard cutoff.
    // Opacity ramps with how much is actually left to scroll (not a
    // plain visible/hidden switch) so it fades out smoothly as you
    // approach the end rather than disappearing abruptly.
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 52
        readonly property real remaining: homeFlickable.contentHeight - homeFlickable.contentY - homeFlickable.height
        opacity: Math.max(0, Math.min(1, (remaining - 4) / 70))
        Behavior on opacity { NumberAnimation { duration: 250 } }
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(0.122, 0.165, 0.18, 0.07) }
            GradientStop { position: 1.0; color: Qt.rgba(0.122, 0.165, 0.18, 0.18) }
        }
    }

    // Reset confirmation modal
    Item {
        anchors.fill: parent
        visible: root.resetConfirmOpen
        z: 50

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.122, 0.165, 0.18, 0.42)
            MouseArea { anchors.fill: parent; onClicked: root.resetConfirmOpen = false }
        }

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 18
            radius: Style.heroRadius
            color: Style.surface
            implicitHeight: resetCol.implicitHeight + 40

            ColumnLayout {
                id: resetCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 20
                spacing: 13

                Rectangle {
                    width: 44; height: 44; radius: 14
                    color: Style.scopeChipBg("autonomico")
                    Image { anchors.centerIn: parent; source: Style.icon("reset-accent"); width: 22; height: 22; sourceSize: Qt.size(22, 22) }
                }
                Text {
                    text: "¿Reiniciar Vacaplan?"
                    font.family: Style.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                    color: Style.text
                }
                Text {
                    Layout.fillWidth: true
                    text: "Se borrarán tu ubicación, tus " + root.totalDays + " días de convenio y los "
                          + root.markCount + " días que has marcado en " + root.currentYear + " y " + root.nextYear
                          + ". Volverás al primer paso de la configuración. Esta acción no se puede deshacer."
                    font.family: Style.fontFamily
                    font.pixelSize: 14
                    color: Style.textSecondary
                    wrapMode: Text.WordWrap
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    spacing: 9
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 52
                        background: Rectangle { radius: 999; color: Style.accent }
                        contentItem: Text { text: "Sí, reiniciar todo"; font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            root.resetConfirmOpen = false
                            root.dataCenter.resetOnboarding()
                            root.restartOnboarding()
                        }
                    }
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 48
                        background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                        contentItem: Text { text: "Cancelar"; font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.textSecondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: root.resetConfirmOpen = false
                    }
                }
            }
        }
    }
}
