import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

Item {
    id: root

    readonly property var protoColors: ({
        "TCP":"#2979ff","UDP":"#00bcd4","TLS":"#7c4dff",
        "DNS":"#ff9100","HTTP":"#00c853","ICMP":"#e31937",
        "ICMPv6":"#f44336","ARP":"#ff6d00","???":"#616161"
    })

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        Column {
            width:   parent.width
            spacing: Theme.spacingLG
            padding: Theme.spacingLG

            // ── 4 stat tiles ──────────────────────────────────────────────
            RowLayout {
                width:   parent.width - Theme.spacingLG * 2
                spacing: Theme.spacingSM

                StatBigNumber {
                    Layout.fillWidth: true
                    label: "Packets"
                    value: appController.stats.totalPackets.toLocaleString()
                }
                StatBigNumber {
                    Layout.fillWidth: true
                    label: "Bytes"
                    value: formatBytes(appController.stats.totalBytes)
                }
                StatBigNumber {
                    Layout.fillWidth: true
                    label: "Packets / sec"
                    value: {
                        var s = appController.stats.throughputSamples
                        return s.length > 0 ? s[s.length - 1].packets.toLocaleString() : "0"
                    }
                }
                StatBigNumber {
                    Layout.fillWidth: true
                    label: "Protocols"
                    value: appController.stats.protocolCounts.length.toString()
                }
            }

            // ── Throughput chart ──────────────────────────────────────────
            Rectangle {
                width:  parent.width - Theme.spacingLG * 2
                height: 190
                radius: Theme.radius
                color:  Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1

                // Title + peak value
                RowLayout {
                    anchors { top: parent.top; left: parent.left; right: parent.right
                              topMargin: Theme.spacingMD; leftMargin: Theme.spacingMD; rightMargin: Theme.spacingMD }
                    spacing: 8
                    Text {
                        text:  "Throughput"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }
                    Text {
                        text:  "bytes / sec"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.Light }
                        opacity: 0.6
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: {
                            var s = appController.stats.throughputSamples
                            if (s.length === 0) return ""
                            var max = 0
                            for (var i = 0; i < s.length; i++) if (s[i].bytes > max) max = s[i].bytes
                            return "peak  " + formatBytes(max) + "/s"
                        }
                        color: Theme.accentCyan
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                        opacity: 0.8
                    }
                }

                Canvas {
                    id: throughputChart
                    anchors { fill: parent; margins: 1; topMargin: 34; bottomMargin: 10
                              leftMargin: 44; rightMargin: 8 }

                    Connections {
                        target: appController.stats
                        function onStatsChanged() { if (root.visible) throughputChart.requestPaint() }
                    }

                    onPaint: {
                        var ctx     = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var samples = appController.stats.throughputSamples
                        if (samples.length < 2) return

                        var maxVal = 1
                        for (var i = 0; i < samples.length; i++)
                            if (samples[i].bytes > maxVal) maxVal = samples[i].bytes

                        var n   = samples.length
                        var pad = 6

                        // Horizontal grid lines + Y labels
                        ctx.font      = "9px Inter, sans-serif"
                        ctx.textAlign = "right"
                        for (var g = 0; g <= 3; g++) {
                            var gy    = pad + (height - pad * 2) * (1 - g / 3)
                            var label = g === 0 ? "0" : formatBytes(maxVal * g / 3)
                            ctx.strokeStyle = Theme.borderSubtle
                            ctx.lineWidth   = 1
                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                            ctx.fillStyle   = Theme.textMuted
                            ctx.fillText(label, -4, gy + 3)
                        }
                        ctx.textAlign = "start"

                        // Fill
                        ctx.beginPath()
                        for (var j = 0; j < n; j++) {
                            var x = j / (n - 1) * width
                            var y = pad + (1 - samples[j].bytes / maxVal) * (height - pad * 2)
                            j === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                        }
                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                        var grad = ctx.createLinearGradient(0, 0, 0, height)
                        grad.addColorStop(0, Qt.rgba(0, 0.83, 1, 0.40))
                        grad.addColorStop(1, Qt.rgba(0, 0.83, 1, 0.02))
                        ctx.fillStyle = grad; ctx.fill()

                        // Line
                        ctx.beginPath()
                        for (var k = 0; k < n; k++) {
                            var lx = k / (n - 1) * width
                            var ly = pad + (1 - samples[k].bytes / maxVal) * (height - pad * 2)
                            k === 0 ? ctx.moveTo(lx, ly) : ctx.lineTo(lx, ly)
                        }
                        ctx.strokeStyle = Theme.accentCyan; ctx.lineWidth = 1.5; ctx.stroke()
                    }
                }
            }

            // ── Protocol breakdown + Top Talkers ──────────────────────────
            RowLayout {
                width:   parent.width - Theme.spacingLG * 2
                spacing: Theme.spacingSM

                // Protocol donut
                Rectangle {
                    Layout.fillWidth: true
                    height: 292
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1

                    Text {
                        id: protoTitle
                        anchors { top: parent.top; left: parent.left
                                  topMargin: Theme.spacingMD; leftMargin: Theme.spacingMD }
                        text:  "Protocol Breakdown"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }

                    // Separator
                    Rectangle {
                        anchors { top: protoTitle.bottom; left: parent.left; right: parent.right; topMargin: 8 }
                        height: 1; color: Theme.borderSubtle
                    }

                    Canvas {
                        id: donutChart
                        anchors { top: protoTitle.bottom; left: parent.left; bottom: parent.bottom
                                  topMargin: 9 }
                        width: parent.width * 0.50

                        Connections {
                            target: appController.stats
                            function onStatsChanged() { if (root.visible) donutChart.requestPaint() }
                        }

                        onPaint: {
                            var ctx   = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var data  = appController.stats.protocolCounts
                            if (data.length === 0) return

                            var total = 0
                            for (var i = 0; i < data.length; i++) total += data[i].count
                            if (total === 0) return

                            var cx = width  / 2
                            var cy = height / 2
                            var R  = Math.min(cx, cy) - 14
                            var r  = R * 0.56
                            if (R <= 4) return

                            var angle = -Math.PI / 2
                            var count = Math.min(data.length, 7)
                            for (var j = 0; j < count; j++) {
                                var sweep = data[j].count / total * Math.PI * 2
                                ctx.beginPath()
                                ctx.moveTo(cx, cy)
                                ctx.arc(cx, cy, R, angle, angle + sweep)
                                ctx.closePath()
                                ctx.fillStyle = root.protoColors[data[j].protocol] || "#616161"
                                ctx.fill()
                                // Gap between segments
                                ctx.strokeStyle = Theme.bgCard
                                ctx.lineWidth   = 2
                                ctx.stroke()
                                angle += sweep
                            }

                            // Donut hole
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.fillStyle = Theme.bgCard; ctx.fill()

                            // Center label
                            ctx.fillStyle = Theme.textPrimary
                            ctx.font      = "bold 13px Inter, sans-serif"
                            ctx.textAlign = "center"
                            ctx.fillText(total.toLocaleString(), cx, cy + 4)
                            ctx.fillStyle = Theme.textMuted
                            ctx.font      = "9px Inter, sans-serif"
                            ctx.fillText("packets", cx, cy + 16)
                            ctx.textAlign = "start"
                        }
                    }

                    // Legend
                    Column {
                        anchors {
                            top: protoTitle.bottom; topMargin: 16
                            left: donutChart.right
                            right: parent.right; rightMargin: Theme.spacingMD
                            bottom: parent.bottom; bottomMargin: Theme.spacingMD
                        }
                        spacing: 0

                        Repeater {
                            model: {
                                var d = appController.stats.protocolCounts
                                return d.length > 7 ? d.slice(0, 7) : d
                            }

                            Item {
                                width:  parent.width
                                height: 34

                                // Hover bg
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusXS
                                    color: "transparent"
                                }

                                Row {
                                    anchors { left: parent.left; right: parent.right
                                              verticalCenter: parent.verticalCenter
                                              leftMargin: 4 }
                                    spacing: 8

                                    Rectangle {
                                        width: 8; height: 8; radius: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.protoColors[modelData.protocol] || "#616161"
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text:  modelData.protocol
                                        color: Theme.textPrimary
                                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                        width: 52
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            var d = appController.stats.protocolCounts
                                            var t = 0
                                            for (var i = 0; i < d.length; i++) t += d[i].count
                                            return t > 0 ? Math.round(modelData.count / t * 100) + "%" : "0%"
                                        }
                                        color: Theme.textMuted
                                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                        width: 30
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text:  modelData.count.toLocaleString()
                                        color: Theme.textMuted
                                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                        opacity: 0.55
                                    }
                                }

                                // Row separator
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 1; color: Theme.borderSubtle; opacity: 0.5
                                }
                            }
                        }
                    }
                }

                // Top Talkers
                Rectangle {
                    id: talkersCard
                    Layout.fillWidth: true
                    height: 292
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1
                    clip: true

                    // Compute max once per stats update
                    readonly property real maxBytes: {
                        var t = appController.stats.topTalkers
                        return t.length > 0 ? t[0].bytes : 1
                    }

                    Text {
                        id: talkersTitle
                        anchors { top: parent.top; left: parent.left
                                  topMargin: Theme.spacingMD; leftMargin: Theme.spacingMD }
                        text:  "Top Talkers"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }

                    Rectangle {
                        anchors { top: talkersTitle.bottom; left: parent.left; right: parent.right; topMargin: 8 }
                        height: 1; color: Theme.borderSubtle
                    }

                    Column {
                        anchors { top: talkersTitle.bottom; left: parent.left; right: parent.right
                                  topMargin: 9; bottom: parent.bottom }
                        spacing: 0

                        Repeater {
                            model: {
                                var t = appController.stats.topTalkers
                                return t.length > 7 ? t.slice(0, 7) : t
                            }

                            Item {
                                width:  parent.width
                                height: 36

                                // Bar fill as row background
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: talkersCard.maxBytes > 0
                                           ? parent.width * (modelData.bytes / talkersCard.maxBytes)
                                           : 0
                                    color: Qt.rgba(0, 0.83, 1, 0.055)
                                    radius: 0
                                }

                                // Rank
                                Text {
                                    anchors { left: parent.left; leftMargin: Theme.spacingMD
                                              verticalCenter: parent.verticalCenter }
                                    text:  index + 1
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                    width: 16
                                }

                                // IP address
                                Text {
                                    anchors { left: parent.left; leftMargin: 38
                                              verticalCenter: parent.verticalCenter }
                                    text:  modelData.ip
                                    color: Theme.textPrimary
                                    font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeXS }
                                    width: parent.width * 0.45; elide: Text.ElideRight
                                }

                                // Bytes (right)
                                Text {
                                    anchors { right: parent.right; rightMargin: Theme.spacingMD
                                              verticalCenter: parent.verticalCenter }
                                    text:  formatBytes(modelData.bytes)
                                    color: Theme.textSecond
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Row separator
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                              leftMargin: Theme.spacingMD; rightMargin: Theme.spacingMD }
                                    height: 1; color: Theme.borderSubtle; opacity: 0.5
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function formatBytes(b) {
        if (b < 1024)       return b + " B"
        if (b < 1048576)    return (b / 1024).toFixed(1)    + " KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1073741824).toFixed(2) + " GB"
    }
}
