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

    background: Rectangle { color: Style.background }

    readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var weekdaysDow: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var weekdaysShort: ["L", "M", "X", "J", "V", "S", "D"]
    readonly property int year: new Date().getFullYear()

    property int totalDays: dataCenter ? dataCenter.data.totalVacationDays : 22
    property string mode: "dates" // "dates" | "count"
    property int usedCount: 0
    property var usedDatesList: [] // ISO strings, sorted

    property bool picking: false
    property int calendarMonth: new Date().getMonth()
    property string dayManual: ""

    property bool hoursOpen: false
    property string hoursDate: ""
    property string hoursAmount: ""
    readonly property var hourEntries: dataCenter && dataCenter.data.usedVacationHourEntries ? dataCenter.data.usedVacationHourEntries : []

    readonly property int usedTotal: mode === "dates" ? usedDatesList.length : usedCount
    readonly property int leftDays: Math.max(0, totalDays - usedTotal)
    readonly property real usedPct: totalDays > 0 ? Math.min(1, usedCount / totalDays) : 0

    function isoFor(day, month) {
        return root.year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }

    function shortLabel(iso) {
        var p = iso.split("-")
        var d = parseInt(p[2]); var m = parseInt(p[1]) - 1
        return d + " de " + months[m] + " de " + p[0]
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

    // Holidays for the calendar year shown in the picker (already fetched
    // and cached during step 1), so the mini-calendar can mark national/
    // regional/local holidays with a colored dot, same as the real calendar.
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
        if (scope === "regional") return Style.scopeColor("regional")
        return Style.scopeColor("manual")
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
            linkText: "Atrás"
            onLinkClicked: root.back()
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

            ColumnLayout {
                id: pageColumn
                width: root.width
                spacing: Style.mediumSpace

                Item { Layout.preferredHeight: Style.smallSpace }

                // Title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 9

                    Image { source: Style.icon("calendar-check"); width: 32; height: 32; sourceSize: Qt.size(32, 32) }
                    Text {
                        text: "¿Ya has gastado días de vacaciones?"
                        font.family: Style.fontFamily
                        font.pixelSize: 27
                        font.weight: Font.Bold
                        font.letterSpacing: -0.8
                        color: Style.text
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Si apuntas las fechas verás tus vacaciones en el calendario. Si solo te interesa el saldo, con el número basta."
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
                        color: "#F1EBE0"

                        RowLayout {
                            id: modeTabsRow
                            anchors.centerIn: parent
                            spacing: 2

                            Button {
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
                                    text: "Apuntar fechas"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.mode === "dates" ? Style.primary : Style.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.mode = "dates"
                            }
                            Button {
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
                                    text: "Solo el número"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: root.mode === "count" ? Style.primary : Style.textSecondary
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
                            text: "RECOM."
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Style.primary
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
                            Text { text: "Días usados"; font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                            RowLayout {
                                spacing: 4
                                Text { text: root.usedTotal; font.family: Style.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.text }
                                Text { text: "de " + root.totalDays; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; Layout.alignment: Qt.AlignBaseline }
                            }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 34; color: "#EFEADF" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: "Te quedan"; font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                            RowLayout {
                                spacing: 4
                                Text { text: root.leftDays; font.family: Style.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.primary }
                                Text { text: "días"; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; Layout.alignment: Qt.AlignBaseline }
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

                    Rectangle {
                        visible: root.usedDatesList.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: datesColumn.implicitHeight + 8
                        radius: Style.listRadius
                        color: Style.surface
                        border.color: Style.divider
                        border.width: 1

                        ColumnLayout {
                            id: datesColumn
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 4
                            anchors.leftMargin: 16; anchors.rightMargin: 16
                            spacing: 0

                            Repeater {
                                model: root.usedDatesList
                                delegate: RowLayout {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.topMargin: index === 0 ? 12 : 0
                                    Layout.bottomMargin: 12
                                    spacing: 12

                                    Rectangle {
                                        width: 34; height: 34; radius: 11
                                        color: Style.scopeChipBg("nacional")
                                        Image { anchors.centerIn: parent; source: Style.icon("calendar"); width: 18; height: 18; sourceSize: Qt.size(18, 18) }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: root.shortLabel(modelData); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Style.text; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: root.weekdayLabel(modelData); font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary }
                                    }
                                    Rectangle {
                                        radius: 999
                                        color: Style.scopeChipBg("nacional")
                                        implicitWidth: dayTagText.implicitWidth + 18
                                        implicitHeight: dayTagText.implicitHeight + 12
                                        Text { id: dayTagText; anchors.centerIn: parent; text: "1 día"; font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; color: Style.primary }
                                    }
                                    Button {
                                        implicitWidth: 28; implicitHeight: 28
                                        background: Rectangle { color: "transparent" }
                                        contentItem: Text { text: "✕"; font.family: Style.fontFamily; font.pixelSize: 14; color: Style.textDisabled; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: root.toggleDate(modelData)
                                    }
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
                                    text: "Aún no has gastado nada"
                                    font.family: Style.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Style.text
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillWidth: true
                                    text: "Empiezas el año con los " + root.totalDays + " días intactos. Si ya cogiste alguno, añádelo abajo."
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
                                border.color: Style.primary
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
                                            implicitWidth: 30; implicitHeight: 30
                                            background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                            contentItem: Image { anchors.centerIn: parent; source: Style.icon("chevron-right"); width: 15; height: 15; sourceSize: Qt.size(15, 15); rotation: 180 }
                                            onClicked: root.calendarMonth = (root.calendarMonth + 11) % 12
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.months[root.calendarMonth] + " de " + root.year
                                            font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.text
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Button {
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

                                                    readonly property string iso: modelData.day > 0 ? root.isoFor(modelData.day, root.calendarMonth) : ""
                                                    readonly property var holiday: modelData.day > 0 ? root.holidayForDate(iso) : null
                                                    readonly property bool isWeekend: modelData.day > 0 && [0, 6].indexOf(new Date(root.year, root.calendarMonth, modelData.day).getDay()) !== -1
                                                    readonly property bool isSelected: modelData.day > 0 && root.usedDatesList.indexOf(iso) !== -1

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: dayCell.modelData.day > 0
                                                        radius: 10
                                                        color: dayCell.isSelected ? Style.primary : Style.background
                                                        border.color: dayCell.isSelected ? Style.primary : "#EFEADF"
                                                        border.width: 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: dayCell.modelData.day
                                                            font.family: Style.fontFamily
                                                            font.pixelSize: 13
                                                            font.weight: (dayCell.isSelected || dayCell.holiday) ? Font.Bold : Font.Medium
                                                            color: dayCell.isSelected ? "white"
                                                                   : dayCell.holiday ? root.dotColorFor(dayCell.holiday.scope)
                                                                   : dayCell.isWeekend ? "#B9C2C4" : Style.text
                                                        }
                                                        Rectangle {
                                                            visible: dayCell.holiday && !dayCell.isSelected
                                                            width: 4; height: 4; radius: 2
                                                            color: dayCell.holiday ? root.dotColorFor(dayCell.holiday.scope) : "transparent"
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            anchors.bottom: parent.bottom
                                                            anchors.bottomMargin: 4
                                                        }
                                                        TapHandler {
                                                            onTapped: root.toggleDate(dayCell.iso)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("nacional") }
                                            Text { text: "Nacional"; font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                        }
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("regional") }
                                            Text { text: "Autonómico"; font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
                                        }
                                        RowLayout {
                                            spacing: 5
                                            Rectangle { width: 7; height: 7; radius: 3.5; color: Style.scopeColor("manual") }
                                            Text { text: "Local"; font.family: Style.fontFamily; font.pixelSize: 10; color: Style.textSecondary }
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
                                            placeholderText: "dd/mm/aaaa"
                                            font.family: Style.fontFamily
                                            onTextEdited: root.dayManual = text
                                        }
                                        Button {
                                            implicitHeight: 40
                                            background: Rectangle { radius: 999; color: Style.primary }
                                            contentItem: Text { text: "Añadir"; font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                        Layout.fillWidth: true
                        implicitHeight: 50
                        background: Rectangle {
                            radius: 999
                            color: root.picking ? Style.scopeChipBg("nacional") : Style.surface
                            border.color: root.picking ? Style.primary : "#D5CEC0"
                            border.width: 1
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Image { source: Style.icon("plus"); width: 16; height: 16; sourceSize: Qt.size(16, 16) }
                            Text { text: "Añadir día usado"; font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.primary }
                        }
                        onClicked: root.picking = !root.picking
                    }

                    Button {
                        Layout.alignment: Qt.AlignLeft
                        Layout.topMargin: 2
                        implicitHeight: 26
                        background: Rectangle { color: "transparent" }
                        contentItem: Text {
                            text: (root.hoursOpen ? "− Ocultar" : "+ Añadir") + " horas sueltas"
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
                                        text: "Para ausencias más cortas que un día completo, en horas."
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
                                            placeholderText: "dd/mm"
                                            font.family: Style.fontFamily
                                            onTextEdited: root.hoursDate = text
                                        }
                                        TextField {
                                            Layout.preferredWidth: 56
                                            text: root.hoursAmount
                                            placeholderText: "h"
                                            horizontalAlignment: Text.AlignHCenter
                                            validator: IntValidator { bottom: 1; top: 24 }
                                            font.family: Style.fontFamily
                                            onTextEdited: root.hoursAmount = text
                                        }
                                        Button {
                                            Layout.fillWidth: true
                                            implicitHeight: 40
                                            background: Rectangle { radius: 999; color: Style.primary }
                                            contentItem: Text { text: "Añadir horas"; font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                                                    Text { id: hourTagText; anchors.centerIn: parent; text: modelData.hours + " h"; font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; color: Style.primary }
                                                }
                                                Button {
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
                            text: "DÍAS YA GASTADOS"
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
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("minus"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.usedCount = Math.max(0, root.usedCount - 1)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { Layout.alignment: Qt.AlignHCenter; text: root.usedCount; font.family: Style.fontFamily; font.pixelSize: 64; font.weight: Font.Bold; font.letterSpacing: -2.9; color: Style.text }
                                Text { Layout.alignment: Qt.AlignHCenter; text: "de " + root.totalDays + " días"; font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; color: Style.textSecondary }
                            }
                            Button {
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle { radius: 999; color: Style.background; border.color: Style.divider; border.width: 1 }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("plus"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.usedCount = Math.min(root.totalDays, root.usedCount + 1)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 7; radius: 99
                            color: "#F1EBE0"
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
            text: "Terminar"
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
}
