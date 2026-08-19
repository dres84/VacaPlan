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

    background: Rectangle { color: Style.background }

    readonly property int currentYear: new Date().getFullYear()
    readonly property int nextYear: currentYear + 1
    property int selectedYear: currentYear

    property var profile: dataCenter ? dataCenter.data : ({})
    readonly property int totalDays: profile.totalVacationDays !== undefined ? profile.totalVacationDays : 0
    readonly property int usedDays: profile.usedVacationMode === "count"
                                     ? (profile.usedVacationCount || 0)
                                     : (profile.usedVacationDates ? profile.usedVacationDates.length : 0)
    readonly property int remainingDays: Math.max(0, totalDays - usedDays)
    readonly property real usedPct: totalDays > 0 ? Math.min(1, usedDays / totalDays) : 0

    property var holidaysList: []
    property var nextHoliday: null
    property bool showManualEditor: false

    function isoToday() {
        var d = new Date()
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }

    function shortDate(iso) {
        if (!iso) return ""
        var parts = iso.split("-")
        var months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        return parseInt(parts[2]) + " " + months[parseInt(parts[1]) - 1]
    }

    function reloadHolidays() {
        holidaysList = holidayProvider.loadCachedHolidays(selectedYear)

        var combined = holidayProvider.loadCachedHolidays(currentYear).concat(holidayProvider.loadCachedHolidays(nextYear))
        var today = isoToday()
        nextHoliday = null
        for (var i = 0; i < combined.length; i++) {
            if (combined[i].date >= today) { nextHoliday = combined[i]; break }
        }
    }

    onSelectedYearChanged: {
        showManualEditor = false
        reloadHolidays()
    }
    Component.onCompleted: reloadHolidays()

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: homeColumn.implicitHeight
        boundsBehavior: Flickable.DragOverBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {}

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
                    onClicked: {
                        root.dataCenter.resetOnboarding()
                        root.restartOnboarding()
                    }
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

            // Hero card
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
                    spacing: 10

                    Text {
                        text: "DÍAS DISPONIBLES"
                        font.family: Style.fontFamily
                        font.pixelSize: Style.caption
                        font.weight: Font.Medium
                        font.letterSpacing: 0.7
                        color: "#E8F5F4"
                    }
                    RowLayout {
                        spacing: 10
                        Text {
                            text: root.remainingDays
                            font.family: Style.fontFamily
                            font.pixelSize: Style.heroSize
                            font.weight: Font.Bold
                            font.letterSpacing: -3.4
                            color: "white"
                        }
                        Text {
                            text: "/ " + root.totalDays + " días"
                            font.family: Style.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.Medium
                            color: "#E8F5F4"
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 9
                        Rectangle {
                            Layout.fillWidth: true
                            height: 7; radius: 99
                            color: "#FFFFFF"; opacity: 0.22
                            Rectangle {
                                height: parent.height; radius: 99
                                color: Style.accent
                                width: parent.width * root.usedPct
                                Behavior on width { NumberAnimation { duration: Style.animationTime } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.usedDays + " usados"
                                font.family: Style.fontFamily
                                font.pixelSize: Style.caption
                                color: "#E8F5F4"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: String(root.currentYear)
                                font.family: Style.fontFamily
                                font.pixelSize: Style.caption
                                color: "#E8F5F4"
                            }
                        }
                    }
                }
            }

            // Mini cards: used / next holiday
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                spacing: Style.smallSpace

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    radius: Style.cardRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        Image { source: Style.icon("calendar-check"); width: 21; height: 21; sourceSize: Qt.size(21, 21) }
                        RowLayout {
                            spacing: 4
                            Text { text: "Ya usados"; font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                        }
                        RowLayout {
                            spacing: 4
                            Text { text: root.usedDays; font.family: Style.fontFamily; font.pixelSize: Style.heading2; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.text }
                            Text { text: "días"; font.family: Style.fontFamily; font.pixelSize: Style.caption; color: Style.textSecondary; Layout.alignment: Qt.AlignBaseline }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    radius: Style.cardRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.04; shadowBlur: 0.4; shadowVerticalOffset: 2 }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        Image { source: Style.icon("beach-umbrella"); width: 21; height: 21; sourceSize: Qt.size(21, 21) }
                        Text { text: "Próximo festivo"; font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary }
                        RowLayout {
                            spacing: 4
                            Text {
                                text: root.nextHoliday ? root.shortDate(root.nextHoliday.date) : "—"
                                font.family: Style.fontFamily; font.pixelSize: Style.heading2; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.text
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
                    text: "Festivos"
                    font.family: Style.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Style.text
                }
                Text {
                    text: root.holidaysList.length ? root.holidaysList.length + " en " + root.selectedYear : ""
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

            // Holidays list
            Rectangle {
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
                        model: root.holidaysList
                        delegate: Rectangle {
                            id: holidayRow
                            required property var modelData
                            required property int index
                            property bool open: false

                            Layout.fillWidth: true
                            implicitHeight: 68
                            radius: 12
                            color: open ? Style.scopeChipBg(modelData.scope) : "transparent"

                            Rectangle {
                                visible: holidayRow.index > 0
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                height: 1
                                color: Style.divider
                            }

                            MouseArea {
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
                                        text: holidayRow.modelData.date
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
        }
    }
}
