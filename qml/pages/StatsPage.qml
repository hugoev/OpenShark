import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

Item {
    id: root

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        Column {
            width: parent.width
            spacing: Theme.spacingLG
            padding: Theme.spacingLG

            // ── Big numbers ───────────────────────────────────────────────
            RowLayout {
                width: parent.width - Theme.spacingLG * 2
                spacing: Theme.spacingSM

                StatBigNumber { Layout.fillWidth: true; label: "Packets";  value: appController.stats.totalPackets.toLocaleString() }
                StatBigNumber { Layout.fillWidth: true; label: "Bytes";    value: formatBytes(appController.stats.totalBytes) }
            }

            // ── Throughput chart ──────────────────────────────────────────
            Rectangle {
                width: parent.width - Theme.spacingLG * 2
                height: 180
                radius: Theme.radius
                color:  Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1

                Text {
                    anchors { top: parent.top; left: parent.left; margins: Theme.spacingSM }
                    text:  "Throughput (bytes/sec)"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                }

                Canvas {
                    id: throughputChart
                    anchors { fill: parent; margins: 1; topMargin: 24; bottomMargin: 8 }

                    Connections {
                        target: appController.stats
                        function onStatsChanged() { throughputChart.requestPaint() }
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
                        var pad = 8

                        // Grid lines
                        ctx.strokeStyle = Theme.borderSubtle
                        ctx.lineWidth   = 1
                        for (var g = 0; g < 4; g++) {
                            var gy = pad + (height - pad * 2) * g / 3
                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                        }

                        // Fill
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        for (var j = 0; j < n; j++) {
                            var x = j / (n - 1) * width
                            var y = pad + (1 - samples[j].bytes / maxVal) * (height - pad * 2)
                            if (j === 0) ctx.lineTo(x, y)
                            else         ctx.lineTo(x, y)
                        }
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        var grad = ctx.createLinearGradient(0, 0, 0, height)
                        grad.addColorStop(0, Qt.rgba(0, 0.83, 1, 0.5))
                        grad.addColorStop(1, Qt.rgba(0, 0.83, 1, 0.02))
                        ctx.fillStyle = grad
                        ctx.fill()

                        // Line
                        ctx.beginPath()
                        for (var k = 0; k < n; k++) {
                            var lx = k / (n - 1) * width
                            var ly = pad + (1 - samples[k].bytes / maxVal) * (height - pad * 2)
                            k === 0 ? ctx.moveTo(lx, ly) : ctx.lineTo(lx, ly)
                        }
                        ctx.strokeStyle = Theme.accentCyan
                        ctx.lineWidth   = 2
                        ctx.stroke()
                    }
                }
            }

            // ── Protocol breakdown + top talkers ──────────────────────────
            RowLayout {
                width: parent.width - Theme.spacingLG * 2
                spacing: Theme.spacingSM

                // Protocol donut
                Rectangle {
                    Layout.fillWidth: true
                    height: 240
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1

                    Text {
                        anchors { top: parent.top; left: parent.left; margins: Theme.spacingSM }
                        text: "Protocol Breakdown"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }

                    Canvas {
                        id: donutChart
                        anchors { fill: parent; margins: 1; topMargin: 24 }

                        readonly property var protoColors: ({
                            "TCP":"#2979ff","UDP":"#00bcd4","TLS":"#7c4dff",
                            "DNS":"#ff9100","HTTP":"#00c853","ICMP":"#e31937",
                            "ICMPv6":"#f44336","ARP":"#ff6d00","???":"#616161"
                        })

                        Connections {
                            target: appController.stats
                            function onStatsChanged() { donutChart.requestPaint() }
                        }

                        onPaint: {
                            var ctx   = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var data  = appController.stats.protocolCounts
                            if (data.length === 0) return

                            var total = 0
                            for (var i = 0; i < data.length; i++) total += data[i].count
                            if (total === 0) return

                            var cx = width * 0.38, cy = height / 2
                            var R = Math.min(cx, cy) - 16, r = R * 0.55
                            if (R <= 0) return
                            var angle = -Math.PI / 2

                            for (var j = 0; j < data.length && j < 8; j++) {
                                var sweep = (data[j].count / total) * Math.PI * 2
                                var color = protoColors[data[j].protocol] || "#616161"
                                ctx.beginPath()
                                ctx.moveTo(cx, cy)
                                ctx.arc(cx, cy, R, angle, angle + sweep)
                                ctx.closePath()
                                ctx.fillStyle = color
                                ctx.fill()
                                angle += sweep
                            }

                            // Donut hole
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI*2)
                            ctx.fillStyle = Theme.bgCard; ctx.fill()

                            // Center label
                            ctx.fillStyle = Theme.textPrimary
                            ctx.font = "bold 14px Inter, sans-serif"
                            ctx.textAlign = "center"
                            ctx.fillText(total.toLocaleString(), cx, cy + 5)
                            ctx.fillStyle = Theme.textMuted
                            ctx.font = "10px Inter, sans-serif"
                            ctx.fillText("packets", cx, cy + 18)
                            ctx.textAlign = "start"

                            // Legend
                            var legX = width * 0.64, legY = 16, legH = 18
                            for (var l = 0; l < data.length && l < 8; l++) {
                                var c2 = protoColors[data[l].protocol] || "#616161"
                                ctx.fillStyle = c2
                                ctx.fillRect(legX, legY + l*legH, 10, 10)
                                ctx.fillStyle = Theme.textSecond
                                ctx.font = "10px Inter, sans-serif"
                                ctx.fillText(data[l].protocol + " " +
                                    Math.round(data[l].count/total*100) + "%",
                                    legX + 14, legY + l*legH + 9)
                            }
                        }
                    }
                }

                // Top talkers
                Rectangle {
                    Layout.fillWidth: true
                    height: 240
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1

                    Column {
                        anchors { fill: parent; margins: Theme.spacingSM }
                        spacing: 4

                        Text {
                            text: "Top Talkers"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                            bottomPadding: 4
                        }

                        Repeater {
                            model: appController.stats.topTalkers

                            Item {
                                width: parent.width
                                height: 20

                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text:  modelData.ip
                                    color: Theme.textPrimary
                                    font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeXS }
                                    width: parent.width * 0.6; elide: Text.ElideRight
                                }

                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text:  formatBytes(modelData.bytes)
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
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
        if (b < 1048576)    return (b/1024).toFixed(1)   + " KB"
        if (b < 1073741824) return (b/1048576).toFixed(1) + " MB"
        return (b/1073741824).toFixed(2) + " GB"
    }
}
