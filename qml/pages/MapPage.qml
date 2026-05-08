import QtQuick
import QtQuick.Layouts
import OpenShark

Item {
    id: root

    // ── Toolbar ───────────────────────────────────────────────────────────────
    Rectangle {
        id: toolbar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44
        color:  Theme.bgOverlay
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.borderSubtle
        }

        Row {
            anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            spacing: Theme.spacingSM

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  "%1 hosts  ·  %2 flows".arg(appController.networkMap.nodeCount)
                                               .arg(appController.networkMap.edges.length)
                color: Theme.textSecond
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            spacing: Theme.spacingSM

            Rectangle {
                width: 70; height: 28; radius: 14
                color:  resetMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "Reset"; color: Theme.textSecond; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS } }
                MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true; onClicked: mapCanvas.resetLayout() }
            }
        }
    }

    // ── Map canvas ────────────────────────────────────────────────────────────
    Item {
        id: mapArea
        anchors { top: toolbar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        Canvas {
            id: mapCanvas
            anchors.fill: parent

            property var nodes: []
            property var edges: []
            property real scale: 1.0
            property real offsetX: 0
            property real offsetY: 0

            // Force simulation parameters
            property real repulsion:  4000
            property real attraction: 0.04
            property real damping:    0.85
            property real minDist:    60

            function resetLayout() {
                // Scatter nodes randomly then let simulation settle
                for (var i = 0; i < nodes.length; i++) {
                    nodes[i].vx = (Math.random() - 0.5) * 40
                    nodes[i].vy = (Math.random() - 0.5) * 40
                }
                simTimer.restart()
            }

            function syncFromModel() {
                var mn = appController.networkMap.nodes
                var me = appController.networkMap.edges
                // Merge new nodes — preserve positions of existing ones
                var existing = {}
                for (var i = 0; i < nodes.length; i++) existing[nodes[i].ip] = nodes[i]

                var next = []
                for (var j = 0; j < mn.length; j++) {
                    var mn_j = mn[j]
                    if (existing[mn_j.ip]) {
                        var ex = existing[mn_j.ip]
                        ex.packets = mn_j.packetCount
                        ex.bytes   = mn_j.bytesTotal
                        next.push(ex)
                    } else {
                        next.push({
                            ip: mn_j.ip, label: mn_j.label,
                            x: width  * (0.15 + Math.random() * 0.7),
                            y: height * (0.15 + Math.random() * 0.7),
                            vx: 0, vy: 0,
                            packets: mn_j.packetCount,
                            bytes:   mn_j.bytesTotal,
                            pinned:  mn_j.pinned
                        })
                    }
                }
                nodes = next
                edges = me
                requestPaint()
            }

            function stepSimulation() {
                if (nodes.length === 0) return
                var dt = 0.5

                // Repulsion between all pairs
                for (var i = 0; i < nodes.length; i++) {
                    for (var j = i + 1; j < nodes.length; j++) {
                        var dx = nodes[j].x - nodes[i].x
                        var dy = nodes[j].y - nodes[i].y
                        var d2 = dx*dx + dy*dy
                        if (d2 < 1) d2 = 1
                        var d  = Math.sqrt(d2)
                        var f  = repulsion / d2
                        var fx = f * dx / d, fy = f * dy / d
                        nodes[i].vx -= fx * dt; nodes[i].vy -= fy * dt
                        nodes[j].vx += fx * dt; nodes[j].vy += fy * dt
                    }
                }

                // Attraction along edges
                var nodeIdx = {}
                for (var k = 0; k < nodes.length; k++) nodeIdx[nodes[k].ip] = k
                for (var e = 0; e < edges.length; e++) {
                    var si = nodeIdx[edges[e].src], di = nodeIdx[edges[e].dst]
                    if (si === undefined || di === undefined) continue
                    var ex = nodes[di].x - nodes[si].x
                    var ey = nodes[di].y - nodes[si].y
                    var ed = Math.sqrt(ex*ex + ey*ey) || 1
                    var ef = attraction * (ed - minDist)
                    nodes[si].vx += ef * ex / ed * dt; nodes[si].vy += ef * ey / ed * dt
                    nodes[di].vx -= ef * ex / ed * dt; nodes[di].vy -= ef * ey / ed * dt
                }

                // Center gravity
                var cx = width / 2, cy = height / 2
                for (var n = 0; n < nodes.length; n++) {
                    if (nodes[n].pinned) { nodes[n].vx = 0; nodes[n].vy = 0; continue }
                    nodes[n].vx += (cx - nodes[n].x) * 0.002 * dt
                    nodes[n].vy += (cy - nodes[n].y) * 0.002 * dt
                    nodes[n].vx *= damping; nodes[n].vy *= damping
                    nodes[n].x  += nodes[n].vx; nodes[n].y += nodes[n].vy
                    // Clamp
                    nodes[n].x = Math.max(40, Math.min(width  - 40, nodes[n].x))
                    nodes[n].y = Math.max(40, Math.min(height - 40, nodes[n].y))
                }
                requestPaint()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (nodes.length === 0) {
                    ctx.fillStyle = Theme.textMuted
                    ctx.font = "14px Inter, sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText("Start a capture to see the network map", width/2, height/2)
                    ctx.textAlign = "start"
                    return
                }

                // Build index
                var idx = {}
                for (var k = 0; k < nodes.length; k++) idx[nodes[k].ip] = nodes[k]

                // ── Edges ─────────────────────────────────────────────────
                var maxBw = 1
                for (var e = 0; e < edges.length; e++) {
                    var bw = edges[e].bandwidth || 0
                    if (bw > maxBw) maxBw = bw
                }

                for (var ei = 0; ei < edges.length; ei++) {
                    var ed = edges[ei]
                    var sn = idx[ed.src], dn = idx[ed.dst]
                    if (!sn || !dn) continue
                    var t  = (ed.bandwidth || 0) / maxBw
                    var lw = 1 + t * 5
                    ctx.beginPath()
                    ctx.moveTo(sn.x, sn.y)
                    ctx.lineTo(dn.x, dn.y)
                    ctx.strokeStyle = Qt.rgba(0, 0.83, 1, 0.15 + t * 0.45)
                    ctx.lineWidth   = lw
                    ctx.stroke()
                }

                // ── Nodes ─────────────────────────────────────────────────
                var maxPkt = 1
                for (var n = 0; n < nodes.length; n++) {
                    if (nodes[n].packets > maxPkt) maxPkt = nodes[n].packets
                }

                for (var ni = 0; ni < nodes.length; ni++) {
                    var nd  = nodes[ni]
                    var r   = 10 + (nd.packets / maxPkt) * 20
                    var sel = (nd.ip === selectedIp)

                    // Glow
                    if (sel) {
                        ctx.beginPath()
                        ctx.arc(nd.x, nd.y, r + 8, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(0, 0.83, 1, 0.12)
                        ctx.fill()
                    }

                    // Circle
                    ctx.beginPath()
                    ctx.arc(nd.x, nd.y, r, 0, Math.PI * 2)
                    ctx.fillStyle = sel ? Theme.accentCyan : Qt.rgba(0.1, 0.1, 0.12, 0.95)
                    ctx.fill()
                    ctx.strokeStyle = sel ? Theme.accentCyan : Theme.borderActive
                    ctx.lineWidth = sel ? 2 : 1
                    ctx.stroke()

                    // Label
                    ctx.fillStyle = sel ? Theme.accentCyan : Theme.textPrimary
                    ctx.font = "10px Menlo, monospace"
                    ctx.textAlign = "center"
                    ctx.fillText(nd.label, nd.x, nd.y + r + 13)
                    ctx.textAlign = "start"
                }
            }

            // Sync model → canvas nodes
            Connections {
                target: appController.networkMap
                function onGraphChanged() { mapCanvas.syncFromModel() }
            }

            Component.onCompleted: syncFromModel()
        }

        // Force simulation timer — runs at ~30fps while animating
        Timer {
            id: simTimer
            interval: 33
            repeat: true
            running: appController.networkMap.nodeCount > 0
            onTriggered: mapCanvas.stepSimulation()
        }

        // Selected node label
        property string selectedIp: ""

        // Node tap detection
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                var best = "", bestD = 30
                for (var i = 0; i < mapCanvas.nodes.length; i++) {
                    var nd = mapCanvas.nodes[i]
                    var dx = nd.x - mouse.x, dy = nd.y - mouse.y
                    var d  = Math.sqrt(dx*dx + dy*dy)
                    if (d < bestD) { bestD = d; best = nd.ip }
                }
                mapArea.selectedIp = best
                mapCanvas.requestPaint()
                if (best !== "") appController.setDisplayFilter("ip.src == " + best)
                else             appController.setDisplayFilter("")
            }
        }

        // Node drag
        property string dragIp: ""
        property real dragOffX: 0
        property real dragOffY: 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onPressed: (mouse) => {
                for (var i = 0; i < mapCanvas.nodes.length; i++) {
                    var nd = mapCanvas.nodes[i]
                    var dx = nd.x - mouse.x, dy = nd.y - mouse.y
                    if (Math.sqrt(dx*dx+dy*dy) < 30) {
                        mapArea.dragIp = nd.ip
                        mapArea.dragOffX = dx; mapArea.dragOffY = dy
                        break
                    }
                }
            }
            onPositionChanged: (mouse) => {
                if (mapArea.dragIp === "") return
                for (var i = 0; i < mapCanvas.nodes.length; i++) {
                    if (mapCanvas.nodes[i].ip === mapArea.dragIp) {
                        mapCanvas.nodes[i].x = mouse.x + mapArea.dragOffX
                        mapCanvas.nodes[i].y = mouse.y + mapArea.dragOffY
                        mapCanvas.nodes[i].pinned = true
                        mapCanvas.requestPaint()
                        break
                    }
                }
            }
            onReleased: mapArea.dragIp = ""
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            visible: appController.networkMap.nodeCount === 0
            text:    "Start a capture to see the network map"
            color:   Theme.textMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMD }
        }
    }
}
