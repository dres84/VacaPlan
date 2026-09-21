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

    // Reset scroll position whenever this page becomes the active StackView
    // item — otherwise coming back from Planificar lands mid-scroll instead
    // of at the top.
    StackView.onActivated: homeFlickable.contentY = 0

    readonly property var months: [qsTr("enero"), qsTr("febrero"), qsTr("marzo"), qsTr("abril"), qsTr("mayo"), qsTr("junio"),
        qsTr("julio"), qsTr("agosto"), qsTr("septiembre"), qsTr("octubre"), qsTr("noviembre"), qsTr("diciembre")]
    readonly property var monthAbbrs: [qsTr("ENE"), qsTr("FEB"), qsTr("MAR"), qsTr("ABR"), qsTr("MAY"), qsTr("JUN"), qsTr("JUL"), qsTr("AGO"), qsTr("SEP"), qsTr("OCT"), qsTr("NOV"), qsTr("DIC")]
    readonly property var monthLetters: [qsTr("E"), qsTr("F"), qsTr("M"), qsTr("A"), qsTr("M"), qsTr("J"), qsTr("J"), qsTr("A"), qsTr("S"), qsTr("O"), qsTr("N"), qsTr("D")]
    readonly property var weekdaysDow: [qsTr("domingo"), qsTr("lunes"), qsTr("martes"), qsTr("miércoles"), qsTr("jueves"), qsTr("viernes"), qsTr("sábado")]

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
    readonly property var stateLabels: ({ used: qsTr("Gastados"), confirmed: qsTr("Confirmados"), planned: qsTr("Planeados"), available: qsTr("Disponibles") })
    readonly property var stateHints: ({
        used: qsTr("Ya disfrutados este año"),
        confirmed: qsTr("Aprobados y en el calendario"),
        planned: qsTr("Marcados pero todavía sin confirmar"),
        available: qsTr("Libres para planificar lo que quede de año")
    })

    property string focusState: "available"
    property int monthFilter: -1 // -1 = sin filtro
    property bool resetConfirmOpen: false
    property bool settingsOpen: false

    property var holidaysList: []
    property bool showManualEditor: false

    function isoToday() {
        var d = new Date()
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function shortDate(iso) {
        if (!iso) return ""
        var parts = iso.split("-")
        var abbrs = [qsTr("ene"), qsTr("feb"), qsTr("mar"), qsTr("abr"), qsTr("may"), qsTr("jun"), qsTr("jul"), qsTr("ago"), qsTr("sep"), qsTr("oct"), qsTr("nov"), qsTr("dic")]
        return parseInt(parts[2]) + " " + abbrs[parseInt(parts[1]) - 1]
    }

    function fullDate(iso) {
        if (!iso) return ""
        var parts = iso.split("-")
        return qsTr("%1 de %2").arg(parseInt(parts[2])).arg(root.months[parseInt(parts[1]) - 1])
    }

    function weekdayName(iso) {
        var p = iso.split("-")
        var dt = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        return weekdaysDow[dt.getDay()]
    }

    function nextInLabel(daysUntil) {
        if (daysUntil <= 0) return qsTr("Hoy")
        if (daysUntil === 1) return qsTr("Mañana")
        return qsTr("En %1 días").arg(daysUntil)
    }

    function daysCountLabel(length) {
        return length === 1 ? qsTr("1 día") : qsTr("%1 días seguidos").arg(length)
    }

    function monthBarsData() {
        var byMonth = new Array(12)
        for (var i = 0; i < 12; i++) byMonth[i] = []
        for (var j = 0; j < root.holidaysList.length; j++) {
            var h = root.holidaysList[j]
            var m = parseInt(h.date.split("-")[1]) - 1
            byMonth[m].push(h.scope)
        }
        var out = []
        for (var i2 = 0; i2 < 12; i2++) {
            out.push({ letter: root.monthLetters[i2], scopes: byMonth[i2] })
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
        var name, subtitle, scope, state
        if (hol) {
            name = hol.name
            subtitle = Style.scopeLabel(hol.scope)
            scope = hol.scope
        } else {
            var st = personalState[anchorIso]
            name = st === "confirmed" ? qsTr("Vacaciones confirmadas") : qsTr("Vacaciones planeadas")
            subtitle = st === "confirmed" ? qsTr("Confirmado") : qsTr("Planeado")
            state = st
        }

        return { date: isoOf(start), name: name, subtitle: subtitle, length: length, daysUntil: daysUntil, scope: scope, state: state }
    }

    readonly property var nextOff: root.computeNextOff()

    // The "next day off" card can anchor on either a holiday (scope-colored,
    // Familia B) or the user's own confirmed/planned mark (state-colored,
    // Familia A) — whichever comes first. These read whichever is set.
    function nextOffFill() {
        if (!root.nextOff) return Style.textSecondary
        return root.nextOff.scope ? Style.scopeColor(root.nextOff.scope) : Style.stateFill(root.nextOff.state)
    }
    function nextOffInk() {
        if (!root.nextOff) return Style.textSecondary
        return root.nextOff.scope ? Style.scopeInk(root.nextOff.scope) : Style.stateInk(root.nextOff.state)
    }

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

                Image { source: Style.icon("app-icon"); width: 36; height: 36; sourceSize: Qt.size(36, 36) }
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
                    id: settingsButton
                    implicitWidth: 34
                    implicitHeight: 34
                    background: Rectangle {
                        radius: 999
                        color: Style.surface
                        border.color: settingsButton.pressed ? Style.primaryBorder : Style.divider
                        border.width: 1
                    }
                    contentItem: Image {
                        anchors.centerIn: parent
                        source: Style.icon("settings")
                        width: 16; height: 16
                        sourceSize: Qt.size(16, 16)
                    }
                    onClicked: root.settingsOpen = true
                }

                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    id: resetButton
                    implicitHeight: 34
                    implicitWidth: resetRow.implicitWidth + 25
                    background: Rectangle {
                        radius: 999
                        color: Style.surface
                        border.color: resetButton.pressed ? Style.primaryBorder : Style.divider
                        border.width: 1
                    }
                    contentItem: RowLayout {
                        id: resetRow
                        spacing: 6
                        Image { source: Style.icon("rotate-ccw"); width: 15; height: 15; sourceSize: Qt.size(15, 15) }
                        Text {
                            text: qsTr("Reiniciar")
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
                    text: (root.profile.municipioName || root.profile.provinciaName || root.profile.ccaaName || qsTr("Tu ubicación"))
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
                                text: qsTr("de %1 días").arg(root.totalDays)
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
                                    readonly property bool isAvailable: modelData === "available"
                                    readonly property real weight: Math.max(root.heroCounts[modelData], 0.35)
                                    width: (heroBarTrack.width - 2 * (root.stateOrder.length - 1)) * (weight / heroBarTrack.totalWeight)
                                    height: 11
                                    radius: 99
                                    // "Disponible" is the leftover, not a value — drawn hollow
                                    // (a ring) instead of filled, so it never reads as a fourth
                                    // data color sitting next to the three real states.
                                    color: isAvailable ? Style.heroAvailableFill : Style.heroStateColor(modelData)
                                    border.width: isAvailable ? 1.5 : 0
                                    border.color: Style.heroAvailableRing
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
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: legendItem.modelData === "available" ? "transparent" : Style.heroStateColor(legendItem.modelData)
                                        border.width: legendItem.modelData === "available" ? 2 : 0
                                        border.color: Style.heroAvailableLegendRing
                                    }
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
                            text: qsTr("Planificar mis días")
                            font.family: Style.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Style.text
                        }
                        Text {
                            text: qsTr("Calendario completo · %1 y %2").arg(root.currentYear).arg(root.nextYear)
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
                    text: qsTr("Tu próximo día libre")
                    font.family: Style.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Style.text
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: nextRow.implicitHeight + 36
                    radius: 22
                    // Colored from whatever root.nextOff actually is — a
                    // holiday's scope (Familia B) or the user's own
                    // confirmed/planned mark (Familia A), never a fixed coral.
                    color: Style.withAlpha(root.nextOffFill(), 0.07843) // fill + 14 (8%)
                    border.color: Style.withAlpha(root.nextOffFill(), 0.30196) // fill + 4d (30%)
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
                            color: root.nextOffFill()
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
                                color: root.nextOffInk()
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
                    text: qsTr("Festivos %1").arg(root.selectedYear)
                    font.family: Style.fontFamily
                    font.pixelSize: Style.heading2
                    font.weight: Font.Bold
                    color: Style.text
                }
                Text {
                    text: root.monthFilter === -1
                          ? (root.holidaysList.length ? qsTr("%1 en total").arg(root.holidaysList.length) : "")
                          : qsTr("%1 en %2").arg(root.filteredHolidays.length).arg(root.months[root.monthFilter])
                    font.family: Style.fontFamily
                    font.pixelSize: Style.caption
                    color: Style.textSecondary
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: yearTabsRow.implicitWidth + 6
                    implicitHeight: yearTabsRow.implicitHeight + 6
                    radius: 999
                    color: Style.track

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
                                color: root.selectedYear === root.currentYear ? Style.primaryInk : Style.textSecondary
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
                                color: root.selectedYear === root.nextYear ? Style.primaryInk : Style.textSecondary
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
                            readonly property bool clickable: modelData.scopes.length > 0
                            readonly property bool dimmed: !selected && root.monthFilter !== -1
                            // Selection highlight reuses the nacional violet
                            // as a generic "selected" tint — it's not saying
                            // this month IS a nacional holiday, just borrowing
                            // that hue the same way the calendar legend does
                            // for its single "Festivo" swatch.
                            readonly property color highlightColor: Style.scopeColor("nacional")

                            color: selected ? highlightColor : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: highlightColor
                            Behavior on color { ColorAnimation { duration: 150 } }

                            layer.enabled: selected
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: monthBarItem.highlightColor
                                shadowOpacity: 0.35
                                shadowBlur: 0.4
                                shadowVerticalOffset: 2
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Item { width: parent.width; height: 18
                                    // Empty-month placeholder — a thin sliver
                                    // so the column isn't blank.
                                    Rectangle {
                                        visible: monthBarItem.modelData.scopes.length === 0
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 3
                                        radius: 3
                                        color: Style.dividerSoft
                                    }
                                    // One 6px segment per holiday that month,
                                    // each in its own scope color, stacked
                                    // bottom-up with a 1px gap — instead of a
                                    // single bar colored by whichever holiday
                                    // happened to come first.
                                    Column {
                                        visible: monthBarItem.modelData.scopes.length > 0
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        spacing: 1
                                        Repeater {
                                            model: monthBarItem.modelData.scopes
                                            delegate: Rectangle {
                                                required property string modelData
                                                width: parent.width
                                                height: 6
                                                radius: 3
                                                color: monthBarItem.selected ? "#FFFFFF" : Style.scopeColor(modelData)
                                                opacity: monthBarItem.dimmed ? 0.28 : 1.0
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                            }
                                        }
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
                                           : monthBarItem.dimmed ? Style.textGhost
                                           : (monthBarItem.modelData.scopes.length > 0 ? Style.text : Style.textGhost)
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
                                    width: 32; height: 32; radius: 10
                                    // Light/soft — kept clearly distinct from the solid,
                                    // vivid pill on the right rather than matching it.
                                    color: Style.scopeChipBg(holidayRow.modelData.scope)
                                    // A plain Text glyph with a direct color binding, not an
                                    // Image + MultiEffect colorization layer — the layered
                                    // shader effect could not be verified to render reliably
                                    // in every environment, so this avoids that dependency
                                    // entirely in favor of something guaranteed to paint.
                                    Text {
                                        anchors.centerIn: parent
                                        text: "⚑" // ⚑ flag
                                        font.pixelSize: 16
                                        color: Style.scopeColor(holidayRow.modelData.scope)
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
                                    color: Style.scopeColor(holidayRow.modelData.scope)
                                    implicitWidth: scopeChipText.implicitWidth + 24
                                    implicitHeight: scopeChipText.implicitHeight + 16
                                    Text {
                                        id: scopeChipText
                                        anchors.centerIn: parent
                                        text: Style.scopeLabel(holidayRow.modelData.scope)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "white"
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
                            text: qsTr("Todavía no hay festivos de %1").arg(root.selectedYear)
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Style.text
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: qsTr("El calendario oficial suele publicarse en octubre. Mientras tanto, puedes añadir los tuyos a mano.")
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
                                text: qsTr("Añadir festivo manual")
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

            // Credit
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 6
                Text {
                    text: qsTr("Diseñado por")
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    color: Style.textDisabled
                }
                Image {
                    source: "qrc:/icons/dresoft-logo.png"
                    fillMode: Image.PreserveAspectFit
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: 16 * (512 / 168)
                    sourceSize.height: 32
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
            GradientStop { position: 0.5; color: Style.withAlpha(Style.text, 0.07) }
            GradientStop { position: 1.0; color: Style.withAlpha(Style.text, 0.18) }
        }
    }

    // Appearance settings modal
    SettingsModal {
        anchors.fill: parent
        open: root.settingsOpen
        onClosed: root.settingsOpen = false
    }

    // Reset confirmation modal
    Item {
        anchors.fill: parent
        visible: root.resetConfirmOpen
        z: 50

        Rectangle {
            anchors.fill: parent
            color: Style.scrim
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
                    text: qsTr("¿Reiniciar Vacaplan?")
                    font.family: Style.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                    color: Style.text
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Se borrarán tu ubicación, tus %1 días de convenio y los %2 días que has marcado en %3 y %4. Volverás al primer paso de la configuración. Esta acción no se puede deshacer.")
                          .arg(root.totalDays).arg(root.markCount).arg(root.currentYear).arg(root.nextYear)
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
                        contentItem: Text { text: qsTr("Sí, reiniciar todo"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                        contentItem: Text { text: qsTr("Cancelar"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.textSecondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: root.resetConfirmOpen = false
                    }
                }
            }
        }
    }
}
