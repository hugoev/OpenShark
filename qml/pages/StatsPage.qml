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

            // ── 4 big-number tiles ────────────────────────────────────────
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
                height: 180
                radius: Theme.radius
                color:  Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1

                Text {
                    anchors { top: parent.top; left: parent.left; margins: Theme.spacingSM }
                    text:  "Throughput  (bytes / sec)"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                }

                Canvas {
                    id: throughputChart
                    anchors { fill: parent; margins: 1; topMargin: 28; bottomMargin: 10 }

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
                        for (var g = 1; g <= 3; g++) {
                            var gy = pad + (height - pad * 2) * (1 - g / 3)
                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                        }

                        // Fill gradient
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        for (var j = 0; j < n; j++) {
                            var x = j / (n - 1) * width
                            var y = pad + (1 - samples[j].bytes / maxVal) * (height - pad * 2)
                            j === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                        }
                        ctx.lineTo((n - 1) / (n - 1) * width, height)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        var grad = ctx.createLinearGradient(0, 0, 0, height)
                        grad.addColorStop(0, Qt.rgba(0, 0.83, 1, 0.45))
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

            // ── Protocol breakdown + Top Talkers ──────────────────────────
            RowLayout {
                width:   parent.width - Theme.spacingLG * 2
                spacing: Theme.spacingSM

                // Protocol donut + QML legend
                Rectangle {
                    Layout.fillWidth: true
                    height: 260
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1

                    Text {
                        id: protoTitle
                        anchors { top: parent.top; left: parent.left; margins: Theme.spacingSM }
                        text:  "Protocol Breakdown"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }

                    // Donut (left half)
                    Canvas {
                        id: donutChart
                        anchors { top: protoTitle.bottom; left: parent.left; bottom: parent.bottom; topMargin: 4 }
                        width: parent.width * 0.52

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

                            var cx    = width / 2
                            var cy    = height / 2
                            var R     = Math.min(cx, cy) - 12
                            var r     = R * 0.54
                            if (R <= 0) return

                            var angle = -Math.PI / 2
                            for (var j = 0; j < data.length && j < 8; j++) {
                                var sweep = (data[j].count / total) * Math.PI * 2
                                ctx.beginPath()
                                ctx.moveTo(cx, cy)
                                ctx.arc(cx, cy, R, angle, angle + sweep)
                                ctx.closePath()
                                ctx.fillStyle = root.protoColors[data[j].protocol] || "#616161"
                                ctx.fill()
                                angle += sweep
                            }

                            // Hole
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.fillStyle = Theme.bgCard; ctx.fill()

                            // Center text
                            ctx.fillStyle  = Theme.textPrimary
                            ctx.font       = "bold 13px Inter, sans-serif"
                            ctx.textAlign  = "center"
                            ctx.fillText(total.toLocaleString(), cx, cy + 5)
                            ctx.fillStyle  = Theme.textMuted
                            ctx.font       = "10px Inter, sans-serif"
                            ctx.fillText("packets", cx, cy + 18)
                            ctx.textAlign  = "start"
                        }
                    }

                    // Legend (right half, QML)
                    Column {
                        anchors {
                            top: protoTitle.bottom; topMargin: 8
                            left: donutChart.right; leftMargin: 4
                            right: parent.right; rightMargin: Theme.spacingSM
                            bottom: parent.bottom; bottomMargin: Theme.spacingSM
                        }
                        spacing: 5

                        Repeater {
                            model: {
                                var d = appController.stats.protocolCounts
                                return d.length > 8 ? d.slice(0, 8) : d
                            }

                            Row {
                                spacing: 7
                                width: parent.width

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
                                    width: 48
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        var total = 0
                                        var d = appController.stats.protocolCounts
                                        for (var i = 0; i < d.length; i++) total += d[i].count
                                        return total > 0
                                               ? Math.round(modelData.count / total * 100) + "%"
                                               : "0%"
                                    }
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                }
                            }
                        }
                    }
                }

                // Top Talkers with bars
                Rectangle {
                    Layout.fillWidth: true
                    height: 260
                    radius: Theme.radius
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle; border.width: 1

                    Column {
                        anchors { fill: parent; margins: Theme.spacingSM }
                        spacing: 0

                        Text {
                            text:  "Top Talkers"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                            bottomPadding: 8
                        }

                        Repeater {
                            model: appController.stats.topTalkers

                            Item {
                                width:  parent.width
                                height: 28

                                // Progress bar track
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
                                    height: 3; radius: 1
                                    color: Theme.borderSubtle
                                }
                                // Progress bar fill
                                Rectangle {
                                    anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 2 }
                                    height: 3; radius: 1
                                    width: {
                                        var talkers = appController.stats.topTalkers
                                        var max = talkers.length > 0 ? talkers[0].bytes : 1
                                        return max > 0 ? parent.width * (modelData.bytes / max) : 0
                                    }
                                    color: Qt.rgba(0, 0.83, 1, 0.55)
                                }

                                Text {
                                    anchors { left: parent.left; top: parent.top; topMargin: 2 }
                                    text:  modelData.ip
                                    color: Theme.textPrimary
                                    font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeXS }
                                    width: parent.width * 0.58; elide: Text.ElideRight
                                }
                                Text {
                                    anchors { right: parent.right; top: parent.top; topMargin: 2 }
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
        if (b < 1048576)    return (b / 1024).toFixed(1)    + " KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1073741824).toFixed(2) + " GB"
    }
}
