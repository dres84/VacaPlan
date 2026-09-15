pragma Singleton
import QtQuick

QtObject {
    readonly property FontLoader dmSansLoader: FontLoader { source: "qrc:/fonts/DM_Sans.ttf" }
    readonly property string fontFamily: dmSansLoader.name.length > 0 ? dmSansLoader.name : "DM Sans"

    // "Beach" palette — warm and light
    readonly property color background: "#FBF7F0"
    readonly property color surface: "#FFFFFF"
    readonly property color soft: "#F1EBDD"
    readonly property color text: "#1F2A2E"
    readonly property color textSecondary: "#6B7A80"
    readonly property color divider: "#E4DED2"
    readonly property color textDisabled: "#A9B4B8"

    readonly property color primary: "#0E7C7B"
    readonly property color primaryPressed: "#0B5E5D"
    readonly property color primaryDisabled: "#A9CFCE"

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
            case "nacional": return "Nacional"
            case "autonomico":
            case "regional": return "Autonómico"
            case "provincial": return "Provincial"
            case "local": return "Local"
            case "manual": return "Manual"
            default: return scope
        }
    }

    function scopeColor(scope) {
        switch (scope) {
            case "nacional": return "#0E7C7B"
            case "autonomico":
            case "regional": return "#FF6B4A"
            case "provincial": return "#3C6E70"
            case "local": return "#B8860B"
            case "manual": return "#9A7B4F"
            default: return "#6B7A80"
        }
    }

    // Translucent background matching scopeColor(), for chips/badges.
    function scopeChipBg(scope) {
        var c = Qt.color(scopeColor(scope))
        return Qt.rgba(c.r, c.g, c.b, 0.12)
    }
}
