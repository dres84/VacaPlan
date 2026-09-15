import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

Page {
    id: root
    property var dataCenter
    property var holidayProvider
    signal locationConfirmed()

    background: Rectangle { color: Style.background }

    readonly property int currentYear: new Date().getFullYear()
    readonly property int nextYear: currentYear + 1

    property string country: "ES"
    property var comunidades: []
    property var provincias: []
    property var municipios: []

    property string ccaaSlug: ""
    property string ccaaName: ""
    property string provinciaSlug: ""
    property string provinciaName: ""
    property string municipioSlug: ""
    property string municipioName: ""
    property bool skipMunicipio: false

    property bool fetching: false
    property bool readyCurrent: false
    property bool readyNext: false
    property bool errorCurrent: false
    property bool errorNext: false
    property int countCurrent: 0
    property int countNext: 0

    property string open: "com"
    property bool esExiting: false
    property string muniQuery: ""

    readonly property bool canSearch: country === "ES" ? (ccaaSlug !== "" && (municipioSlug !== "" || skipMunicipio)) : false
    // The next year never blocks: its calendar is almost never published
    // yet and onboarding doesn't offer manual editing for it (see
    // nextYearLocked/nextYearOk). Continue only depends on the current year.
    readonly property bool currentYearOk: readyCurrent && !currentYearNeedsLocal
    readonly property bool nextYearOk: readyNext && countNext >= expectedHolidaysPerYear
    readonly property bool nextYearLocked: (readyNext && countNext < expectedHolidaysPerYear) || errorNext
    readonly property bool canContinue: currentYearOk

    readonly property bool showSearchButton: canSearch && !fetching && !readyCurrent && !readyNext && !errorCurrent && !errorNext

    // Spain has 14 public holidays a year (national/regional + 2 local
    // ones each town council decides). The official calendar almost never
    // includes the local ones, so if the current year arrives with fewer
    // than 14, adding them by hand is offered right away — no need to
    // wait, it's the year in progress. The next year can wait (its local
    // calendar usually isn't even decided yet).
    readonly property int expectedHolidaysPerYear: 14
    readonly property bool currentYearNeedsLocal: root.readyCurrent && root.countCurrent < root.expectedHolidaysPerYear

    function normalizeText(t) {
        var combiningMarks = new RegExp("[" + String.fromCharCode(0x300) + "-" + String.fromCharCode(0x36f) + "]", "g")
        return t.normalize("NFD").replace(combiningMarks, "").toLowerCase()
    }

    // The API doesn't give population. Since that data isn't available, we
    // prioritize using a fixed list of the most populated Spanish
    // municipalities (largest to smallest); the rest keeps the API's order.
    // It's not an exact/up-to-date ranking, but it keeps capitals and big
    // cities from getting buried among hamlets when alphabetized.
    readonly property var bigMunicipioNames: [
        "madrid", "barcelona", "valencia", "sevilla", "zaragoza", "malaga", "murcia",
        "palma de mallorca", "las palmas de gran canaria", "bilbao", "alicante", "cordoba",
        "valladolid", "vigo", "gijon", "l'hospitalet de llobregat", "vitoria-gasteiz",
        "a coruna", "granada", "elche", "oviedo", "badalona", "cartagena", "terrassa",
        "jerez de la frontera", "sabadell", "mostoles", "alcala de henares", "pamplona",
        "fuenlabrada", "almeria", "leganes", "santander", "burgos", "castellon de la plana",
        "donostia", "san sebastian", "getafe", "albacete", "alcorcon", "logrono",
        "badajoz", "salamanca", "huelva", "marbella", "lleida", "tarragona", "leon",
        "cadiz", "dos hermanas", "torrejon de ardoz", "parla", "mataro",
        "santa cruz de tenerife", "telde", "algeciras", "jaen", "ourense", "reus",
        "girona", "barakaldo", "coslada", "sant cugat del valles", "rubi", "alcobendas",
        "torrent", "manresa", "el puerto de santa maria", "ferrol", "roquetas de mar",
        "chiclana de la frontera", "torremolinos", "fuengirola", "gandia", "avila",
        "toledo", "caceres", "lugo", "pontevedra", "melilla", "ceuta",
        "santiago de compostela", "linares", "motril", "ecija", "utrera", "arona",
        "san cristobal de la laguna", "talavera de la reina", "aranjuez",
        "rivas-vaciamadrid", "las rozas de madrid", "pozuelo de alarcon",
        "majadahonda", "collado villalba", "alcazar de san juan", "puertollano",
        "ciudad real", "guadalajara", "aviles", "siero", "langreo",
        "santa coloma de gramenet", "cornella de llobregat", "sant boi de llobregat",
        "viladecans", "el prat de llobregat", "granollers", "vilanova i la geltru",
        "vic", "figueres", "olot", "orihuela", "torrevieja", "benidorm", "elda",
        "alcoy", "denia", "cuenca", "segovia", "soria", "palencia", "zamora",
        "teruel", "huesca", "vilagarcia de arousa", "naron", "monforte de lemos",
        "arrecife", "puerto del rosario", "san bartolome de tirajana", "adeje",
        "santa lucia de tirajana", "eivissa", "mao-mahon", "manacor",
        "calvia", "marratxi"
    ]
    // Backs up the ranking above: for each of the 52 Spanish provinces,
    // its most populated municipalities from largest to smallest (approx.,
    // from general knowledge, not an exact official figure). Used before
    // bigMunicipioNames because it's scoped to the selected province, so it
    // also correctly orders towns that aren't big nationally but are the
    // biggest within their own province.
    readonly property var provinceBigTowns: ({
        "A Coruña": ["A Coruña", "Santiago de Compostela", "Ferrol", "Narón", "Oleiros", "Culleredo", "Arteixo", "Ribeira", "Carballo", "Cambre"],
        "Albacete": ["Albacete", "Hellín", "Villarrobledo", "La Roda", "Almansa", "Tobarra", "Caudete", "Casas-Ibáñez"],
        "Alicante": ["Alicante", "Elche", "Torrevieja", "Orihuela", "Benidorm", "Elda", "Alcoy", "Dénia", "San Vicente del Raspeig", "Villena", "Ibi", "Petrer"],
        "Almería": ["Almería", "Roquetas de Mar", "El Ejido", "Níjar", "Adra", "Vícar", "Huércal-Overa", "Vera"],
        "Asturias": ["Gijón", "Oviedo", "Avilés", "Siero", "Langreo", "Mieres", "Castrillón", "Corvera de Asturias", "Villaviciosa"],
        "Badajoz": ["Badajoz", "Mérida", "Don Benito", "Almendralejo", "Villanueva de la Serena", "Zafra", "Montijo", "Olivenza"],
        "Baleares": ["Palma de Mallorca", "Calvià", "Manacor", "Eivissa", "Llucmajor", "Marratxí", "Inca", "Ciutadella de Menorca", "Maó-Mahón"],
        "Barcelona": ["Barcelona", "L'Hospitalet de Llobregat", "Badalona", "Terrassa", "Sabadell", "Mataró", "Santa Coloma de Gramenet", "Cornellà de Llobregat", "Sant Boi de Llobregat", "Manresa", "Rubí", "Vilanova i la Geltrú", "Viladecans", "Granollers", "Cerdanyola del Vallès", "Sant Cugat del Vallès", "Mollet del Vallès"],
        "Burgos": ["Burgos", "Aranda de Duero", "Miranda de Ebro"],
        "Cantabria": ["Santander", "Torrelavega", "Camargo", "Castro-Urdiales", "Piélagos", "El Astillero", "Santoña"],
        "Castellón": ["Castellón de la Plana", "Vila-real", "Burriana", "Vinaròs", "Onda", "Almazora", "Benicàssim"],
        "Ciudad Real": ["Ciudad Real", "Puertollano", "Tomelloso", "Alcázar de San Juan", "Valdepeñas", "Manzanares", "Daimiel"],
        "Cuenca": ["Cuenca", "Tarancón", "San Clemente"],
        "Cáceres": ["Cáceres", "Plasencia", "Navalmoral de la Mata", "Coria", "Trujillo"],
        "Cádiz": ["Jerez de la Frontera", "Algeciras", "Cádiz", "San Fernando", "El Puerto de Santa María", "Chiclana de la Frontera", "Sanlúcar de Barrameda", "La Línea de la Concepción", "Rota", "Arcos de la Frontera", "Barbate", "Conil de la Frontera"],
        "Córdoba": ["Córdoba", "Lucena", "Puente Genil", "Priego de Córdoba", "Montilla", "Cabra", "Palma del Río"],
        "Girona": ["Girona", "Figueres", "Blanes", "Olot", "Lloret de Mar", "Salt", "Roses", "Sant Feliu de Guíxols", "Palafrugell"],
        "Granada": ["Granada", "Motril", "Almuñécar", "Armilla", "Maracena", "Baza", "Loja", "Las Gabias"],
        "Guadalajara": ["Guadalajara", "Azuqueca de Henares", "Cabanillas del Campo"],
        "Guipúzcoa": ["Donostia", "Irún", "Errenteria", "Eibar", "Zarautz", "Hernani"],
        "Huelva": ["Huelva", "Lepe", "Almonte", "Isla Cristina", "Ayamonte", "Moguer"],
        "Huesca": ["Huesca", "Barbastro", "Monzón", "Fraga", "Jaca"],
        "Jaén": ["Jaén", "Linares", "Andújar", "Úbeda", "Martos", "Alcalá la Real"],
        "La Rioja": ["Logroño", "Calahorra", "Arnedo", "Haro"],
        "Las Palmas": ["Las Palmas de Gran Canaria", "Telde", "Arrecife", "San Bartolomé de Tirajana", "Santa Lucía de Tirajana", "Puerto del Rosario", "Ingenio", "Agüimes"],
        "León": ["León", "Ponferrada", "San Andrés del Rabanedo", "Villaquilambre", "Astorga"],
        "Lleida": ["Lleida", "Balaguer", "Mollerussa", "Tàrrega", "Cervera"],
        "Lugo": ["Lugo", "Vilalba", "Monforte de Lemos", "Viveiro"],
        "Madrid": ["Madrid", "Móstoles", "Alcalá de Henares", "Fuenlabrada", "Leganés", "Getafe", "Alcorcón", "Torrejón de Ardoz", "Parla", "Alcobendas", "Las Rozas de Madrid", "San Sebastián de los Reyes", "Pozuelo de Alarcón", "Coslada", "Rivas-Vaciamadrid", "Majadahonda", "Collado Villalba", "Aranjuez"],
        "Murcia": ["Murcia", "Cartagena", "Lorca", "Molina de Segura", "Alcantarilla", "Mazarrón", "Águilas", "Yecla", "Cieza"],
        "Málaga": ["Málaga", "Marbella", "Vélez-Málaga", "Fuengirola", "Mijas", "Torremolinos", "Estepona", "Rincón de la Victoria", "Benalmádena", "Antequera"],
        "Navarra": ["Pamplona", "Tudela", "Barañáin", "Burlada"],
        "Ourense": ["Ourense", "Verín", "O Carballiño"],
        "Palencia": ["Palencia", "Aguilar de Campoo", "Guardo", "Venta de Baños"],
        "Pontevedra": ["Vigo", "Pontevedra", "Vilagarcía de Arousa", "Redondela", "Cangas", "Marín", "Ponteareas", "O Porriño"],
        "Salamanca": ["Salamanca", "Santa Marta de Tormes", "Béjar"],
        "Santa Cruz de Tenerife": ["Santa Cruz de Tenerife", "San Cristóbal de La Laguna", "Arona", "Adeje", "Puerto de la Cruz", "Granadilla de Abona", "Los Realejos", "Icod de los Vinos"],
        "Segovia": ["Segovia", "Cuéllar"],
        "Sevilla": ["Sevilla", "Dos Hermanas", "Alcalá de Guadaíra", "Utrera", "Écija", "Mairena del Aljarafe", "Los Palacios y Villafranca", "Coria del Río", "San Juan de Aznalfarache"],
        "Soria": ["Soria"],
        "Tarragona": ["Tarragona", "Reus", "El Vendrell", "Cambrils", "Salou", "Tortosa", "Amposta", "Valls"],
        "Teruel": ["Teruel", "Alcañiz"],
        "Toledo": ["Toledo", "Talavera de la Reina", "Illescas", "Seseña", "Torrijos"],
        "Valencia": ["Valencia", "Torrent", "Gandia", "Paterna", "Sagunto", "Alzira", "Xàtiva", "Ontinyent", "Cullera", "Manises"],
        "Valladolid": ["Valladolid", "Medina del Campo", "Laguna de Duero", "Arroyo de la Encomienda"],
        "Vizcaya": ["Bilbao", "Barakaldo", "Getxo", "Portugalete", "Santurtzi", "Basauri", "Leioa", "Erandio", "Sestao", "Durango"],
        "Zamora": ["Zamora", "Benavente", "Toro"],
        "Zaragoza": ["Zaragoza", "Calatayud", "Utebo", "Ejea de los Caballeros", "Tarazona"],
        "Álava": ["Vitoria-Gasteiz", "Amurrio", "Llodio"],
        "Ávila": ["Ávila", "Arévalo"],
        "Ceuta": ["Ceuta"],
        "Melilla": ["Melilla"]
    })
    readonly property var muniOrdered: {
        var list = root.municipios.slice()
        var provinceList = root.provinceBigTowns[root.provinciaName] || []
        var big = root.bigMunicipioNames
        var articles = ["el ", "la ", "los ", "las ", "a ", "o ", "l'"]
        function exactMatch(n, b) {
            if (n === b) return true
            for (var a = 0; a < articles.length; a++) {
                if (b.indexOf(articles[a]) === 0) {
                    var rest = b.slice(articles[a].length)
                    var art = articles[a].trim()
                    if (n === rest + ", " + art) return true
                }
            }
            return false
        }
        function rankOf(name) {
            // Exact match, not substring: otherwise "madrid" matches inside
            // "Humanes de Madrid" or "Rivas-Vaciamadrid", and those ties beat
            // the actual capital on alphabetical order. The API also inverts
            // the article ("Rozas de Madrid, Las") and uses bilingual names
            // separated by "/" in several regions (e.g. "Alicante/Alacant",
            // "Donostia/San Sebastián"), so those variants are tried too.
            // The current province's list is checked first (more precise),
            // and only if not found there is the national big-city list
            // tried.
            var variants = [normalizeText(name)]
            if (name.indexOf("/") !== -1) {
                var parts = name.split("/")
                for (var p = 0; p < parts.length; p++) variants.push(normalizeText(parts[p]))
            }
            for (var i = 0; i < provinceList.length; i++) {
                var pb = normalizeText(provinceList[i])
                for (var v = 0; v < variants.length; v++) {
                    if (exactMatch(variants[v], pb)) return i
                }
            }
            for (var j = 0; j < big.length; j++) {
                for (var v2 = 0; v2 < variants.length; v2++) {
                    if (exactMatch(variants[v2], big[j])) return provinceList.length + j
                }
            }
            return provinceList.length + big.length + 1
        }
        var decorated = list.map(function (m, i) { return { m: m, rank: rankOf(m.name), idx: i } })
        decorated.sort(function (a, b) {
            if (a.rank !== b.rank) return a.rank - b.rank
            return a.idx - b.idx
        })
        return decorated.map(function (d) { return d.m })
    }
    readonly property var muniMatches: {
        var q = root.muniQuery.trim()
        if (!q) return root.muniOrdered
        var n = normalizeText(q)
        return root.muniOrdered.filter(function (m) { return normalizeText(m.name).indexOf(n) !== -1 })
    }
    readonly property var muniOptionNames: root.muniMatches.slice(0, 10).map(function (m) { return m.name })
    readonly property string muniHint: {
        var q = root.muniQuery.trim()
        if (root.municipios.length === 0) return ""
        if (!q) return root.municipios.length + " municipios en la provincia · escribe para buscar los más pequeños"
        if (root.muniMatches.length === 0) return "Ningún municipio coincide con «" + q + "». Marca la casilla de abajo y usaremos solo los festivos autonómicos."
        if (root.muniMatches.length > 10) return "Mostrando 10 de " + root.muniMatches.length + " · sigue escribiendo para afinar"
        return ""
    }

    function clearResults() {
        fetching = false
        readyCurrent = false; readyNext = false
        errorCurrent = false; errorNext = false
        countCurrent = 0; countNext = 0
    }

    function resetLocationState() {
        country = "ES"
        ccaaSlug = ""; ccaaName = ""
        provinciaSlug = ""; provinciaName = ""
        municipioSlug = ""; municipioName = ""
        provincias = []; municipios = []
        skipMunicipio = false
        muniQuery = ""
        open = "com"
        clearResults()
    }

    function pickCountry(c) {
        if (c === root.country) return
        if (c === "OTHER") {
            root.esExiting = true
            exitTimer.start()
        } else {
            resetLocationState()
        }
    }

    function pickComunidad(name) {
        var item = root.comunidades.find(function (c) { return c.name === name })
        if (!item) return
        root.ccaaSlug = item.slug; root.ccaaName = item.name
        root.provinciaSlug = ""; root.provinciaName = ""
        root.municipioSlug = ""; root.municipioName = ""
        root.provincias = []; root.municipios = []
        root.skipMunicipio = false
        root.muniQuery = ""
        root.clearResults()
        root.open = "prov"
        holidayProvider.fetchProvincias(root.currentYear, root.ccaaSlug)
    }

    function pickProvincia(name) {
        var item = root.provincias.find(function (p) { return p.name === name })
        if (!item) return
        root.provinciaSlug = item.slug; root.provinciaName = item.name
        root.municipioSlug = ""; root.municipioName = ""
        root.municipios = []
        root.skipMunicipio = false
        root.muniQuery = ""
        root.clearResults()
        root.open = "muni"
        holidayProvider.fetchMunicipios(root.currentYear, root.ccaaSlug, root.provinciaSlug)
    }

    function pickMunicipio(name) {
        var item = root.municipios.find(function (m) { return m.name === name })
        if (!item) return
        root.municipioSlug = item.slug; root.municipioName = item.name
        root.clearResults()
        root.open = ""
    }

    function toggleSkipMunicipio() {
        root.skipMunicipio = !root.skipMunicipio
        if (root.skipMunicipio) { root.municipioSlug = ""; root.municipioName = "" }
        root.clearResults()
        root.open = ""
    }

    function startFetch() {
        fetching = true
        readyCurrent = false; readyNext = false
        errorCurrent = false; errorNext = false
        holidayProvider.fetchHolidays(currentYear, ccaaSlug, provinciaSlug, skipMunicipio ? "" : municipioSlug)
        holidayProvider.fetchHolidays(nextYear, ccaaSlug, provinciaSlug, skipMunicipio ? "" : municipioSlug)
    }

    function switchToOtherCountry() {
        country = "OTHER"
        fetching = false
        readyCurrent = false; readyNext = false
        errorCurrent = true; errorNext = true // forces the manual editor for both years
    }

    Timer {
        id: exitTimer
        interval: 190
        onTriggered: {
            root.switchToOtherCountry()
            root.esExiting = false
        }
    }

    Connections {
        target: holidayProvider
        function onComunidadesReady(year, list) { comunidades = list }
        function onProvinciasReady(year, list) {
            provincias = list
            // Single-province regions (Asturias, Madrid, Murcia...): it
            // makes no sense to ask the user to pick from a single option,
            // it self-selects and moves straight to Municipio.
            if (list.length === 1) root.pickProvincia(list[0].name)
        }
        function onMunicipiosReady(year, list) {
            municipios = list
            // The municipio list arrives over the network and can take
            // longer than the accordion's opening animation: if it's still
            // open when it arrives, the scroll needs recalculating with the
            // real size.
            if (root.open === "muni" && municipioLoader.item) root.scheduleEnsureVisible(municipioLoader.item, checkboxLoader)
        }
        function onHolidaysReady(year, holidays) {
            if (year === root.currentYear) { readyCurrent = true; errorCurrent = false; countCurrent = holidays.length }
            else if (year === root.nextYear) { readyNext = true; errorNext = false; countNext = holidays.length }
            if (readyCurrent && readyNext) fetching = false
        }
        function onHolidaysError(year, message) {
            if (year === root.currentYear) errorCurrent = true
            else if (year === root.nextYear) errorNext = true
            if (!fetching) return
            fetching = false
        }
    }

    Component.onCompleted: holidayProvider.fetchComunidades(currentYear)

    // The blocks that appear have their own entrance animation
    // (opacity/y, ~280ms). If we compute the scroll while that animation is
    // still running, we'd aim at a position that's still moving. That's why
    // the actual calculation is delayed until that animation finishes.
    Timer {
        id: ensureVisibleTimer
        property var targetItem: null
        property var targetBottomItem: null
        interval: 300
        onTriggered: root.ensureVisible(targetItem, targetBottomItem)
    }
    // `bottomItem` is optional: if given, it tries to show the whole span
    // from the start of `item` to the end of `bottomItem` (for example,
    // opening Municipio needs to reach down to the checkbox below it).
    function scheduleEnsureVisible(item, bottomItem) {
        ensureVisibleTimer.targetItem = item
        ensureVisibleTimer.targetBottomItem = bottomItem || null
        ensureVisibleTimer.restart()
    }

    // Scrolls just enough so `item` (through `bottomItem`, if given) is
    // visible with a 16px margin, animated. Called after mounting each
    // block that appears.
    function ensureVisible(item, bottomItem) {
        if (!item) return
        var flick = scrollView
        var pad = 16
        // Position relative to the visible viewport (already accounts for
        // the current scroll offset, so 0 = visible top edge).
        var pos = item.mapToItem(flick, 0, 0)
        var itemTop = pos.y
        var bottomRef = (bottomItem && bottomItem.height > 0) ? bottomItem : item
        var posBottom = bottomRef.mapToItem(flick, 0, 0)
        var itemBottom = posBottom.y + bottomRef.height
        var totalHeight = itemBottom - itemTop
        var viewH = flick.height
        var delta = 0
        var fitsInView = (totalHeight + pad * 2) <= viewH
        if (fitsInView) {
            if (itemBottom + pad > viewH) delta = itemBottom + pad - viewH
            else if (itemTop - pad < 0) delta = itemTop - pad
        } else if (itemTop < 0 || itemBottom > viewH) {
            // Doesn't fit whole: prioritize showing it from its start.
            delta = itemTop - pad
        }
        if (delta === 0) return
        var target = flick.contentY + delta
        target = Math.max(0, Math.min(target, Math.max(0, flick.contentHeight - flick.height)))
        scrollAnimation.to = target
        scrollAnimation.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: Style.smallSpace }

        StepHeader {
            step: 1
            linkText: "Reiniciar"
            onLinkClicked: root.resetLocationState()
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
                spacing: 10

                Image { source: Style.icon("location-pin"); width: 34; height: 34; sourceSize: Qt.size(34, 34) }
                Text {
                    text: "¿Dónde vives?"
                    font.family: Style.fontFamily
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    font.letterSpacing: -0.9
                    color: Style.text
                }
                Text {
                    text: "Con tu ubicación cargamos los festivos nacionales, autonómicos, provinciales y locales que te corresponden. Puedes cambiarla cuando quieras."
                    font.family: Style.fontFamily
                    font.pixelSize: 14
                    color: Style.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Country selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                spacing: 10

                Text {
                    text: "PAÍS"
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0.4
                    color: Style.textSecondary
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 72
                        background: Rectangle {
                            radius: 22
                            color: root.country === "ES" ? "#E6F0EF" : Style.surface
                            border.color: root.country === "ES" ? Style.primary : Style.divider
                            border.width: root.country === "ES" ? 1.5 : 1
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            anchors.left: parent.left; anchors.leftMargin: 18
                            Image { source: Style.icon("flag-spain"); width: 34; height: 23; sourceSize: Qt.size(34, 23) }
                            Text {
                                text: "España"
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: root.country === "ES" ? Style.primary : Style.textSecondary
                            }
                        }
                        onClicked: root.pickCountry("ES")
                    }
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 72
                        background: Rectangle {
                            radius: 22
                            color: root.country === "OTHER" ? "#E6F0EF" : Style.surface
                            border.color: root.country === "OTHER" ? Style.primary : Style.divider
                            border.width: root.country === "OTHER" ? 1.5 : 1
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            anchors.left: parent.left; anchors.leftMargin: 18
                            Image {
                                source: Style.icon(root.country === "OTHER" ? "globe-active" : "globe")
                                width: 30; height: 20; sourceSize: Qt.size(30, 20)
                            }
                            Text {
                                text: "Otro país"
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: root.country === "OTHER" ? Style.primary : Style.textSecondary
                            }
                        }
                        onClicked: root.pickCountry("OTHER")
                    }
                }
            }

            // Spain block: comunidad / provincia / municipio / checkbox
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                active: root.country === "ES" || root.esExiting
                visible: active
                onLoaded: root.scheduleEnsureVisible(item)
                sourceComponent: Component {
                    ColumnLayout {
                        id: esWrap
                        Layout.fillWidth: true
                        spacing: 0
                        property bool revealed: false
                        opacity: !revealed ? 0 : (root.esExiting ? 0 : 1)
                        y: !revealed ? 14 : (root.esExiting ? -10 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.esExiting ? 180 : 280
                                easing.type: root.esExiting ? Easing.InQuad : Easing.OutQuint
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: root.esExiting ? 180 : 280
                                easing.type: root.esExiting ? Easing.InQuad : Easing.OutQuint
                            }
                        }
                        Component.onCompleted: revealed = true

                        AccordionSelect {
                            id: comunidadField
                            Layout.fillWidth: true
                            label: "COMUNIDAD AUTÓNOMA"
                            value: root.ccaaName
                            placeholder: "Elige tu comunidad"
                            options: root.comunidades.map(function (c) { return c.name })
                            open: root.open === "com"
                            onToggled: root.open = (root.open === "com" ? "" : "com")
                            onOptionPicked: (opt) => root.pickComunidad(opt)
                            onExpanded: root.scheduleEnsureVisible(comunidadField)
                        }

                        Loader {
                            Layout.fillWidth: true
                            active: root.ccaaSlug !== ""
                            visible: active
                            onLoaded: root.scheduleEnsureVisible(item)
                            sourceComponent: Component {
                                AccordionSelect {
                                    id: provinciaField
                                    Layout.fillWidth: true
                                    property bool revealed: false
                                    opacity: revealed ? 1 : 0
                                    y: revealed ? 0 : 14
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Component.onCompleted: revealed = true

                                    label: "PROVINCIA"
                                    value: root.provinciaName
                                    placeholder: "Elige tu provincia"
                                    options: root.provincias.map(function (p) { return p.name })
                                    open: root.open === "prov"
                                    onToggled: root.open = (root.open === "prov" ? "" : "prov")
                                    onOptionPicked: (opt) => root.pickProvincia(opt)
                                    onExpanded: root.scheduleEnsureVisible(provinciaField)
                                }
                            }
                        }

                        Loader {
                            id: municipioLoader
                            Layout.fillWidth: true
                            active: root.provinciaSlug !== "" && !root.skipMunicipio
                            visible: active
                            onLoaded: root.scheduleEnsureVisible(item, checkboxLoader)
                            sourceComponent: Component {
                                AccordionSelect {
                                    id: municipioField
                                    Layout.fillWidth: true
                                    property bool revealed: false
                                    opacity: revealed ? 1 : 0
                                    y: revealed ? 0 : 14
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Component.onCompleted: revealed = true

                                    label: "MUNICIPIO"
                                    value: root.municipioName
                                    placeholder: "Busca tu municipio"
                                    searchable: true
                                    query: root.muniQuery
                                    searchPlaceholder: "Busca tu municipio"
                                    options: root.muniOptionNames
                                    hintText: root.muniHint
                                    open: root.open === "muni"
                                    onToggled: root.open = (root.open === "muni" ? "" : "muni")
                                    onOptionPicked: (opt) => root.pickMunicipio(opt)
                                    onQueryEdited: (t) => root.muniQuery = t
                                    onExpanded: root.scheduleEnsureVisible(municipioField, checkboxLoader)
                                }
                            }
                        }

                        Loader {
                            id: checkboxLoader
                            Layout.fillWidth: true
                            active: root.provinciaSlug !== ""
                            visible: active
                            onLoaded: root.scheduleEnsureVisible(item)
                            sourceComponent: Component {
                                Button {
                                    opacity: pressed ? 0.6 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                    id: unknownBtn
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 12
                                    implicitHeight: 56
                                    property bool revealed: false
                                    opacity: revealed ? 1 : 0
                                    y: revealed ? 0 : 14
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                                    Component.onCompleted: staggerTimer.start()
                                    Timer { id: staggerTimer; interval: 70; onTriggered: unknownBtn.revealed = true }

                                    background: Rectangle {
                                        radius: 18
                                        color: root.skipMunicipio ? "#E6F0EF" : Style.surface
                                        border.color: root.skipMunicipio ? Style.primary : Style.divider
                                        border.width: root.skipMunicipio ? 1.5 : 1
                                    }
                                    contentItem: RowLayout {
                                        spacing: 12
                                        anchors.left: parent.left; anchors.leftMargin: 16
                                        anchors.right: parent.right; anchors.rightMargin: 16

                                        Rectangle {
                                            width: 22; height: 22; radius: 7
                                            color: root.skipMunicipio ? Style.primary : Style.background
                                            border.color: root.skipMunicipio ? Style.primary : "#D5CEC0"
                                            border.width: 1.5
                                            Item {
                                                anchors.centerIn: parent
                                                width: 12; height: 9
                                                visible: root.skipMunicipio
                                                Rectangle { width: 6; height: 2; radius: 1; color: "white"; rotation: 45; x: 0; y: 5 }
                                                Rectangle { width: 10; height: 2; radius: 1; color: "white"; rotation: -45; x: 3; y: 3 }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "No sé mi municipio, usar solo festivos autonómicos"
                                            font.family: Style.fontFamily
                                            font.pixelSize: 13
                                            color: Style.text
                                            wrapMode: Text.WordWrap
                                            horizontalAlignment: Text.AlignLeft
                                        }
                                    }
                                    onClicked: root.toggleSkipMunicipio()
                                }
                            }
                        }
                    }
                }
            }

            // Search button
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                active: root.showSearchButton
                visible: active
                onLoaded: root.scheduleEnsureVisible(item)
                sourceComponent: Component {
                    Button {
                        opacity: pressed ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Layout.fillWidth: true
                        implicitHeight: 54
                        property bool revealed: false
                        opacity: revealed ? 1 : 0
                        y: revealed ? 0 : 14
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Component.onCompleted: revealed = true

                        background: Rectangle { radius: 999; color: Style.accent }
                        contentItem: Text {
                            text: "Buscar festivos"
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.startFetch()
                    }
                }
            }

            // Loading
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                active: root.fetching
                visible: active
                onLoaded: root.scheduleEnsureVisible(item)
                sourceComponent: Component {
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 54
                        property bool revealed: false
                        opacity: revealed ? 1 : 0
                        y: revealed ? 0 : 14
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Component.onCompleted: revealed = true

                        radius: 999
                        color: Style.surface
                        border.color: Style.divider
                        border.width: 1
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 11
                            BusyIndicator { running: true; implicitWidth: 20; implicitHeight: 20 }
                            Text {
                                text: "Consultando festivos oficiales…"
                                font.family: Style.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: Style.textSecondary
                            }
                        }
                    }
                }
            }

            // Current year result
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                active: root.readyCurrent || root.errorCurrent
                visible: active
                onLoaded: root.scheduleEnsureVisible(item)
                sourceComponent: Component {
                    Rectangle {
                        Layout.fillWidth: true
                        property bool revealed: false
                        opacity: revealed ? 1 : 0
                        y: revealed ? 0 : 14
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Component.onCompleted: revealed = true

                        implicitHeight: resultColCurrent.implicitHeight + 36
                        radius: Style.listRadius
                        color: Style.surface
                        border.color: root.readyCurrent ? Style.divider : "#FFB8A8"
                        border.width: 1

                        ColumnLayout {
                            id: resultColCurrent
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    width: 34; height: 34; radius: 11
                                    color: root.readyCurrent ? Style.scopeChipBg("nacional") : Style.scopeChipBg("regional")
                                    Image {
                                        anchors.centerIn: parent
                                        source: Style.icon(root.readyCurrent ? "check-circle" : "alert-circle")
                                        width: 19; height: 19; sourceSize: Qt.size(19, 19)
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 3
                                    Text {
                                        text: root.readyCurrent ? ("Festivos de " + root.currentYear + " cargados") : ("No hemos podido cargar " + root.currentYear)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: Style.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.readyCurrent ? (root.countCurrent + " festivos oficiales") : "El calendario oficial todavía no está publicado. Añádelos a mano y podrás editarlos después."
                                        font.family: Style.fontFamily
                                        font.pixelSize: 13
                                        color: Style.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    radius: 999
                                    color: "#F4EFE5"
                                    implicitWidth: yearChipCurrent.implicitWidth + 18
                                    implicitHeight: yearChipCurrent.implicitHeight + 12
                                    Text {
                                        id: yearChipCurrent
                                        anchors.centerIn: parent
                                        text: String(root.currentYear)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Style.textSecondary
                                    }
                                }
                            }

                            ManualHolidaysEditor {
                                visible: root.errorCurrent
                                Layout.fillWidth: true
                                year: root.currentYear
                                holidayProvider: root.holidayProvider
                                onSaved: { root.readyCurrent = true; root.errorCurrent = false }
                            }

                            ColumnLayout {
                                visible: root.currentYearNeedsLocal
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Style.divider
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Image { source: Style.icon("alert-circle"); width: 16; height: 16; sourceSize: Qt.size(16, 16) }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "España tiene 14 festivos al año y solo hemos encontrado " + root.countCurrent
                                              + " para " + root.currentYear + " — el calendario oficial casi nunca trae los locales."
                                              + " Añade los que falten:"
                                        font.family: Style.fontFamily
                                        font.pixelSize: 13
                                        color: Style.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                ManualHolidaysEditor {
                                    Layout.fillWidth: true
                                    year: root.currentYear
                                    holidayProvider: root.holidayProvider
                                }
                            }
                        }
                    }
                }
            }

            // Next year result: only "ok" or "locked" (informational). The
            // upcoming year never offers manual editing in onboarding — its
            // calendar is almost never published yet; it'll get completed
            // later from Home when it's time.
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.mediumMargin
                Layout.rightMargin: Style.mediumMargin
                active: root.nextYearOk || root.nextYearLocked
                visible: active
                onLoaded: root.scheduleEnsureVisible(item)
                sourceComponent: Component {
                    Rectangle {
                        Layout.fillWidth: true
                        property bool revealed: false
                        opacity: revealed ? 1 : 0
                        y: revealed ? 0 : 14
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Component.onCompleted: revealed = true

                        implicitHeight: resultColNext.implicitHeight + 36
                        radius: Style.listRadius
                        color: Style.surface
                        border.color: Style.divider
                        border.width: 1

                        ColumnLayout {
                            id: resultColNext
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    width: 34; height: 34; radius: 11
                                    color: root.nextYearOk ? Style.scopeChipBg("nacional") : "rgba(107,122,128,.12)"
                                    Image {
                                        anchors.centerIn: parent
                                        source: Style.icon(root.nextYearOk ? "check-circle" : "calendar-locked")
                                        width: 19; height: 19; sourceSize: Qt.size(19, 19)
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 3
                                    Text {
                                        text: root.nextYearOk ? ("Festivos de " + root.nextYear + " cargados") : ("El calendario de " + root.nextYear + " aún no está publicado")
                                        font.family: Style.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: Style.text
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.nextYearOk ? (root.countNext + " festivos oficiales") : "Te avisaremos en cuanto esté disponible. También podrás añadirlo desde Ajustes cuando quieras."
                                        font.family: Style.fontFamily
                                        font.pixelSize: 13
                                        color: Style.textSecondary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    radius: 999
                                    color: "#F4EFE5"
                                    implicitWidth: yearChipNext.implicitWidth + 18
                                    implicitHeight: yearChipNext.implicitHeight + 12
                                    Text {
                                        id: yearChipNext
                                        anchors.centerIn: parent
                                        text: String(root.nextYear)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Style.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Final margin: whatever the last visible block is at any
            // point in the flow (checkbox, search, results...), it should
            // never sit flush against the bottom edge of the scroll area.
            Item { Layout.preferredHeight: Style.mediumMargin }
        }
    }

    OnboardingFooter {
        text: "Continuar"
        baseColor: Style.primary
        buttonEnabled: root.canContinue
        onClicked: {
            root.dataCenter.setLocation(root.country, root.ccaaSlug, root.ccaaName,
                                         root.provinciaSlug, root.provinciaName,
                                         root.municipioSlug, root.municipioName)
            root.locationConfirmed()
        }
    }
    }
}
