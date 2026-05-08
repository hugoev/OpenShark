import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

Item {
    id: root
    property int packetIndex: -1

    property var detail: packetIndex >= 0
                         ? appController.packets.packetDetail(packetIndex)
                         : null

    signal followStreamRequested(var streamData)

    property int hlOffset: -1
    property int hlLength: 0
    property var collapsedLayers: ({})

    onPacketIndexChanged: {
        hlOffset = -1
        hlLength = 0
        collapsedLayers = {}
    }

    function protocolAccentColor(proto) {
        switch (proto) {
        case "TCP":      return "#2979ff"
        case "UDP":      return "#00bcd4"
        case "TLS":      return "#7c4dff"
        case "DNS":      return "#ff9100"
        case "HTTP":     return "#00c853"
        case "ICMP":     return "#e31937"
        case "ICMPv6":   return "#f44336"
        case "ARP":      return "#ff6d00"
        case "IPv4":     return "#546e7a"
        case "IPv6":     return "#455a64"
        case "Ethernet": return "#37474f"
        default:         return "#616161"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgOverlay

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Theme.borderSubtle
        }

        SplitView {
            anchors { fill: parent; topMargin: Theme.spacingSM }
            orientation: Qt.Horizontal

            handle: Item {
                id: splitHandle
                implicitWidth: 7

                HoverHandler { cursorShape: Qt.SplitHCursor }

                Rectangle {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top; bottom: parent.bottom
                        topMargin: Theme.spacingSM; bottomMargin: Theme.spacingSM
                    }
                    width: 1
                    color: splitHandle.SplitHandle.pressed  ? Theme.accentCyan
                         : splitHandle.SplitHandle.hovered  ? Theme.borderActive
                         :                                    Theme.borderSubtle
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }

            // ── Layer / field tree (left pane) ─────────────────────────────
            ScrollView {
                SplitView.preferredWidth: parent.width * 0.50
                SplitView.minimumWidth:   160
                padding: Theme.spacingSM
                clip: true
                contentWidth: availableWidth

                Column {
                    width: parent.width
                    spacing: Theme.spacingSM

                    Repeater {
                        model: root.detail ? root.detail.layers : []

                        Rectangle {
                            id: layerCard
                            property bool isCollapsed: root.collapsedLayers[index] === true
                            width:  parent.width
                            height: isCollapsed
                                    ? layerHeader.height
                                    : layerHeader.height + fieldsCol.implicitHeight + 16
                            radius: Theme.radiusSM
                            color:  Theme.bgCard
                            border.color: Theme.borderSubtle
                            border.width: 1
                            clip: true

                            Behavior on height {
                                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                            }

                            // Protocol accent bar
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 3
                                color: root.protocolAccentColor(modelData.protocol)
                            }

                            // Layer header row
                            Item {
                                id: layerHeader
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                height: 34

                                Rectangle {
                                    anchors { fill: parent; leftMargin: 3 }
                                    radius: Theme.radiusSM
                                    color: headerMa.containsMouse ? Theme.bgCardHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text:  layerCard.isCollapsed ? "▶" : "▼"
                                    color: Theme.textMuted
                                    font.pixelSize: 8
                                }

                                Text {
                                    anchors { left: parent.left; leftMargin: 26; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text:  modelData.label
                                    color: Theme.textPrimary
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.DemiBold }
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: headerMa
                                    anchors { fill: parent; leftMargin: 3 }
                                    hoverEnabled: true
                                    onClicked: {
                                        var c = Object.assign({}, root.collapsedLayers)
                                        c[index] = !c[index]
                                        root.collapsedLayers = c
                                    }
                                }
                            }

                            // Divider under header
                            Rectangle {
                                anchors { left: parent.left; leftMargin: 3; right: parent.right; top: layerHeader.bottom }
                                height: 1
                                color: Theme.borderSubtle
                                opacity: layerCard.isCollapsed ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            }

                            // Field rows
                            Column {
                                id: fieldsCol
                                anchors {
                                    left: parent.left; leftMargin: 4
                                    right: parent.right; rightMargin: 4
                                    top: layerHeader.bottom; topMargin: 6
                                }
                                spacing: 1

                                Repeater {
                                    model: modelData.fields

                                    Rectangle {
                                        id: fieldRow
                                        width:  parent.width
                                        height: 22
                                        radius: Theme.radiusXS
                                        color: {
                                            if (root.hlOffset >= 0 &&
                                                modelData.absoluteOffset === root.hlOffset &&
                                                modelData.byteLength    === root.hlLength)
                                                return Qt.rgba(0, 0.83, 1, 0.12)
                                            return fieldMa.containsMouse ? Theme.bgCardHover : "transparent"
                                        }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Row {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                                            spacing: 8

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text:  modelData.name + ":"
                                                color: Theme.textMuted
                                                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                                width: 110; elide: Text.ElideRight
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text:  modelData.value
                                                color: (root.hlOffset >= 0 &&
                                                        modelData.absoluteOffset === root.hlOffset)
                                                       ? Theme.accentCyan : Theme.textPrimary
                                                font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeXS }
                                                elide: Text.ElideRight
                                                width: parent.width - 126
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                            }
                                        }

                                        MouseArea {
                                            id: fieldMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (root.hlOffset === modelData.absoluteOffset &&
                                                    root.hlLength === modelData.byteLength) {
                                                    root.hlOffset = -1
                                                    root.hlLength = 0
                                                } else {
                                                    root.hlOffset = modelData.absoluteOffset
                                                    root.hlLength = modelData.byteLength
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Hex view (right pane) ──────────────────────────────────────
            Item {
                SplitView.fillWidth:  true
                SplitView.minimumWidth: 200

                // Header strip
                Rectangle {
                    id: hexHeader
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Theme.spacingSM }
                    height: 24
                    color: Theme.bgCard

                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: root.detail
                              ? (root.hlOffset >= 0
                                 ? "Bytes %1–%2  (%3 bytes)".arg(root.hlOffset)
                                                             .arg(root.hlOffset + root.hlLength - 1)
                                                             .arg(root.hlLength)
                                 : "%1 bytes total".arg(root.detail.length))
                              : ""
                        color: root.hlOffset >= 0 ? Theme.accentCyan : Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Rectangle {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        height: 20; width: followLabel.implicitWidth + 16
                        radius: 10
                        visible: {
                            if (!root.detail || !root.detail.layers) return false
                            for (var i = 0; i < root.detail.layers.length; i++) {
                                var p = root.detail.layers[i].protocol
                                if (p === "TCP" || p === "HTTP" || p === "TLS") return true
                            }
                            return false
                        }
                        color:  followMa.containsMouse ? Qt.rgba(0, 0.83, 1, 0.18) : Qt.rgba(0, 0.83, 1, 0.08)
                        border.color: Theme.accentCyan; border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: followLabel
                            anchors.centerIn: parent
                            text: "Follow Stream"
                            color: Theme.accentCyan
                            font { family: Theme.fontFamily; pixelSize: 10 }
                        }
                        MouseArea {
                            id: followMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                var sd = appController.packets.followStream(root.packetIndex)
                                root.followStreamRequested(sd)
                            }
                        }
                    }
                }

                HexView {
                    anchors {
                        top: hexHeader.bottom; left: parent.left
                        right: parent.right;   bottom: parent.bottom
                        topMargin: Theme.spacingMD
                        leftMargin: Theme.spacingSM; rightMargin: Theme.spacingSM; bottomMargin: Theme.spacingSM
                    }
                    rawBytes:        root.detail ? root.detail.rawBytes : []
                    highlightOffset: root.hlOffset
                    highlightLength: root.hlLength
                }
            }
        }
    }
}
