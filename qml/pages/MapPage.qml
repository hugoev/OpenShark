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
            height: 1; color: Theme.borderSubtle
        }

        Row {
            anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            spacing: Theme.spacingSM
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  "%1 hosts  ·  %2 flows"
                       .arg(appController.networkMap.nodeCount)
                       .arg(appController.networkMap.edges.length)
                color: Theme.textSecond
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            spacing: Theme.spacingSM

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  "scroll to zoom  ·  drag to pan"
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                visible: appController.networkMap.nodeCount > 0
            }

            Rectangle {
                width: 70; height: 28; radius: 14
                color:  resetMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "Reset"; color: Theme.textSecond
                       font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS } }
                MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: mapCanvas.resetLayout() }
            }
        }
    }

    // ── Map area ──────────────────────────────────────────────────────────────
    Item {
        id: mapArea
        anchors { top: toolbar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true

        property string selectedIp:  ""
        property string hoveredIp:   ""
        property var    hoveredNode: null

        // Drag state
        property string dragIp:    ""
        property real   dragOffX:  0
        property real   dragOffY:  0

        // Pan state
        property bool   panning:   false
        property real   panStartX: 0
        property real   panStartY: 0
        property real   panOffX0:  0
        property real   panOffY0:  0

        Canvas {
            id: mapCanvas
            anchors.fill: parent

            property var  nodes:     []
            property var  edges:     []
            property real scale:     1.0
            property real offsetX:   0
            property real offsetY:   0

            property real repulsion:  4000
            property real attraction: 0.04
            property real damping:    0.85
            property real minDist:    60

            function maxPackets() {
                var m = 1
                for (var i = 0; i < nodes.length; i++)
                    if (nodes[i].packets > m) m = nodes[i].packets
                return m
            }

            function nodeAt(wx, wy) {
                var mp = maxPackets()
                for (var i = 0; i < nodes.length; i++) {
                    var nd = nodes[i]
                    var r  = 10 + (nd.packets / mp) * 20 + 6
                    var dx = nd.x - wx, dy = nd.y - wy
                    if (dx*dx + dy*dy < r*r) return nd
                }
                return null
            }

            function toWorld(sx, sy) {
                return { x: (sx - offsetX) / scale, y: (sy - offsetY) / scale }
            }

            function resetLayout() {
                offsetX = 0; offsetY = 0; scale = 1.0
                for (var i = 0; i < nodes.length; i++) {
                    nodes[i].x  = width  * (0.15 + Math.random() * 0.7)
                    nodes[i].y  = height * (0.15 + Math.random() * 0.7)
                    nodes[i].vx = (Math.random() - 0.5) * 40
                    nodes[i].vy = (Math.random() - 0.5) * 40
                    nodes[i].pinned = false
                }
                mapArea.selectedIp = ""
                requestPaint()
                simTimer.restart()
            }

            function syncFromModel() {
                var mn = appController.networkMap.nodes
                var me = appController.networkMap.edges
                var existing = {}
                for (var i = 0; i < nodes.length; i++) existing[nodes[i].ip] = nodes[i]

                var next = []
                for (var j = 0; j < mn.length; j++) {
                    var mj = mn[j]
                    if (existing[mj.ip]) {
                        var ex = existing[mj.ip]
                        ex.packets = mj.packetCount
                        ex.bytes   = mj.bytesTotal
                        next.push(ex)
                    } else {
                        next.push({
                            ip: mj.ip, label: mj.label,
                            x: width  * (0.15 + Math.random() * 0.7),
                            y: height * (0.15 + Math.random() * 0.7),
                            vx: 0, vy: 0,
                            packets: mj.packetCount,
                            bytes:   mj.bytesTotal,
                            pinned:  mj.pinned
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

                for (var i = 0; i < nodes.length; i++) {
                    for (var j = i + 1; j < nodes.length; j++) {
                        var dx = nodes[j].x - nodes[i].x
                        var dy = nodes[j].y - nodes[i].y
                        var d2 = Math.max(1, dx*dx + dy*dy)
                        var d  = Math.sqrt(d2)
                        var f  = repulsion / d2
                        nodes[i].vx -= f * dx/d * dt;  nodes[i].vy -= f * dy/d * dt
                        nodes[j].vx += f * dx/d * dt;  nodes[j].vy += f * dy/d * dt
                    }
                }

                var nodeIdx = {}
                for (var k = 0; k < nodes.length; k++) nodeIdx[nodes[k].ip] = k
                for (var e = 0; e < edges.length; e++) {
                    var si = nodeIdx[edges[e].src], di = nodeIdx[edges[e].dst]
                    if (si === undefined || di === undefined) continue
                    var ex = nodes[di].x - nodes[si].x
                    var ey = nodes[di].y - nodes[si].y
                    var ed = Math.max(1, Math.sqrt(ex*ex + ey*ey))
                    var ef = attraction * (ed - minDist)
                    nodes[si].vx += ef*ex/ed*dt;  nodes[si].vy += ef*ey/ed*dt
                    nodes[di].vx -= ef*ex/ed*dt;  nodes[di].vy -= ef*ey/ed*dt
                }

                var cx = width / 2, cy = height / 2
                for (var n = 0; n < nodes.length; n++) {
                    if (nodes[n].pinned) { nodes[n].vx = 0; nodes[n].vy = 0; continue }
                    nodes[n].vx += (cx - nodes[n].x) * 0.002 * dt
                    nodes[n].vy += (cy - nodes[n].y) * 0.002 * dt
                    nodes[n].vx *= damping;  nodes[n].vy *= damping
                    nodes[n].x  += nodes[n].vx
                    nodes[n].y  += nodes[n].vy
                    nodes[n].x = Math.max(30, Math.min(width  - 30, nodes[n].x))
                    nodes[n].y = Math.max(30, Math.min(height - 30, nodes[n].y))
                }
                requestPaint()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (nodes.length === 0) return

                ctx.save()
                ctx.translate(offsetX, offsetY)
                ctx.scale(scale, scale)

                var idx = {}
                for (var k = 0; k < nodes.length; k++) idx[nodes[k].ip] = nodes[k]

                // Edges
                var maxBw = 1
                for (var e = 0; e < edges.length; e++)
                    if ((edges[e].bandwidth || 0) > maxBw) maxBw = edges[e].bandwidth
                for (var ei = 0; ei < edges.length; ei++) {
                    var ed = edges[ei]
                    var sn = idx[ed.src], dn = idx[ed.dst]
                    if (!sn || !dn) continue
                    var t = (ed.bandwidth || 0) / maxBw
                    ctx.beginPath()
                    ctx.moveTo(sn.x, sn.y); ctx.lineTo(dn.x, dn.y)
                    ctx.strokeStyle = Qt.rgba(0, 0.83, 1, 0.12 + t * 0.45)
                    ctx.lineWidth   = (1 + t * 3) / scale
                    ctx.stroke()
                }

                // Nodes
                var mp = maxPackets()
                for (var ni = 0; ni < nodes.length; ni++) {
                    var nd  = nodes[ni]
                    var r   = 10 + (nd.packets / mp) * 20
                    var sel = (nd.ip === mapArea.selectedIp)
                    var hov = (nd.ip === mapArea.hoveredIp)

                    if (sel || hov) {
                        ctx.beginPath()
                        ctx.arc(nd.x, nd.y, r + 9, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(0, 0.83, 1, sel ? 0.14 : 0.07)
                        ctx.fill()
                    }

                    ctx.beginPath()
                    ctx.arc(nd.x, nd.y, r, 0, Math.PI * 2)
                    ctx.fillStyle = sel ? Qt.rgba(0, 0.83, 1, 0.85)
                                   : hov ? Qt.rgba(0.08, 0.3, 0.38, 0.95)
                                   : Qt.rgba(0.1, 0.1, 0.13, 0.95)
                    ctx.fill()
                    ctx.strokeStyle = sel ? Theme.accentCyan
                                    : hov ? Qt.rgba(0, 0.83, 1, 0.55)
                                    : Theme.borderActive
                    ctx.lineWidth   = (sel ? 2 : 1) / scale
                    ctx.stroke()

                    var fontSize = Math.max(7, 10 / scale)
                    ctx.font      = fontSize + "px Menlo, monospace"
                    ctx.fillStyle = sel ? Theme.accentCyan : Theme.textPrimary
                    ctx.textAlign = "center"
                    ctx.fillText(nd.label, nd.x, nd.y + r + fontSize + 2)
                    ctx.textAlign = "start"
                }

                ctx.restore()
            }

            Connections {
                target: appController.networkMap
                function onGraphChanged() { mapCanvas.syncFromModel() }
            }
            Component.onCompleted: syncFromModel()
        }

        // Force simulation
        Timer {
            id: simTimer
            interval: 33; repeat: true
            running:  appController.networkMap.nodeCount > 0
            onTriggered: mapCanvas.stepSimulation()
        }

        // Hover tooltip
        Rectangle {
            id: nodeTooltip
            visible:  mapArea.hoveredNode !== null
            x: Math.min(tooltipX + 14, mapArea.width  - width  - 6)
            y: Math.max(6, Math.min(tooltipY - height / 2, mapArea.height - height - 6))
            width:  tipCol.implicitWidth + 24
            height: tipCol.implicitHeight + 16
            radius: Theme.radiusSM
            color:  Theme.bgCard
            border.color: Theme.borderActive; border.width: 1
            z: 10

            property real tooltipX: 0
            property real tooltipY: 0

            Column {
                id: tipCol
                anchors { left: parent.left; top: parent.top; margins: 12 }
                spacing: 4

                Text {
                    text:  mapArea.hoveredNode ? mapArea.hoveredNode.ip : ""
                    color: Theme.accentCyan
                    font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeSM; weight: Font.DemiBold }
                }
                Text {
                    text:  mapArea.hoveredNode
                           ? (mapArea.hoveredNode.packets.toLocaleString() + " packets")
                           : ""
                    color: Theme.textSecond
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                }
                Text {
                    text:  mapArea.hoveredNode ? root.formatBytes(mapArea.hoveredNode.bytes) : ""
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                }
            }
        }

        // Unified mouse handler
        MouseArea {
            id: mapMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            property bool didDrag:  false
            property real pressX:   0
            property real pressY:   0

            onPressed: (mouse) => {
                pressX = mouse.x; pressY = mouse.y; didDrag = false
                var w  = mapCanvas.toWorld(mouse.x, mouse.y)
                var nd = mapCanvas.nodeAt(w.x, w.y)
                if (nd) {
                    mapArea.dragIp   = nd.ip
                    mapArea.dragOffX = nd.x - w.x
                    mapArea.dragOffY = nd.y - w.y
                } else {
                    mapArea.panning   = true
                    mapArea.panStartX = mouse.x; mapArea.panStartY = mouse.y
                    mapArea.panOffX0  = mapCanvas.offsetX
                    mapArea.panOffY0  = mapCanvas.offsetY
                }
            }

            onPositionChanged: (mouse) => {
                if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 4)
                    didDrag = true

                if (mapArea.dragIp !== "") {
                    var w = mapCanvas.toWorld(mouse.x, mouse.y)
                    for (var i = 0; i < mapCanvas.nodes.length; i++) {
                        if (mapCanvas.nodes[i].ip === mapArea.dragIp) {
                            mapCanvas.nodes[i].x = w.x + mapArea.dragOffX
                            mapCanvas.nodes[i].y = w.y + mapArea.dragOffY
                            mapCanvas.nodes[i].pinned = true
                            break
                        }
                    }
                } else if (mapArea.panning) {
                    mapCanvas.offsetX = mapArea.panOffX0 + (mouse.x - mapArea.panStartX)
                    mapCanvas.offsetY = mapArea.panOffY0 + (mouse.y - mapArea.panStartY)
                }

                // Hover
                var hw = mapCanvas.toWorld(mouse.x, mouse.y)
                var hn = mapCanvas.nodeAt(hw.x, hw.y)
                mapArea.hoveredIp   = hn ? hn.ip   : ""
                mapArea.hoveredNode = hn ? hn : null
                nodeTooltip.tooltipX = mouse.x
                nodeTooltip.tooltipY = mouse.y
                mapCanvas.requestPaint()
            }

            onReleased: (mouse) => {
                if (!didDrag) {
                    var w  = mapCanvas.toWorld(mouse.x, mouse.y)
                    var nd = mapCanvas.nodeAt(w.x, w.y)
                    var ip = nd ? nd.ip : ""
                    mapArea.selectedIp = (mapArea.selectedIp === ip && ip !== "") ? "" : ip
                    appController.setDisplayFilter(ip !== "" ? "ip.src == " + ip : "")
                    mapCanvas.requestPaint()
                }
                mapArea.dragIp  = ""
                mapArea.panning = false
            }

            onExited: {
                mapArea.hoveredIp   = ""
                mapArea.hoveredNode = null
                mapCanvas.requestPaint()
            }

            onWheel: (wheel) => {
                var factor = wheel.angleDelta.y > 0 ? 1.12 : (1 / 1.12)
                var wx = (wheel.x - mapCanvas.offsetX) / mapCanvas.scale
                var wy = (wheel.y - mapCanvas.offsetY) / mapCanvas.scale
                mapCanvas.scale   = Math.max(0.15, Math.min(6.0, mapCanvas.scale * factor))
                mapCanvas.offsetX = wheel.x - wx * mapCanvas.scale
                mapCanvas.offsetY = wheel.y - wy * mapCanvas.scale
                mapCanvas.requestPaint()
            }
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingSM
            visible: appController.networkMap.nodeCount === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "◎"; font.pixelSize: 40; color: Theme.textMuted
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  "Start a capture to see the network map"
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMD }
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
