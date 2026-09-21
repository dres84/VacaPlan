import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

Page {
    id: root
    property var dataCenter
    property var holidayProvider
    signal finished()
    signal back()

    property bool settingsOpen: false

    background: Rectangle { color: Style.background }

    // Reset scroll position whenever this page becomes the active StackView
    // item — otherwise coming back via "Atrás" lands mid-scroll instead of
    // at the top.
    StackView.onActivated: scrollView.contentY = 0

    readonly property var months: [qsTr("enero"), qsTr("febrero"), qsTr("marzo"), qsTr("abril"), qsTr("mayo"), qsTr("junio"),
        qsTr("julio"), qsTr("agosto"), qsTr("septiembre"), qsTr("octubre"), qsTr("noviembre"), qsTr("diciembre")]
    readonly property var weekdaysDow: [qsTr("domingo"), qsTr("lunes"), qsTr("martes"), qsTr("miércoles"), qsTr("jueves"), qsTr("viernes"), qsTr("sábado")]
    readonly property var weekdaysShort: [qsTr("L"), qsTr("M"), qsTr("X"), qsTr("J"), qsTr("V"), qsTr("S"), qsTr("D")]
    readonly property int year: new Date().getFullYear()

    property int totalDays: dataCenter ? dataCenter.data.totalVacationDays : 22
    property string mode: "dates" // "dates" | "count"
    property int usedCount: 0
    property var usedDatesList: [] // ISO strings, sorted

    property bool picking: false
    property int calendarMonth: new Date().getMonth()
    property string dayManual: ""
    property string highlightKey: ""

    // One hue per month, evenly spaced, so each used day reads as "which
    // month" at a glance in the chip list and in the calendar itself.
    readonly property var monthColors: Style.monthPillColors

    property bool hoursOpen: false
    property string hoursDate: ""
    property string hoursAmount: ""
    readonly property var hourEntries: dataCenter && dataCenter.data.usedVacationHourEntries ? dataCenter.data.usedVacationHourEntries : []

    readonly property int usedTotal: mode === "dates" ? usedDatesList.length : usedCount
    // No longer clamped to 0: going over the total is a real, visible state
    // (shown in coral), not silently hidden.
    readonly property int leftDays: totalDays - usedTotal
    readonly property real usedPct: totalDays > 0 ? Math.min(1, usedCount / totalDays) : 0

    function isoFor(day, month) {
        return root.year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }

    function dayMonthFor(iso) {
        var p = iso.split("-")
        return { day: parseInt(p[2]), month: parseInt(p[1]) - 1 }
    }

    function shortLabel(iso) {
        var p = iso.split("-")
        var d = parseInt(p[2]); var m = parseInt(p[1]) - 1
        return qsTr("%1 de %2 de %3").arg(d).arg(months[m]).arg(p[0])
    }

    function shortChipLabel(iso) {
        var dm = root.dayMonthFor(iso)
        return dm.day + " " + root.months[dm.month].slice(0, 3)
    }

    function weekdayLabel(iso) {
        var p = iso.split("-")
        var dt = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        return weekdaysDow[dt.getDay()]
    }

    function toggleDate(iso) {
        var list = root.usedDatesList.slice()
        var idx = list.indexOf(iso)
        if (idx !== -1) list.splice(idx, 1)
        else { list.push(iso); list.sort() }
        root.usedDatesList = list
    }

    // Explicit add/remove (not a toggle) so a drag gesture across several
    // cells can apply the same action to every cell it passes over, instead
    // of re-toggling a cell back off when the drag crosses it twice.
    function setDaySelected(day, month, add) {
        var iso = root.isoFor(day, month)
        var list = root.usedDatesList.slice()
        var idx = list.indexOf(iso)
        if (add && idx === -1) { list.push(iso); list.sort(); root.usedDatesList = list }
        else if (!add && idx !== -1) { list.splice(idx, 1); root.usedDatesList = list }
    }

    // Jumps the picker to the month of `iso` and briefly outlines that cell,
    // so tapping a chip in the used-days list shows you exactly where that
    // day lives on the calendar.
    function goToDay(day, month) {
        root.calendarMonth = month
        root.highlightKey = day + ":" + month
        root.picking = true
        highlightTimer.restart()
    }

    Timer {
        id: highlightTimer
        interval: 1400
        onTriggered: root.highlightKey = ""
    }

    // The picker card has its own entrance animation (opacity/y, 220ms). If
    // we scroll it into view immediately on Loader.onLoaded, we'd measure
    // its position mid-animation and land somewhere wrong — same lesson as
    // step 1's ensureVisible, so the actual scroll is delayed until that
    // animation is done.
    Timer {
        id: ensureVisibleTimer
        property var targetItem: null
        interval: 260
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
        var itemBottom = itemTop + item.height
        var viewH = flick.height
        var delta = 0
        var fitsInView = (item.height + pad * 2) <= viewH
        if (fitsInView) {
            if (itemBottom + pad > viewH) delta = itemBottom + pad - viewH
            else if (itemTop - pad < 0) delta = itemTop - pad
        } else if (itemTop < 0 || itemBottom > viewH) {
            delta = itemTop - pad
        }
        if (delta === 0) return
        var target = flick.contentY + delta
        target = Math.max(0, Math.min(target, Math.max(0, flick.contentHeight - flick.height)))
        scrollAnimation.to = target
        scrollAnimation.restart()
    }

    // Holidays for the calendar year shown in the picker (already fetched
    // and cached during step 1), so the mini-calendar can mark national/
    // regional/local holidays with a tinted background, same as the real
    // calendar.
    readonly property var holidaysThisYear: root.holidayProvider ? root.holidayProvider.loadCachedHolidays(root.year) : []

    function holidayForDate(iso) {
        for (var i = 0; i < root.holidaysThisYear.length; i++) {
            if (root.holidaysThisYear[i].date === iso) return root.holidaysThisYear[i]
        }
        return null
    }

    // Collapses the 5 real scopes into the 3-color legend the calendar
    // shows (nacional/autonómico/local): provincial and manual entries
    // read visually as "local" here, there just isn't room for 5 dot colors.
    function dotColorFor(scope) {
        if (scope === "nacional") return Style.scopeColor("nacional")
        if (scope === "autonomico" || scope === "regional") return Style.scopeColor("autonomico")
        return Style.scopeColor("manual")
    }

    // Holiday cells get a tinted background/border in the scope color
    // (~15%/~33% alpha), not just a colored number — matches the design's
    // hol.color + '26' / '55' hex-alpha suffixes.
    function holidayTintBg(scope) {
        var c = Qt.color(root.dotColorFor(scope))
        return Qt.rgba(c.r, c.g, c.b, 0.15)
    }
    function holidayTintBorder(scope) {
        var c = Qt.color(root.dotColorFor(scope))
        return Qt.rgba(c.r, c.g, c.b, 0.33)
    }

    function calendarCells() {
        var m = root.calendarMonth
        var first = new Date(root.year, m, 1)
        var lead = (first.getDay() + 6) % 7
        var days = new Date(root.year, m + 1, 0).getDate()
        var cells = []
        for (var i = 0; i < lead; i++) cells.push({ day: 0 })
        for (var d = 1; d <= days; d++) cells.push({ day: d })
        return cells
    }

    function parseManualDate(text) {
        var m = /^(\d{1,2})\s*\/\s*(\d{1,2})/.exec(text.trim())
        if (!m) return null
        var mo = Math.min(12, Math.max(1, parseInt(m[2], 10))) - 1
        var d = Math.min(new Date(root.year, mo + 1, 0).getDate(), Math.max(1, parseInt(m[1], 10)))
        return { day: d, month: mo }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: Style.smallSpace }

        StepHeader {
            step: 3
            linkText: qsTr("Atrás")
            onLinkClicked: root.back()
            onSettingsClicked: root.settingsOpen = true
        }

        Flickable {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                spacing: Style.mediumSpace

                // Title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 9

                    Image { source: Style.icon("calendar-check"); width: 32; height: 32; sourceSize: Qt.size(32, 32) }
                    Text {
                        text: qsTr("¿Ya has gastado días de vacaciones?")
                        font.family: Style.fontFamily
                        font.pixelSize: 27
                        font.weight: Font.Bold
                        font.letterSpacing: -0.8
                        color: Style.text
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: qsTr("Si apuntas las fechas verás tus vacaciones en el calendario. Si solo te interesa el saldo, con el número basta.")
                        font.family: Style.fontFamily
                        font.pixelSize: 14
                        color: Style.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Mode selector
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 10

                    Rectangle {
                        implicitWidth: modeTabsRow.implicitWidth + 6
                        implicitHeight: modeTabsRow.implicitHeight + 6
                        radius: 999
                        color: Style.track

                        RowLayout {
                            id: modeTabsRow
                            anchors.centerIn: parent
                            spacing: 2

                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitHeight: 32
                                implicitWidth: datesTabText.implicitWidth + 28
                                background: Rectangle {
                                    radius: 999
                                    color: root.mode === "dates" ? Style.surface : "transparent"
                                    layer.enabled: root.mode === "dates"
                                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                                }
                                contentItem: Text {
                                    id: datesTabText
                                    text: qsTr("Apuntar fechas")
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.mode === "dates" ? Style.primaryInk : Style.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.mode = "dates"
                            }
                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitHeight: 32
                                implicitWidth: countTabText.implicitWidth + 28
                                background: Rectangle {
                                    radius: 999
                                    color: root.mode === "count" ? Style.surface : "transparent"
                                    layer.enabled: root.mode === "count"
                                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                                }
                                contentItem: Text {
                                    id: countTabText
                                    text: qsTr("Solo el número")
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.mode === "count" ? Style.primaryInk : Style.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.mode = "count"
                            }
                        }
                    }

                    Rectangle {
                        visible: root.mode === "dates"
                        radius: 999
                        color: Style.scopeChipBg("nacional")
                        implicitWidth: recomText.implicitWidth + 16
                        implicitHeight: recomText.implicitHeight + 12
                        Text {
                            id: recomText
                            anchors.centerIn: parent
                            text: qsTr("RECOM.")
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Style.primaryInk
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // Balance row
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: balanceRow.implicitHeight + 28
                    radius: Style.cardRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1

                    RowLayout {
                        id: balanceRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: qsTr("Días usados"); font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                            RowLayout {
                                spacing: 4
                                Text { text: root.usedTotal; font.family: Style.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.text }
                                Text { text: qsTr("de %1").arg(root.totalDays); font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; Layout.alignment: Qt.AlignBaseline }
                            }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 34; color: Style.dividerSoft }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: qsTr("Te quedan"); font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                            RowLayout {
                                spacing: 4
                                Text { text: root.leftDays; font.family: Style.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: -0.4; color: root.leftDays < 0 ? Style.accent : Style.primaryInk }
                                Text { text: qsTr("días"); font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; Layout.alignment: Qt.AlignBaseline }
                            }
                        }
                    }
                }

                // Dates mode
                ColumnLayout {
                    visible: root.mode === "dates"
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 12

                    Flow {
                        visible: root.usedDatesList.length > 0
                        Layout.fillWidth: true
                        spacing: 7

                        Repeater {
                            model: root.usedDatesList
                            delegate: Rectangle {
                                id: dayChip
                                required property string modelData
                                readonly property var dm: root.dayMonthFor(modelData)
                                readonly property color chipColor: root.monthColors[dm.month]
                                readonly property bool isHl: root.highlightKey === (dm.day + ":" + dm.month)

                                radius: 999
                                color: chipColor
                                implicitHeight: 30
                                implicitWidth: chipLabel.implicitWidth + 12 + 6 + 22 + 5
                                border.width: isHl ? 2.5 : 0
                                border.color: Style.text

                                // Plain Text + Rectangle instead of nested Buttons: a
                                // Button's own default padding/inset fought the chip's
                                // fixed size and made the pill render smaller/squished
                                // than the design.
                                Text {
                                    id: chipLabel
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.shortChipLabel(dayChip.modelData)
                                    font.family: Style.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: "white"
                                    opacity: labelTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                    TapHandler { id: labelTap; onTapped: root.goToDay(dayChip.dm.day, dayChip.dm.month) }
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22; radius: 999
                                    color: Qt.rgba(1, 1, 1, 0.28)
                                    opacity: deleteTap.pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 11
                                        color: "white"
                                    }
                                    TapHandler { id: deleteTap; onTapped: root.toggleDate(dayChip.modelData) }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.usedDatesList.length === 0
                        Layout.fillWidth: true
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: emptyContent.implicitHeight + 56
                            radius: Style.listRadius
                            color: Style.surface
                            border.color: Style.divider
                            border.width: 1

                            ColumnLayout {
                                id: emptyContent
                                anchors.centerIn: parent
                                width: parent.width - 48
                                spacing: 9

                                Image { Layout.alignment: Qt.AlignHCenter; source: Style.icon("beach-umbrella"); width: 38; height: 38; sourceSize: Qt.size(38, 38); opacity: 0.35 }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: qsTr("Aún no has gastado nada")
                                    font.family: Style.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Style.text
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillWidth: true
                                    text: qsTr("Empiezas el año con los %1 días intactos. Si ya cogiste alguno, añádelo abajo.").arg(root.totalDays)
                                    font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        active: root.picking
                        visible: active
                        onLoaded: root.scheduleEnsureVisible(item)
                        sourceComponent: Component {
                            Rectangle {
                                Layout.fillWidth: true
                                property bool revealed: false
                                opacity: revealed ? 1 : 0
                                y: revealed ? 0 : 10
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Component.onCompleted: revealed = true

                                implicitHeight: pickerCol.implicitHeight + 24
                                radius: Style.listRadius
                                color: Style.surface
                                border.color: Style.primaryBorder
                                border.width: 1

                                ColumnLayout {
                                    id: pickerCol
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 13
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Button {
                                            opacity: pressed ? 0.6 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            implicitWidth: 30; implicitHeight: 30
                                            background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                            contentItem: Image { anchors.centerIn: parent; source: Style.icon("chevron-right"); width: 15; height: 15; sourceSize: Qt.size(15, 15); rotation: 180 }
                                            onClicked: root.calendarMonth = (root.calendarMonth + 11) % 12
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: qsTr("%1 de %2").arg(root.months[root.calendarMonth][0].toUpperCase() + root.months[root.calendarMonth].slice(1)).arg(root.year)
                                            font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: root.monthColors[root.calendarMonth]
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Button {
                                            opacity: pressed ? 0.6 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            implicitWidth: 30; implicitHeight: 30
                                            background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                            contentItem: Image { anchors.centerIn: parent; source: Style.icon("chevron-right"); width: 15; height: 15; sourceSize: Qt.size(15, 15) }
                                            onClicked: root.calendarMonth = (root.calendarMonth + 1) % 12
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: dayGrid.implicitHeight

                                        // Plain Grid, not GridLayout: GridLayout sizes
                                        // each column from its items' Layout.fillWidth,
                                        // which can misalign columns once two separate
                                        // Repeaters (weekdays + day cells) feed into the
                                        // same grid. A Grid with each cell's width fixed
                                        // to gridWidth/7 sidesteps that entirely.
                                        Grid {
                                            id: dayGrid
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            columns: 7
                                            rowSpacing: 3
                                            columnSpacing: 3

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
                                                    height: 32

                                                    readonly property string iso: modelData.day > 0 ? root.isoFor(modelData.day, root.calendarMonth) : ""
                                                    readonly property var holiday: modelData.day > 0 ? root.holidayForDate(iso) : null
                                                    readonly property bool isWeekend: modelData.day > 0 && [0, 6].indexOf(new Date(root.year, root.calendarMonth, modelData.day).getDay()) !== -1
                                                    readonly property bool isSelected: modelData.day > 0 && root.usedDatesList.indexOf(iso) !== -1
                                                    readonly property bool isHighlighted: modelData.day > 0 && root.highlightKey === (modelData.day + ":" + root.calendarMonth)

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: dayCell.modelData.day > 0
                                                        radius: 10
                                                        color: dayCell.isSelected ? root.monthColors[root.calendarMonth]
                                                               : dayCell.holiday ? root.holidayTintBg(dayCell.holiday.scope)
                                                               : Style.background
                                                        border.color: dayCell.isHighlighted ? Style.text
                                                               : dayCell.isSelected ? root.monthColors[root.calendarMonth]
                                                               : dayCell.holiday ? root.holidayTintBorder(dayCell.holiday.scope)
                                                               : Style.cellBorder
                                                        border.width: dayCell.isHighlighted ? 2.5 : 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: dayCell.modelData.day
                                                            font.family: Style.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: (dayCell.isSelected || dayCell.holiday) ? Font.Bold : Font.Medium
                                                            color: dayCell.isSelected ? "white"
                                                                   : dayCell.holiday ? root.dotColorFor(dayCell.holiday.scope)
                                                                   : dayCell.isWeekend ? Style.textGhost : Style.text
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // A single MouseArea over the whole grid drives
                                        // both tap and press-and-drag multi-select: the
                                        // web version wires onPointerDown/onPointerEnter
                                        // per cell button, which QML doesn't have a direct
                                        // equivalent for — one owning MouseArea doing its
                                        // own cell hit-testing is the standard QML way to
                                        // get the same "paint across cells" gesture.
                                        MouseArea {
                                            id: dragArea
                                            anchors.fill: dayGrid
                                            preventStealing: true
                                            property bool dragAdd: true
                                            // The grid's row 0 is the weekday-header labels
                                            // (L M X J...), not the first day-cell row — the
                                            // day cells start below it. Forgetting this
                                            // offset misaligned the row math more and more
                                            // the further down a drag went, so it looked
                                            // like you couldn't cross into a new row without
                                            // having "earned" it first.
                                            readonly property real headerRowHeight: 18 + dayGrid.rowSpacing

                                            function cellDayAt(mx, my) {
                                                var cellW = (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                                                var col = Math.floor(mx / (cellW + dayGrid.columnSpacing))
                                                var row = Math.floor((my - headerRowHeight) / (32 + dayGrid.rowSpacing))
                                                if (col < 0 || col > 6 || row < 0) return -1
                                                var idx = row * 7 + col
                                                var cells = root.calendarCells()
                                                if (idx < 0 || idx >= cells.length) return -1
                                                return cells[idx].day
                                            }

                                            function applyAt(mx, my, decideMode) {
                                                var day = cellDayAt(mx, my)
                                                if (day <= 0) return
                                                var iso = root.isoFor(day, root.calendarMonth)
                                                var holiday = root.holidayForDate(iso)
                                                var already = root.usedDatesList.indexOf(iso) !== -1
                                                if (holiday && !already) return
                                                if (decideMode) dragArea.dragAdd = !already
                                                root.setDaySelected(day, root.calendarMonth, dragArea.dragAdd)
                                            }

                                            onPressed: (mouse) => applyAt(mouse.x, mouse.y, true)
                                            onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x, mouse.y, false) }
                                        }
                                    }

                                    Text {
                                        Layout.topMargin: 2
                                        text: qsTr("Mantén pulsado y arrastra para marcar varios días de golpe.")
                                        font.family: Style.fontFamily
                                        font.pixelSize: 11
                                        color: Style.textFaint
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("nacional") }
                                            Text { text: qsTr("Nacional"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                        }
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("autonomico") }
                                            Text { text: qsTr("Autonómico"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                        }
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("manual") }
                                            Text { text: qsTr("Local"); font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        spacing: 10
                                        TextField {
                                            Layout.fillWidth: true
                                            text: root.dayManual
                                            placeholderText: qsTr("dd/mm/aaaa")
                                            placeholderTextColor: Style.textFaint
                                            color: Style.text
                                            font.family: Style.fontFamily
                                            background: Rectangle {
                                                radius: Style.mediumRadius
                                                color: Style.sunken
                                                border.color: Style.divider
                                                border.width: 1
                                            }
                                            onTextEdited: root.dayManual = text
                                        }
                                        Button {
                                            opacity: pressed ? 0.6 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            implicitHeight: 40
                                            background: Rectangle { radius: 999; color: Style.primary }
                                            contentItem: Text { text: qsTr("Añadir"); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                            onClicked: {
                                                var parsed = root.parseManualDate(root.dayManual)
                                                if (!parsed) return
                                                var iso = root.isoFor(parsed.day, parsed.month)
                                                if (root.usedDatesList.indexOf(iso) === -1) root.toggleDate(iso)
                                                root.dayManual = ""
                                                root.calendarMonth = parsed.month
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 50
                        background: Rectangle {
                            radius: 999
                            color: root.picking ? Style.scopeChipBg("nacional") : Style.surface
                            border.color: root.picking ? Style.primaryBorder : Style.divider
                            border.width: 1
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Image { source: Style.icon("plus"); width: 16; height: 16; sourceSize: Qt.size(16, 16) }
                            Text { text: qsTr("Añadir día usado"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.primaryInk }
                        }
                        onClicked: root.picking = !root.picking
                    }

                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.alignment: Qt.AlignLeft
                        Layout.topMargin: 2
                        implicitHeight: 26
                        background: Rectangle { color: "transparent" }
                        contentItem: Text {
                            text: root.hoursOpen ? qsTr("− Ocultar horas sueltas") : qsTr("+ Añadir horas sueltas")
                            font.family: Style.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Style.textSecondary
                        }
                        onClicked: root.hoursOpen = !root.hoursOpen
                    }

                    Loader {
                        Layout.fillWidth: true
                        active: root.hoursOpen
                        visible: active
                        sourceComponent: Component {
                            Rectangle {
                                Layout.fillWidth: true
                                property bool revealed: false
                                opacity: revealed ? 1 : 0
                                y: revealed ? 0 : 10
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Component.onCompleted: revealed = true

                                implicitHeight: hoursCol.implicitHeight + 28
                                radius: Style.cardRadius
                                color: Style.surface
                                border.color: Style.divider
                                border.width: 1

                                ColumnLayout {
                                    id: hoursCol
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 10

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Para ausencias más cortas que un día completo, en horas.")
                                        font.family: Style.fontFamily
                                        font.pixelSize: 12
                                        color: Style.textSecondary
                                        wrapMode: Text.WordWrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        TextField {
                                            Layout.preferredWidth: 76
                                            text: root.hoursDate
                                            placeholderText: qsTr("dd/mm")
                                            placeholderTextColor: Style.textFaint
                                            color: Style.text
                                            font.family: Style.fontFamily
                                            background: Rectangle {
                                                radius: Style.mediumRadius
                                                color: Style.sunken
                                                border.color: Style.divider
                                                border.width: 1
                                            }
                                            onTextEdited: root.hoursDate = text
                                        }
                                        TextField {
                                            Layout.preferredWidth: 56
                                            text: root.hoursAmount
                                            placeholderText: qsTr("h")
                                            placeholderTextColor: Style.textFaint
                                            color: Style.text
                                            horizontalAlignment: Text.AlignHCenter
                                            validator: IntValidator { bottom: 1; top: 24 }
                                            font.family: Style.fontFamily
                                            background: Rectangle {
                                                radius: Style.mediumRadius
                                                color: Style.sunken
                                                border.color: Style.divider
                                                border.width: 1
                                            }
                                            onTextEdited: root.hoursAmount = text
                                        }
                                        Button {
                                            opacity: pressed ? 0.6 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            Layout.fillWidth: true
                                            implicitHeight: 40
                                            background: Rectangle { radius: 999; color: Style.primary }
                                            contentItem: Text { text: qsTr("Añadir horas"); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                            onClicked: {
                                                var parsed = root.parseManualDate(root.hoursDate)
                                                var hours = parseInt(root.hoursAmount, 10)
                                                if (!parsed || !hours) return
                                                root.dataCenter.addUsedVacationHours(root.isoFor(parsed.day, parsed.month), hours)
                                                root.hoursDate = ""
                                                root.hoursAmount = ""
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        visible: root.hourEntries.length > 0
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        spacing: 0

                                        Repeater {
                                            model: root.hourEntries
                                            delegate: RowLayout {
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                Layout.topMargin: index === 0 ? 10 : 0
                                                Layout.bottomMargin: 10
                                                spacing: 10

                                                Text { Layout.fillWidth: true; text: root.shortLabel(modelData.date); font.family: Style.fontFamily; font.pixelSize: 13; color: Style.text }
                                                Rectangle {
                                                    radius: 999
                                                    color: Style.scopeChipBg("nacional")
                                                    implicitWidth: hourTagText.implicitWidth + 18
                                                    implicitHeight: hourTagText.implicitHeight + 12
                                                    Text { id: hourTagText; anchors.centerIn: parent; text: qsTr("%1 h").arg(modelData.hours); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; color: Style.primaryInk }
                                                }
                                                Button {
                                                    opacity: pressed ? 0.6 : 1.0
                                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                                    implicitWidth: 26; implicitHeight: 26
                                                    background: Rectangle { color: "transparent" }
                                                    contentItem: Text { text: "✕"; font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textDisabled; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    onClicked: root.dataCenter.removeUsedVacationHours(modelData.date)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Count mode
                Rectangle {
                    visible: root.mode === "count"
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: countContent.implicitHeight + 48
                    radius: Style.heroRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1

                    ColumnLayout {
                        id: countContent
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 24
                        spacing: 18

                        Text {
                            text: qsTr("DÍAS YA GASTADOS")
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.letterSpacing: 0.5
                            color: Style.textSecondary
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("minus"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.usedCount = Math.max(0, root.usedCount - 1)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { Layout.alignment: Qt.AlignHCenter; text: root.usedCount; font.family: Style.fontFamily; font.pixelSize: 64; font.weight: Font.Bold; font.letterSpacing: -2.9; color: Style.text }
                                Text { Layout.alignment: Qt.AlignHCenter; text: qsTr("de %1 días").arg(root.totalDays); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; color: Style.textSecondary }
                            }
                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("plus"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.usedCount = Math.min(root.totalDays, root.usedCount + 1)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 7; radius: 99
                            color: Style.track
                            Rectangle {
                                height: parent.height; radius: 99
                                color: Style.accent
                                width: parent.width * root.usedPct
                                Behavior on width { NumberAnimation { duration: Style.animationTime } }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Style.mediumMargin }
            }
        }

        OnboardingFooter {
            text: qsTr("Terminar")
            baseColor: Style.accent
            disabledColor: Style.accentDisabled
            showIcon: false
            onClicked: {
                root.dataCenter.setUsedVacationMode(root.mode)
                if (root.mode === "count") {
                    root.dataCenter.setUsedVacationCount(root.usedCount)
                } else {
                    for (var i = 0; i < root.usedDatesList.length; i++) {
                        root.dataCenter.addUsedVacationDate(root.usedDatesList[i])
                    }
                }
                root.dataCenter.completeOnboarding()
                root.finished()
            }
        }
    }

    SettingsModal {
        anchors.fill: parent
        open: root.settingsOpen
        onClosed: root.settingsOpen = false
    }
}
