import QtQuick
import QtQuick.Controls.Basic
import OpenShark

Flickable {
    id: root

    property var    rawBytes:        []
    property int    highlightOffset: -1
    property int    highlightLength: 0

    clip:             true
    contentWidth:     canvas.width
    contentHeight:    canvas.height
    boundsBehavior:   Flickable.StopAtBounds

    // Scroll the highlighted field into view
    onHighlightOffsetChanged: scrollToHighlight()

    function scrollToHighlight() {
        if (highlightOffset < 0 || rawBytes.length === 0) return
        var row = Math.floor(highlightOffset / 16)
        var y   = row * metrics.rowH
        if (y < contentY)
            contentY = Math.max(0, y - metrics.rowH)
        else if (y + metrics.rowH > contentY + height)
            contentY = y + metrics.rowH - height + metrics.rowH
    }

    // Layout metrics — computed once, referenced by canvas paint
    QtObject {
        id: metrics
        readonly property real charW:  7.2   // monospace glyph width at 11px
        readonly property real rowH:   18
        readonly property real addrW:  charW * 6    // "0000  "
        readonly property real hexW:   charW * 3 * 16  // "XX " × 16
        readonly property real gapW:   charW * 2
        readonly property real asciiX: addrW + hexW + gapW
        readonly property real totalW: asciiX + charW * 16 + 12
    }

    Canvas {
        id: canvas
        width:  metrics.totalW
        height: Math.ceil(root.rawBytes.length / 16) * metrics.rowH + 4

        // Repaint whenever data or highlight changes
        onAvailableChanged: requestPaint()

        Connections {
            target: root
            function onRawBytesChanged()        { canvas.requestPaint() }
            function onHighlightOffsetChanged() { canvas.requestPaint() }
            function onHighlightLengthChanged() { canvas.requestPaint() }
        }

        onPaint: {
            var ctx   = getContext("2d")
            var bytes = root.rawBytes
            if (!bytes || bytes.length === 0) { ctx.clearRect(0, 0, width, height); return }
            var n     = bytes.length

            ctx.clearRect(0, 0, width, height)
            ctx.font = "11px Menlo, Courier, monospace"

            var cW    = metrics.charW
            var rH    = metrics.rowH
            var aX    = metrics.addrW
            var ascX  = metrics.asciiX
            var hlOff = root.highlightOffset
            var hlLen = root.highlightLength

            var numRows = Math.ceil(n / 16)

            for (var row = 0; row < numRows; row++) {
                var rowStart = row * 16
                var y        = row * rH
                var baseline = y + rH * 0.72

                // ── Address ──────────────────────────────────────────────────
                ctx.fillStyle = Theme.textMuted
                var addrStr = ("0000" + rowStart.toString(16)).slice(-4)
                ctx.fillText(addrStr, 2, baseline)

                for (var col = 0; col < 16; col++) {
                    var byteIdx = rowStart + col
                    if (byteIdx >= n) break

                    var byteVal  = bytes[byteIdx]
                    var inHl     = hlLen > 0 && byteIdx >= hlOff && byteIdx < hlOff + hlLen
                    var hexX     = aX  + col * cW * 3
                    var aCharX   = ascX + col * cW

                    // ── Highlight backgrounds ─────────────────────────────
                    if (inHl) {
                        ctx.fillStyle = Qt.rgba(0, 0.83, 1, 0.18)
                        ctx.fillRect(hexX - 1, y + 1, cW * 2 + 2, rH - 2)
                        ctx.fillRect(aCharX - 1, y + 1, cW + 2, rH - 2)
                    }

                    // ── Hex bytes ─────────────────────────────────────────
                    var hexStr = ("0" + byteVal.toString(16)).slice(-2)
                    ctx.fillStyle = inHl ? Theme.accentCyan : Theme.textPrimary
                    ctx.fillText(hexStr, hexX, baseline)

                    // ── ASCII ─────────────────────────────────────────────
                    var ch = (byteVal >= 0x20 && byteVal < 0x7F)
                             ? String.fromCharCode(byteVal) : "."
                    ctx.fillStyle = inHl ? Theme.accentCyan
                                 : (byteVal >= 0x20 && byteVal < 0x7F)
                                   ? Theme.textSecond : Theme.textMuted
                    ctx.fillText(ch, aCharX, baseline)
                }
            }
        }
    }

    // Thin scrollbar
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { radius: 2; color: Theme.textMuted; opacity: 0.5 }
    }
}
