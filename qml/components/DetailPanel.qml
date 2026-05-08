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

    // Highlight state driven by field clicks
    property int hlOffset: -1
    property int hlLength: 0

    onPacketIndexChanged: { hlOffset = -1; hlLength = 0 }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgOverlay

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Theme.borderSubtle
        }

        RowLayout {
            anchors { fill: parent; topMargin: Theme.spacingSM }
            spacing: 0

            // ── Layer / field tree (left pane) ─────────────────────────────
            ScrollView {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.52
                padding: Theme.spacingSM
                clip: true
                contentWidth: availableWidth

                Column {
                    width: parent.width
                    spacing: Theme.spacingSM

                    Repeater {
                        model: root.detail ? root.detail.layers : []

                        Rectangle {
                            width:  parent.width
                            height: layerCol.implicitHeight + 20
                            radius: Theme.radiusSM
                            color:  Theme.bgCard
                            border.color: Theme.borderSubtle
                            border.width: 1

                            Column {
                                id: layerCol
                                anchors { fill: parent; margins: 10 }
                                spacing: 2

                                // Layer header
                                Text {
                                    text:  modelData.label
                                    color: Theme.textPrimary
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.DemiBold }
                                    bottomPadding: 4
                                }

                                // Field rows
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
                                                modelData.byteLength === root.hlLength)
                                                return Qt.rgba(0, 0.83, 1, 0.12)
                                            return fieldMa.containsMouse ? Theme.bgCardHover : "transparent"
                                        }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Row {
                                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                            spacing: 8
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text:  modelData.name + ":"
                                                color: Theme.textMuted
                                                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                                width: 120; elide: Text.ElideRight
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text:  modelData.value
                                                color: (root.hlOffset >= 0 &&
                                                        modelData.absoluteOffset === root.hlOffset)
                                                       ? Theme.accentCyan : Theme.textPrimary
                                                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                                                elide: Text.ElideRight
                                                width: parent.width - 134
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

            // Vertical divider
            Rectangle {
                Layout.fillHeight: true
                Layout.topMargin:    Theme.spacingSM
                Layout.bottomMargin: Theme.spacingSM
                width: 1; color: Theme.borderSubtle
            }

            // ── Hex view (right pane) ──────────────────────────────────────
            Item {
                Layout.fillHeight: true
                Layout.fillWidth:  true

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
