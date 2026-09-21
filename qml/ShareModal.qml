import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

// "Enviar planificación" bottom sheet: two tabs.
// - Email: opens a mailto: draft in the user's own mail client (there's no
//   SMTP backend in this app) with a prefilled subject/body, then marks
//   the sent days as "sent" locally.
// - Exportar: writes a real PDF/CSV/ICS file to ~/Downloads via the
//   Exporter singleton.
// No real delivery confirmation exists either way, so "send"/"save" just
// means "handed off to the OS" — the sheet reflects that honestly
// ("Correo preparado" / "Archivo guardado"), not "enviado".
//
// The scroll lives in the inner Flickable, never on the outer radiused
// `sheet` Rectangle — scrolling the radiused container itself makes the
// top corners look square and the scroll never reaches its true end.
Item {
    id: root
    property bool open: false
    property var dataCenter
    property var clipboard
    property var exporter
    property int calYear: new Date().getFullYear()
    property var months: []
    property var plannedRows: [] // [{date, estado, ambito}]
    property var holidaysThisYear: [] // [{date, scope, ...}] — CSV "festivo" rows only
    property string location: ""
    property int totalDays: 0
    property int usedCount: 0
    property int confirmedCount: 0
    property int plannedCount: 0
    property int availableCount: 0
    signal closed()

    visible: open
    z: 50

    property string activeTab: "email" // "email" | "export"
    property string resultState: "form" // "form" | "prepared" | "saved"
    property string savedFileName: ""

    property string recipientName: ""
    property string recipientEmail: ""
    property string senderEmail: ""
    property bool rememberChecked: false
    property bool messageExpanded: false
    property string subjectOverride: ""
    property string bodyOverride: ""
    property string exportFormat: "pdf" // "pdf" | "csv" | "ics"
    property string copyFeedback: ""
    property bool copySucceeded: false

    readonly property var monthAbbrev: [qsTr("ene"), qsTr("feb"), qsTr("mar"), qsTr("abr"), qsTr("may"), qsTr("jun"),
        qsTr("jul"), qsTr("ago"), qsTr("sep"), qsTr("oct"), qsTr("nov"), qsTr("dic")]

    Timer {
        id: copyFeedbackTimer
        interval: 1800
        onTriggered: { root.copyFeedback = ""; root.copySucceeded = false }
    }

    onOpenChanged: {
        if (!open) return
        resultState = "form"
        activeTab = "email"
        messageExpanded = false
        subjectOverride = ""
        bodyOverride = ""
        copyFeedback = ""
        var d = (root.dataCenter && root.dataCenter.data) ? root.dataCenter.data : {}
        recipientName = d.shareRecipientName || ""
        recipientEmail = d.shareRecipientEmail || ""
        senderEmail = d.shareSenderEmail || ""
        rememberChecked = false
    }

    function isValidEmail(e) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e || "")
    }
    function initialsOf(name) {
        var parts = (name || "").trim().split(/\s+/).filter(function(s) { return s.length > 0 })
        if (parts.length === 0) return "?"
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
        return (parts[0][0] + parts[1][0]).toUpperCase()
    }
    function firstName(name) {
        var t = (name || "").trim()
        return t ? t.split(/\s+/)[0] : ""
    }
    function fullDateLabel(iso) {
        var p = iso.split("-")
        return qsTr("%1 de %2 de %3").arg(parseInt(p[2])).arg(root.months[parseInt(p[1]) - 1] || "").arg(p[0])
    }
    function shortDateLabel(iso) {
        var p = iso.split("-")
        var y = parseInt(p[0])
        var label = parseInt(p[2]) + " " + root.monthAbbrev[parseInt(p[1]) - 1]
        if (y !== root.calYear) label += " " + String(y).slice(-2)
        return label
    }
    function defaultSubject() {
        var n = root.plannedRows.length
        return n === 1 ? qsTr("Solicitud de vacaciones · %1 día").arg(n) : qsTr("Solicitud de vacaciones · %1 días").arg(n)
    }
    function defaultBody() {
        var name = root.firstName(root.recipientName)
        var lines = []
        lines.push(name ? qsTr("Hola %1,").arg(name) : qsTr("Hola,"))
        lines.push("")
        lines.push(qsTr("Te paso los días de vacaciones que quiero solicitar:"))
        lines.push("")
        for (var i = 0; i < root.plannedRows.length; i++) {
            lines.push("· " + root.fullDateLabel(root.plannedRows[i].date))
        }
        lines.push("")
        var dayWord = root.plannedRows.length === 1 ? qsTr("día") : qsTr("días")
        lines.push(qsTr("Total: %1 %2. Me quedarían %3 disponibles de los %4 del año.")
            .arg(root.plannedRows.length).arg(dayWord).arg(root.availableCount).arg(root.totalDays))
        lines.push("")
        lines.push(qsTr("Gracias,"))
        lines.push(qsTr("Enviado con Vacaplan"))
        return lines.join("\n")
    }
    function effectiveSubject() {
        return root.subjectOverride.length > 0 ? root.subjectOverride : root.defaultSubject()
    }
    function effectiveBody() {
        return root.bodyOverride.length > 0 ? root.bodyOverride : root.defaultBody()
    }

    // Saves the current contact fields immediately when "Recordar" is
    // checked, instead of only at send time — so it's remembered even if
    // the user closes the sheet without sending (e.g. to export instead).
    function saveContactIfRemembered() {
        if (root.rememberChecked) {
            root.dataCenter.setShareContact(root.recipientName, root.recipientEmail, root.senderEmail)
        }
    }

    function isEmailReady() {
        return root.plannedRows.length > 0 && root.isValidEmail(root.recipientEmail)
    }
    function sendLabel() {
        if (root.plannedRows.length === 0) return qsTr("Nada que enviar")
        if (!root.isValidEmail(root.recipientEmail)) return qsTr("Falta el correo")
        return qsTr("Enviar por email")
    }
    function doSendEmail() {
        if (!root.isEmailReady()) return
        if (root.rememberChecked) {
            root.dataCenter.setShareContact(root.recipientName, root.recipientEmail, root.senderEmail)
        }
        for (var i = 0; i < root.plannedRows.length; i++) {
            root.dataCenter.setDaySent(root.plannedRows[i].date, true)
        }
        var mailto = "mailto:" + root.recipientEmail
            + "?subject=" + encodeURIComponent(root.effectiveSubject())
            + "&body=" + encodeURIComponent(root.effectiveBody())
            + (root.isValidEmail(root.senderEmail) ? "&from=" + encodeURIComponent(root.senderEmail) : "")
        Qt.openUrlExternally(mailto)
        root.resultState = "prepared"
    }

    function exportNote(fmt) {
        if (fmt === "pdf") return qsTr("Una página con el calendario y el desglose de días. Para firmar o archivar.")
        if (fmt === "csv") return qsTr("Una fila por día (fecha, estado, ámbito). Se abre directamente en Excel o Sheets.")
        return qsTr("Archivo .ics que tu responsable puede importar en Outlook o Google Calendar.")
    }
    function exportLabel() {
        if (root.plannedRows.length === 0) return qsTr("Nada que exportar")
        var fmtLabel = root.exportFormat === "pdf" ? qsTr("PDF") : root.exportFormat === "csv" ? qsTr("CSV") : qsTr("ICS")
        return qsTr("Guardar %1").arg(fmtLabel)
    }
    function modeSubtitle() {
        return root.activeTab === "email"
            ? qsTr("Comparte los días que aún no están aprobados para que tu responsable los valide.")
            : qsTr("Guarda un archivo con tus días para adjuntarlo donde quieras.")
    }
    function doExport() {
        if (root.plannedRows.length === 0 || !root.exporter) return
        var path = ""
        if (root.exportFormat === "csv") {
            path = root.exporter.exportCsv(root.plannedRows, root.holidaysThisYear, root.calYear)
        } else if (root.exportFormat === "ics") {
            path = root.exporter.exportIcs(root.plannedRows, root.calYear)
        } else {
            var summary = {
                location: root.location,
                used: root.usedCount,
                confirmed: root.confirmedCount,
                planned: root.plannedCount,
                available: root.availableCount
            }
            path = root.exporter.exportPdf(root.plannedRows, summary, root.calYear)
        }
        if (path && path.length > 0) {
            var parts = path.split("/")
            root.savedFileName = parts[parts.length - 1]
            root.resultState = "saved"
        }
    }

    function doCopyMessage() {
        var text = root.effectiveSubject() + "\n\n" + root.effectiveBody()
        var ok = root.clipboard ? root.clipboard.setText(text) : false
        root.copyFeedback = ok ? qsTr("Copiado") : qsTr("No se pudo copiar")
        root.copySucceeded = ok
        copyFeedbackTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: Style.scrim
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Rectangle {
        id: sheet
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 18
        height: Math.min(parent.height - 60, contentCol.implicitHeight + 40)
        radius: Style.heroRadius
        color: Style.surface
        clip: true // corners stay rounded even though the inner Flickable scrolls to the edge

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.topMargin: 22
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            // 18px bottom breathing room, deliberately left as unused space
            // below the layout rather than a bottom anchor margin — see
            // sheet.height's "+40" (22 top + 18 bottom).
            height: sheet.height - 40
            spacing: 14

            // ---- Result states ----
            ColumnLayout {
                visible: root.resultState === "prepared"
                Layout.fillWidth: true
                spacing: 13
                Rectangle {
                    width: 46; height: 46; radius: 15
                    color: Style.primary
                    Image { anchors.centerIn: parent; source: Style.icon("check-white"); width: 22; height: 22; sourceSize: Qt.size(22, 22) }
                }
                Text { text: qsTr("Correo preparado"); font.family: Style.fontFamily; font.pixelSize: 20; font.weight: Font.Bold; color: Style.text }
                Text {
                    Layout.fillWidth: true
                    text: root.plannedRows.length === 1
                        ? qsTr("%1 recibirá tu día en %2. Siguen marcados como planeados hasta que los apruebe.").arg(root.recipientName).arg(root.recipientEmail)
                        : qsTr("%1 recibirá tus %2 días en %3. Siguen marcados como planeados hasta que los apruebe.").arg(root.recipientName).arg(root.plannedRows.length).arg(root.recipientEmail)
                    font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textSecondary; wrapMode: Text.WordWrap
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Layout.fillWidth: true; Layout.topMargin: 3
                    implicitHeight: 50
                    background: Rectangle { radius: 999; color: Style.primary }
                    contentItem: Text { text: qsTr("Hecho"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.closed()
                }
            }

            ColumnLayout {
                visible: root.resultState === "saved"
                Layout.fillWidth: true
                spacing: 13
                Rectangle {
                    width: 46; height: 46; radius: 15
                    color: Style.primary
                    Image { anchors.centerIn: parent; source: Style.icon("check-white"); width: 22; height: 22; sourceSize: Qt.size(22, 22) }
                }
                Text { text: qsTr("Archivo guardado"); font.family: Style.fontFamily; font.pixelSize: 20; font.weight: Font.Bold; color: Style.text }
                Text {
                    Layout.fillWidth: true
                    text: root.plannedRows.length === 1
                        ? qsTr("Tu día está en %1 en Descargas. Puedes adjuntarlo donde quieras.").arg(root.savedFileName)
                        : qsTr("Tus %1 días están en %2 en Descargas. Puedes adjuntarlo donde quieras.").arg(root.plannedRows.length).arg(root.savedFileName)
                    font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textSecondary; wrapMode: Text.WordWrap
                }
                Button {
                    opacity: pressed ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Layout.fillWidth: true; Layout.topMargin: 3
                    implicitHeight: 50
                    background: Rectangle { radius: 999; color: Style.primary }
                    contentItem: Text { text: qsTr("Hecho"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.closed()
                }
            }

            // ---- Form (email / export) ----
            ColumnLayout {
                visible: root.resultState === "form"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Text {
                    text: root.activeTab === "email" ? qsTr("Enviar planificación") : qsTr("Exportar planificación")
                    font.family: Style.fontFamily; font.pixelSize: 20; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Style.text
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: tabRow.implicitHeight + 6
                    radius: 999
                    color: Style.track
                    RowLayout {
                        id: tabRow
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 2
                        Button {
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Layout.fillWidth: true
                            implicitHeight: 32
                            background: Rectangle {
                                radius: 999
                                color: root.activeTab === "email" ? Style.surface : "transparent"
                                layer.enabled: root.activeTab === "email"
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.12); shadowBlur: 0.4; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text { text: qsTr("Enviar por email"); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: root.activeTab === "email" ? Style.primaryInk : Style.textSecondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: root.activeTab = "email"
                        }
                        Button {
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Layout.fillWidth: true
                            implicitHeight: 32
                            background: Rectangle {
                                radius: 999
                                color: root.activeTab === "export" ? Style.surface : "transparent"
                                layer.enabled: root.activeTab === "export"
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.12); shadowBlur: 0.4; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text { text: qsTr("Exportar archivo"); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: root.activeTab === "export" ? Style.primaryInk : Style.textSecondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: root.activeTab = "export"
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.modeSubtitle()
                    font.family: Style.fontFamily; font.pixelSize: 13; color: Style.textSecondary; wrapMode: Text.WordWrap
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Contributes formColumn's real content height to
                    // contentCol.implicitHeight — without this, ColumnLayout
                    // treats a bare fillHeight Item as 0-height when computing
                    // its own implicitHeight, so `sheet.height` (which is
                    // capped via contentCol.implicitHeight) never grows enough
                    // to give the scrollable area any real room.
                    Layout.preferredHeight: formColumn.implicitHeight

                    Flickable {
                        id: formScroll
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: formColumn.implicitHeight
                        boundsBehavior: Flickable.DragOverBounds
                        interactive: contentHeight > height
                        ScrollBar.vertical: ScrollBar {}

                        ColumnLayout {
                            id: formColumn
                            width: formScroll.width
                            spacing: 16

                            // ---- Email tab ----
                            ColumnLayout {
                                visible: root.activeTab === "email"
                                Layout.fillWidth: true
                                spacing: 14

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 7
                                    Text { text: qsTr("ENVIAR DESDE"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.4; color: Style.textSecondary }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: senderRow.implicitHeight + 26
                                        radius: 18
                                        color: Style.background
                                        border.color: Style.divider
                                        border.width: 1
                                        RowLayout {
                                            id: senderRow
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: 14
                                            spacing: 10
                                            Rectangle {
                                                width: 34; height: 34; radius: 11
                                                color: root.isValidEmail(root.senderEmail) ? Style.withAlpha(Style.primary, 0.12) : Style.track
                                                Image {
                                                    anchors.centerIn: parent
                                                    source: root.isValidEmail(root.senderEmail) ? Style.icon("mail-teal") : Style.icon("mail")
                                                    width: 16; height: 16; sourceSize: Qt.size(16, 16)
                                                }
                                            }
                                            TextField {
                                                Layout.fillWidth: true
                                                text: root.senderEmail
                                                placeholderText: qsTr("tu@empresa.com (opcional)")
                                                placeholderTextColor: Style.textFaint
                                                color: Style.text
                                                font.family: Style.fontFamily
                                                background: null
                                                onTextEdited: { root.senderEmail = text; root.saveContactIfRemembered() }
                                            }
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.isValidEmail(root.senderEmail)
                                            ? qsTr("Tu app de correo se abrirá con esta cuenta seleccionada.")
                                            : qsTr("Opcional. Si lo indicas, abriremos el correo desde esa cuenta.")
                                        font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary; wrapMode: Text.WordWrap
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 7
                                    Text { text: qsTr("PARA"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.4; color: Style.textSecondary }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: paraRow.implicitHeight + 26
                                        radius: 18
                                        color: Style.background
                                        border.color: Style.divider
                                        border.width: 1
                                        RowLayout {
                                            id: paraRow
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: 14
                                            spacing: 10
                                            Rectangle {
                                                width: 38; height: 38; radius: 999
                                                color: root.isValidEmail(root.recipientEmail) ? Style.primaryInk : Style.textGhost
                                                Text { anchors.centerIn: parent; text: root.initialsOf(root.recipientName); font.family: Style.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: "white" }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                TextField {
                                                    Layout.fillWidth: true
                                                    text: root.recipientName
                                                    placeholderText: qsTr("Nombre del responsable")
                                                    placeholderTextColor: Style.textFaint
                                                    font.family: Style.fontFamily
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                    color: Style.text
                                                    background: null
                                                    topPadding: 0; bottomPadding: 0
                                                    onTextEdited: { root.recipientName = text; root.saveContactIfRemembered() }
                                                }
                                                TextField {
                                                    Layout.fillWidth: true
                                                    text: root.recipientEmail
                                                    placeholderText: qsTr("correo@empresa.com")
                                                    placeholderTextColor: Style.textFaint
                                                    font.family: Style.fontFamily
                                                    font.pixelSize: 12
                                                    color: Style.textSecondary
                                                    background: null
                                                    topPadding: 0; bottomPadding: 0
                                                    onTextEdited: { root.recipientEmail = text; root.saveContactIfRemembered() }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: root.recipientEmail.length > 0 && !root.isValidEmail(root.recipientEmail)
                                        Layout.fillWidth: true
                                        text: qsTr("Necesitamos un correo válido para abrir tu app de email.")
                                        font.family: Style.fontFamily; font.pixelSize: 11; color: Style.accent; wrapMode: Text.WordWrap
                                    }
                                    RowLayout {
                                        Layout.topMargin: 2
                                        spacing: 8

                                        // A plain MouseArea over the whole row, not a
                                        // TapHandler on just the checkbox square — mixing
                                        // TapHandler with the full-screen backdrop MouseArea
                                        // let taps here fall through and also trigger the
                                        // backdrop's onClicked, closing the whole sheet
                                        // before the checked state (or a save) ever landed.
                                        MouseArea {
                                            id: rememberArea
                                            anchors.fill: parent
                                            onClicked: {
                                                root.rememberChecked = !root.rememberChecked
                                                root.saveContactIfRemembered()
                                            }
                                        }

                                        Rectangle {
                                            width: 19; height: 19; radius: 6
                                            color: root.rememberChecked ? Style.primary : Style.background
                                            border.color: root.rememberChecked ? Style.primaryBorder : Style.divider
                                            border.width: 1
                                            Image {
                                                anchors.centerIn: parent
                                                visible: root.rememberChecked
                                                source: Style.icon("check-white")
                                                width: 11; height: 11; sourceSize: Qt.size(11, 11)
                                            }
                                        }
                                        Text {
                                            text: qsTr("Recordar para los próximos envíos")
                                            font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: msgHeaderRow.implicitHeight + 20
                                        topLeftRadius: 14; topRightRadius: 14
                                        bottomLeftRadius: root.messageExpanded ? 0 : 14
                                        bottomRightRadius: root.messageExpanded ? 0 : 14
                                        color: Style.background
                                        RowLayout {
                                            id: msgHeaderRow
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: 12
                                            spacing: 8
                                            Text { text: qsTr("MENSAJE"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.4; color: Style.textSecondary }
                                            Text { visible: root.copyFeedback.length > 0; text: root.copyFeedback; font.family: Style.fontFamily; font.pixelSize: 10; color: Style.primaryInk }
                                            Item { Layout.fillWidth: true }
                                            Button {
                                                opacity: pressed ? 0.6 : 1.0
                                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                                implicitHeight: 24
                                                background: Rectangle { radius: 999; color: "transparent"; border.color: Style.divider; border.width: 1 }
                                                contentItem: Text { text: root.copySucceeded ? qsTr("Copiado") : qsTr("Copiar"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: root.copySucceeded ? Style.primaryInk : Style.textSecondary; horizontalAlignment: Text.AlignHCenter; leftPadding: 4; rightPadding: 4 }
                                                onClicked: root.doCopyMessage()
                                            }
                                            Button {
                                                opacity: pressed ? 0.6 : 1.0
                                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                                implicitHeight: 24
                                                background: Rectangle { color: "transparent" }
                                                contentItem: Text { text: root.messageExpanded ? qsTr("Ocultar") : qsTr("Editar"); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Style.primaryInk }
                                                onClicked: root.messageExpanded = !root.messageExpanded
                                            }
                                        }
                                    }
                                    Item {
                                        id: expandableWrap
                                        Layout.fillWidth: true
                                        clip: true
                                        implicitHeight: root.messageExpanded ? expandableCol.implicitHeight : 0
                                        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        opacity: root.messageExpanded ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }

                                        ColumnLayout {
                                            id: expandableCol
                                            width: expandableWrap.width
                                            spacing: 8
                                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Style.divider }
                                            TextField {
                                                Layout.fillWidth: true
                                                text: root.effectiveSubject()
                                                color: Style.text
                                                font.family: Style.fontFamily
                                                font.weight: Font.Bold
                                                background: Rectangle { color: "transparent"; border.color: Style.divider; border.width: 0; anchors.bottom: parent.bottom }
                                                onTextEdited: root.subjectOverride = text
                                            }
                                            TextArea {
                                                id: bodyArea
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 190
                                                text: root.effectiveBody()
                                                color: Style.text
                                                wrapMode: Text.WordWrap
                                                font.family: Style.fontFamily
                                                font.pixelSize: 12
                                                background: Rectangle { radius: 12; color: Style.sunken; border.color: Style.divider; border.width: 1 }
                                                onTextChanged: if (activeFocus) root.bodyOverride = text
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTr("Se guarda solo. Si lo dejas en blanco usaremos el texto por defecto.")
                                                font.family: Style.fontFamily; font.pixelSize: 11; color: Style.textSecondary; wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }

                            }

                            // ---- QUÉ SE ENVÍA — shared between both tabs ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: qsTr("QUÉ SE ENVÍA"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.4; color: Style.textSecondary }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: root.plannedRows.length > 0
                                    Repeater {
                                        model: root.plannedRows
                                        delegate: Rectangle {
                                            required property var modelData
                                            radius: 999
                                            color: Qt.rgba(255 / 255, 107 / 255, 74 / 255, 0.13)
                                            border.color: Qt.rgba(255 / 255, 107 / 255, 74 / 255, 0.34)
                                            border.width: 1
                                            implicitWidth: chipText.implicitWidth + 22
                                            implicitHeight: chipText.implicitHeight + 14
                                            Text { id: chipText; anchors.centerIn: parent; text: root.shortDateLabel(parent.modelData.date); font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Style.accent }
                                        }
                                    }
                                }
                                Text {
                                    visible: root.plannedRows.length === 0
                                    Layout.fillWidth: true
                                    text: qsTr("No tienes días sin confirmar. Marca algunos en el calendario para poder enviarlos.")
                                    font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; wrapMode: Text.WordWrap
                                }
                            }

                            // ---- Export tab ----
                            ColumnLayout {
                                visible: root.activeTab === "export"
                                Layout.fillWidth: true
                                spacing: 10

                                Text { text: qsTr("FORMATO"); font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.4; color: Style.textSecondary }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 7
                                    Repeater {
                                        model: [ { k: "pdf", label: qsTr("PDF") }, { k: "csv", label: qsTr("CSV") }, { k: "ics", label: qsTr("Calendario") } ]
                                        delegate: Button {
                                            id: fmtButton
                                            required property var modelData
                                            opacity: pressed ? 0.6 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            implicitHeight: 40
                                            background: Rectangle {
                                                radius: 999
                                                color: root.exportFormat === fmtButton.modelData.k ? Style.primary : Style.background
                                                border.color: root.exportFormat === fmtButton.modelData.k ? Style.primaryBorder : Style.divider
                                                border.width: 1
                                            }
                                            contentItem: Text {
                                                text: fmtButton.modelData.label
                                                font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                                                color: root.exportFormat === fmtButton.modelData.k ? "white" : Style.textSecondary
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                leftPadding: 14; rightPadding: 14
                                            }
                                            onClicked: root.exportFormat = fmtButton.modelData.k
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.exportNote(root.exportFormat)
                                    font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary; wrapMode: Text.WordWrap
                                }
                            }

                            Item { Layout.preferredHeight: 18 }
                        }
                    }

                    // Scroll fade indicator: fades in as content remains below the fold.
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 52
                        opacity: Math.max(0, Math.min(1, (formScroll.contentHeight - formScroll.contentY - formScroll.height - 4) / 70))
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(31 / 255, 42 / 255, 46 / 255, 0.07) }
                            GradientStop { position: 1.0; color: Qt.rgba(31 / 255, 42 / 255, 46 / 255, 0.18) }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 9
                    Button {
                        id: sendButton
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 52
                        enabled: root.activeTab === "email" ? root.isEmailReady() : root.plannedRows.length > 0
                        background: Rectangle {
                            radius: 999
                            color: sendButton.enabled ? (root.activeTab === "email" ? Style.accent : Style.primary) : Style.track
                            layer.enabled: sendButton.enabled
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(14 / 255, 124 / 255, 123 / 255, 0.26); shadowBlur: 0.6; shadowVerticalOffset: 6 }
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            Image {
                                id: sendIcon
                                visible: root.activeTab === "email"
                                source: Style.icon("share-white")
                                width: 16; height: 16; sourceSize: Qt.size(16, 16)
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: sendButton.enabled ? "white" : Style.textGhost
                                }
                            }
                            Text {
                                text: root.activeTab === "email" ? root.sendLabel() : root.exportLabel()
                                font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                                color: sendButton.enabled ? "white" : Style.textGhost
                            }
                            Item { Layout.fillWidth: true }
                        }
                        onClicked: root.activeTab === "email" ? root.doSendEmail() : root.doExport()
                    }
                    Text {
                        visible: root.activeTab === "email"
                        Layout.fillWidth: true
                        text: qsTr("Se abrirá tu app de correo con el mensaje listo para enviar.")
                        font.family: Style.fontFamily; font.pixelSize: 12; color: Style.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 46
                        background: Rectangle { radius: 999; color: Style.surface; border.color: Style.divider; border.width: 1 }
                        contentItem: Text { text: qsTr("Cancelar"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.textSecondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: root.closed()
                    }
                }
            }
        }
    }
}
