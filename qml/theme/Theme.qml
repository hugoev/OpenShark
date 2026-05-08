pragma Singleton
import QtQuick

QtObject {
    // Palette
    readonly property color bgBase:       "#0d0d0f"
    readonly property color bgCard:       "#1a1a1d"
    readonly property color bgCardHover:  "#222226"
    readonly property color bgOverlay:    "#141416"

    readonly property color textPrimary:  "#e8e8ea"
    readonly property color textSecond:   "#8888a0"
    readonly property color textMuted:    "#55556a"

    readonly property color accentRed:    "#e31937"
    readonly property color accentCyan:   "#00d4ff"
    readonly property color accentPurple: "#7c4dff"

    readonly property color borderSubtle: "#28282e"
    readonly property color borderActive: "#3a3a46"

    // Typography
    readonly property string fontFamily:  "Inter"
    readonly property int    fontSizeXS:  11
    readonly property int    fontSizeSM:  13
    readonly property int    fontSizeMD:  15
    readonly property int    fontSizeLG:  18
    readonly property int    fontSizeXL:  24
    readonly property int    fontSizeXXL: 32

    // Geometry
    readonly property real radius:       16
    readonly property real radiusSM:      8
    readonly property real radiusXS:      4
    readonly property real navBarHeight: 72
    readonly property real statusHeight: 44
    readonly property real spacing:      16
    readonly property real spacingSM:     8
    readonly property real spacingMD:    12
    readonly property real spacingLG:    24

    // Animation
    readonly property int   animFast:   150
    readonly property int   animNormal: 250
    readonly property int   animSlow:   400
    readonly property int   easingType: Easing.OutCubic
}
