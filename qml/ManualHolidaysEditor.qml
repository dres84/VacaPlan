import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

// Manual holidays editor with a real calendar: each row has a date field
// (dd/mm) editable by hand and a button that opens a month grid to tap the
// day. Saves via HolidayProvider.saveManualHolidays in YYYY-MM-DD format.
ColumnLayout {
    id: root
    property int year: 2026
    property var holidayProvider
    signal saved()

    readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var weekdays: ["L", "M", "X", "J", "V", "S", "D"]

    spacing: Style.smallSpace

    ListModel { id: entriesModel }

    function ddmm(iso) {
        if (!iso || iso.indexOf("-") === -1) return iso || ""
        var p = iso.split("-")
        return p[2] + "/" + p[1]
    }

    function monthFromDdmm(text) {
        var m = /^(\d{1,2})\s*\/\s*(\d{1,2})/.exec(text || "")
        return m ? Math.min(11, Math.max(0, parseInt(m[2], 10) - 1)) : 0
    }

    function isoFor(day, month) {
        return root.year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }

    Text {
        text: "Festivos de " + root.year
        font.family: Style.fontFamily
        font.pixelSize: Style.semi
        font.weight: Font.Bold
        color: Style.text
    }

    Repeater {
        model: entriesModel
        delegate: ColumnLayout {
            id: rowItem
            required property int index
            required property string date
            required property string name
            required property bool pickerOpen
            required property int pickerMonth

            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    Layout.preferredWidth: 76
                    text: rowItem.date
                    placeholderText: "dd/mm"
                    font.family: Style.fontFamily
                    onTextEdited: entriesModel.setProperty(rowItem.index, "date", text)
                }

                Button {
                    implicitWidth: 42; implicitHeight: 40
                    background: Rectangle {
                        radius: 12
                        color: rowItem.pickerOpen ? Style.primary : Style.surface
                        border.color: rowItem.pickerOpen ? Style.primary : Style.divider
                        border.width: 1
                    }
                    contentItem: Image {
                        anchors.centerIn: parent
                        source: Style.icon("calendar")
                        width: 17; height: 17
                        sourceSize: Qt.size(17, 17)
                    }
                    onClicked: {
                        var opening = !rowItem.pickerOpen
                        entriesModel.setProperty(rowItem.index, "pickerOpen", opening)
                        if (opening) entriesModel.setProperty(rowItem.index, "pickerMonth", root.monthFromDdmm(rowItem.date))
                    }
                }

                TextField {
                    Layout.fillWidth: true
                    text: rowItem.name
                    placeholderText: "Nombre del festivo"
                    font.family: Style.fontFamily
                    onTextEdited: entriesModel.setProperty(rowItem.index, "name", text)
                }

                ToolButton {
                    text: "✕"
                    onClicked: entriesModel.remove(rowItem.index)
                }
            }

            Loader {
                Layout.fillWidth: true
                active: rowItem.pickerOpen
                visible: active
                sourceComponent: Component {
                    Rectangle {
                        implicitHeight: pickerColumn.implicitHeight + 24
                        radius: 16
                        color: Style.background
                        border.color: Style.divider
                        border.width: 1
                        opacity: 0
                        y: 14
                        Component.onCompleted: {
                            opacity = 1; y = 0
                        }
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

                        ColumnLayout {
                            id: pickerColumn
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Button {
                                    implicitWidth: 28; implicitHeight: 28
                                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                                    contentItem: Image {
                                        anchors.centerIn: parent
                                        source: Style.icon("chevron-right")
                                        width: 15; height: 15
                                        sourceSize: Qt.size(15, 15)
                                        rotation: 180
                                    }
                                    onClicked: entriesModel.setProperty(rowItem.index, "pickerMonth", (rowItem.pickerMonth + 11) % 12)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.months[rowItem.pickerMonth] + " de " + root.year
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.semi
                                    font.weight: Font.Bold
                                    color: Style.text
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Button {
                                    implicitWidth: 28; implicitHeight: 28
                                    background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                                    contentItem: Image {
                                        anchors.centerIn: parent
                                        source: Style.icon("chevron-right")
                                        width: 15; height: 15
                                        sourceSize: Qt.size(15, 15)
                                    }
                                    onClicked: entriesModel.setProperty(rowItem.index, "pickerMonth", (rowItem.pickerMonth + 1) % 12)
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
                                    rowSpacing: 2
                                    columnSpacing: 2

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
                                        model: {
                                            var first = new Date(root.year, rowItem.pickerMonth, 1)
                                            var lead = (first.getDay() + 6) % 7
                                            var days = new Date(root.year, rowItem.pickerMonth + 1, 0).getDate()
                                            var cells = []
                                            for (var i = 0; i < lead; i++) cells.push({ day: 0 })
                                            for (var d = 1; d <= days; d++) cells.push({ day: d })
                                            return cells
                                        }
                                        delegate: Item {
                                            required property var modelData
                                            width: (dayGrid.width - dayGrid.columnSpacing * 6) / 7
                                            height: 30

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: modelData.day > 0
                                                radius: 9
                                                readonly property bool isSelected: modelData.day > 0 && rowItem.date === root.ddmm(root.isoFor(modelData.day, rowItem.pickerMonth))
                                                color: isSelected ? Style.primary : Style.surface
                                                border.color: isSelected ? Style.primary : Style.divider
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.day
                                                    font.family: Style.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: parent.isSelected ? Font.Bold : Font.Medium
                                                    color: parent.isSelected ? "white" : Style.text
                                                }
                                                TapHandler {
                                                    onTapped: {
                                                        entriesModel.setProperty(rowItem.index, "date", root.ddmm(root.isoFor(modelData.day, rowItem.pickerMonth)))
                                                        entriesModel.setProperty(rowItem.index, "pickerOpen", false)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Button {
        Layout.topMargin: 2
        implicitHeight: 34
        implicitWidth: addRow.implicitWidth + 25
        background: Rectangle {
            radius: 999
            color: "transparent"
            border.color: Style.divider
            border.width: 1
        }
        contentItem: RowLayout {
            id: addRow
            spacing: 6
            Image { source: Style.icon("plus"); width: 14; height: 14; sourceSize: Qt.size(14, 14) }
            Text {
                text: "Añadir fila"
                font.family: Style.fontFamily
                font.pixelSize: Style.caption
                font.weight: Font.Medium
                color: Style.primary
            }
        }
        onClicked: entriesModel.append({ date: "", name: "", pickerOpen: false, pickerMonth: 0 })
    }

    Text {
        visible: entriesModel.count === 0
        text: "Añade al menos un festivo (por ejemplo, el 1 de enero) para poder continuar."
        color: Style.textSecondary
        font.family: Style.fontFamily
        font.pixelSize: Style.caption
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Button {
        Layout.topMargin: 4
        implicitHeight: 38
        implicitWidth: saveLabel.implicitWidth + 34
        enabled: entriesModel.count > 0
        background: Rectangle { radius: 999; color: parent.enabled ? Style.primary : Style.primaryDisabled }
        contentItem: Text {
            id: saveLabel
            text: "Guardar " + root.year
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
                if (!item.date || item.date.indexOf("/") === -1) continue
                var parts = item.date.split("/")
                var iso = root.year + "-" + parts[1].padStart(2, "0") + "-" + parts[0].padStart(2, "0")
                newEntries.push({ date: iso, name: item.name, scope: "manual" })
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
