pragma Singleton
import QtQuick
import QtCore

QtObject {
    readonly property FontLoader dmSansLoader: FontLoader { source: "qrc:/fonts/DM_Sans.ttf" }
    readonly property string fontFamily: dmSansLoader.name.length > 0 ? dmSansLoader.name : "DM Sans"

    // ---- Theme mode ----
    // 0 = follow the system, 1 = force light, 2 = force dark. Persisted so
    // an explicit choice survives a restart; "auto" re-evaluates live if the
    // OS theme changes (Application.styleHints.colorScheme is a live signal
    // since Qt 6.5, no restart needed).
    readonly property Settings themeSettings: Settings {
        id: themeSettingsObj
        category: "appearance"
        property int mode: 0
    }
    property alias mode: themeSettingsObj.mode
    readonly property bool dark: mode === 2 || (mode === 0 && Application.styleHints.colorScheme === Qt.Dark)

    // ---- Surfaces & ink ----
    // Every screen reads these — never a literal hex — so toggling `dark`
    // recolors the whole app without touching a single view.
    readonly property color background: dark ? "#121A1B" : "#FBF7F0"
    readonly property color surface: dark ? "#1A2426" : "#FFFFFF"
    // Sunken surfaces (fields, calendar cells) sit a level above background,
    // not at background level, or they vanish against the card that holds
    // them.
    readonly property color sunken: dark ? "#26312F" : "#FBF7F0"
    readonly property color soft: dark ? "#232E2C" : "#F1EBDD"
    readonly property color divider: dark ? "#2C3A3C" : "#E4DED2"
    readonly property color dividerSoft: dark ? "#26302F" : "#EFEADF"
    readonly property color track: dark ? "#233032" : "#F1EBE0"
    readonly property color weekend: dark ? "#1E2828" : "#F4EFE5"
    readonly property color cellBorder: dark ? "#3A4746" : "#EFEADF"

    // Dark ink is a warm off-white (#EDEAE3), not pure white — it answers
    // the cream of light mode instead of clashing with it.
    readonly property color text: dark ? "#EDEAE3" : "#1F2A2E"
    readonly property color textSecondary: dark ? "#93A1A3" : "#6B7A80"
    readonly property color textFaint: dark ? "#7C8B8D" : "#9AA6AA"
    readonly property color textGhost: dark ? "#6E7C7E" : "#B9C2C4"
    readonly property color textDisabled: dark ? "#5C6B6D" : "#A9B4B8"

    // ---- Brand (structural — never a state or a scope value) ----
    // The hero teal itself doesn't change: in dark mode it's the one bright
    // surface on the screen and becomes the natural focal point. Teal AS
    // TEXT does change — #0E7C7B on #121A1B falls short of 4.5:1.
    readonly property color primary: "#0E7C7B"
    readonly property color primaryInk: dark ? "#63D8D6" : "#0E7C7B"
    readonly property color primaryBorder: dark ? "#14A3A1" : "#0E7C7B"
    readonly property color primaryPressed: dark ? "#0B5E5D" : "#0B5E5D"
    readonly property color primaryDisabled: dark ? "#2E4B4A" : "#A9CFCE"

    readonly property color accent: "#FF6B4A"
    readonly property color accentPressed: "#D9502F"
    readonly property color accentDisabled: "#F7C3B4"

    readonly property color buttonPositive: "#0E7C7B"
    readonly property color buttonPositivePressed: "#0B5E5D"
    readonly property color buttonPositiveDisabled: "#A9CFCE"

    readonly property color buttonNegative: "#E15B4E"
    readonly property color buttonNegativePressed: "#B7402F"
    readonly property color buttonNegativeDisabled: "#F1B8AF"

    readonly property color buttonNeutral: "#7C8B90"
    readonly property color buttonNeutralPressed: "#5E6A6E"
    readonly property color buttonNeutralDisabled: "#D3D9DB"

    readonly property color buttonText: "#FFFFFF"
    readonly property color buttonTextDisabled: "#F1EEEA"

    // ---- Shadows & veils ----
    // Dark mode loses shadow-as-depth-cue almost entirely (a soft shadow on
    // a dark background barely reads), so cards there lean on the
    // surface-vs-background step instead — the shadow tokens still exist so
    // cards keep *some* separation, just not the primary one.
    readonly property color shadowCard: dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0.122, 0.165, 0.18, 0.04)
    readonly property color shadowSheet: dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0.122, 0.165, 0.18, 0.3)
    readonly property color scrim: dark ? Qt.rgba(0, 0, 0, 0.62) : Qt.rgba(0.122, 0.165, 0.18, 0.42)
    readonly property color scrollFade: dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0.122, 0.165, 0.18, 0.18)

    // Text sizes
    readonly property int heroSize: 48
    readonly property int bigSize: 30
    readonly property int heading1: 24
    readonly property int heading2: 20
    readonly property int body: 16
    readonly property int semi: 14
    readonly property int caption: 12

    // Spacing
    readonly property int bigSpace: 20
    readonly property int mediumSpace: 12
    readonly property int smallSpace: 6

    // Border radii
    readonly property int smallRadius: 6
    readonly property int mediumRadius: 12
    readonly property int largeRadius: 18
    readonly property int extraLargeRadius: 28

    // Home-specific radii (hero card / list / mini-cards)
    readonly property int cardRadius: 20
    readonly property int listRadius: 22
    readonly property int heroRadius: 26

    // Margins
    readonly property int smallMargin: 16
    readonly property int mediumMargin: 28

    readonly property int animationTime: 200

    function icon(name) {
        return "qrc:/icons/" + name + ".svg"
    }

    // Flag/badge icon per holiday scope. Each SVG already comes colored
    // with the tone from scopeColor() for that scope.
    function scopeIcon(scope) {
        switch (scope) {
            case "nacional": return icon("flag-national")
            // The real API returns "autonomico" (no accent); "regional" is
            // kept as an alias since some UI reuses these tokens decoratively
            // (e.g. a coral badge) without an actual holiday scope behind it.
            case "autonomico":
            case "regional": return icon("flag-region")
            case "provincial": return icon("flag-provincial")
            case "local": return icon("flag-local")
            case "manual": return icon("bookmark-manual")
            default: return ""
        }
    }

    function scopeLabel(scope) {
        switch (scope) {
            case "nacional": return qsTr("Nacional")
            case "autonomico":
            case "regional": return qsTr("Autonómico")
            case "provincial": return qsTr("Provincial")
            case "local": return qsTr("Local")
            case "manual": return qsTr("Manual")
            default: return scope
        }
    }

    // ---- Color system ----
    // One color, one meaning across the whole app. Two families that share
    // no hue: Familia A is "your days" (states you chose — warm), Familia B
    // is holidays (data handed to you — cool). Brand teal (primary) is
    // purely structural — chrome, buttons, active-field borders — and never
    // stands for a state or a scope. fill is for solid fills (cells, bars,
    // dots), ink is text-on-light-app-background (fills don't hit 4.5:1 as
    // text), on is the text color that sits on top of a solid fill.
    //
    // In light mode ink is darker than its fill; in dark mode ink is
    // lighter.
    //
    // stateFill()/stateOn() are deliberately NOT theme-aware: each fill is
    // dark/saturated enough (>=4.5:1) to always take plain white on top, so
    // the pair is self-contained regardless of the app's light/dark mode.
    // "Disponible" is the one exception — a light beige by design (it means
    // "no data"), so it keeps dark text instead.

    // Familia A — day-mark states (used/confirmed/planned/available).
    // Planeado is a darker red-orange (not the old bright coral, which only
    // hit 2.7:1 with white) so it can take white text like the other three.
    function stateFill(state) {
        switch (state) {
            case "used": return "#5E6B7A"
            case "confirmed": return "#1B7F4D"
            case "planned": return "#C4471F"
            case "available": return "#DCD5C7"
            default: return textSecondary
        }
    }
    function stateInk(state) {
        switch (state) {
            case "used": return dark ? "#A6B2C0" : "#4A5563"
            case "confirmed": return dark ? "#6DD9A0" : "#146138"
            case "planned": return dark ? "#FFAD94" : "#C0341A"
            case "available": return textSecondary
            default: return textSecondary
        }
    }
    // Color of the text/icon drawn on top of a solid stateFill() fill.
    function stateOn(state) {
        switch (state) {
            case "used": return "#FFFFFF"
            case "confirmed": return "#FFFFFF"
            case "planned": return "#FFFFFF"
            case "available": return "#1F2A2E"
            default: return "#FFFFFF"
        }
    }
    // Light variants for used/confirmed/planned when drawn over the teal
    // hero card, where the normal dark fills don't read. Same in both modes
    // — the hero teal itself doesn't change, so neither do these. "available"
    // has no entry here — on the hero it's the leftover, drawn hollow (a
    // ring, see heroAvailable* below), not a fourth filled color.
    function heroStateColor(state) {
        switch (state) {
            case "used": return "#CFD8D6"
            case "confirmed": return "#8FE3C0"
            case "planned": return "#FFC4B0"
            default: return "#FFFFFF"
        }
    }
    readonly property color heroAvailableFill: Qt.rgba(1, 1, 1, 0.1)
    readonly property color heroAvailableRing: Qt.rgba(1, 1, 1, 0.62)
    readonly property color heroAvailableLegendRing: Qt.rgba(1, 1, 1, 0.82)

    // Familia B — holiday scopes. Five hues spread >=50° apart (crimson
    // 343°, blue 218°, violet 269°, yellow-ocre 46°, moss 85°) so no two
    // read as "basically the same color" next to each other in a list —
    // the earlier cool cluster (blue/violet/cyan/indigo) and, before that,
    // the warm cluster (red/orange/brown) both failed that test.
    function scopeColor(scope) {
        switch (scope) {
            case "nacional": return dark ? "#D62C56" : "#C81E4E"
            case "autonomico":
            case "regional": return dark ? "#2E6FDE" : "#1B5FD1"
            case "provincial": return dark ? "#9450DD" : "#7B34C9"
            case "local": return dark ? "#977500" : "#8A6A00"
            case "manual": return dark ? "#5F7E3A" : "#4F6B2E"
            default: return textSecondary
        }
    }
    function scopeInk(scope) {
        switch (scope) {
            case "nacional": return dark ? "#F58AA5" : "#A0193F"
            case "autonomico":
            case "regional": return dark ? "#8FB6F7" : "#174FAC"
            case "provincial": return dark ? "#C9A3F2" : "#672AA8"
            case "local": return dark ? "#D6B754" : "#745900"
            case "manual": return dark ? "#A8C47A" : "#435A26"
            default: return textSecondary
        }
    }

    // Translucent "soft" background matching scopeColor(), for the chip
    // variant used inline within a denser row (as opposed to the solid
    // insignia — see scopeColor() used directly for that). Light mode is a
    // flat 14% for all five; dark mode varies per scope (18-24%) since the
    // same alpha reads differently against #121A1B depending on the hue's
    // own luminance.
    function scopeChipBg(scope) {
        if (!dark) return withAlpha(scopeColor(scope), 0.14)
        switch (scope) {
            case "local": return withAlpha(scopeColor(scope), 0.22)
            case "manual": return withAlpha(scopeColor(scope), 0.24)
            default: return withAlpha(scopeColor(scope), 0.18)
        }
    }

    function withAlpha(hexColor, alphaFraction) {
        var c = Qt.color(hexColor)
        return Qt.rgba(c.r, c.g, c.b, alphaFraction)
    }

    // Month pill colors (used-day-by-month swatches): oklch(56% 0.16 H) in
    // light, oklch(68% 0.14 H) in dark — same hue turn, more lightness and a
    // touch less chroma. H = (158 + i*30) % 360. Isoluminant, so the text on
    // top is white in light mode and #12181A in dark. QML has no native
    // OKLCH, so these are precomputed sRGB values.
    readonly property var monthPillColorsLight: [
        "#008F4E", "#009086", "#0087B2", "#0078CC", "#6166D0", "#8F55BB",
        "#AD4895", "#BE4262", "#BF4922", "#AF5C00", "#8E7200", "#598400"
    ]
    readonly property var monthPillColorsDark: [
        "#35B276", "#00B3A8", "#00ABD1", "#479EEA", "#858EED", "#B07FDA",
        "#CF74B6", "#DF7088", "#E07655", "#D0851F", "#B09803", "#7FA841"
    ]
    readonly property var monthPillColors: dark ? monthPillColorsDark : monthPillColorsLight
    readonly property color monthPillOn: dark ? "#12181A" : "#FFFFFF"
}
