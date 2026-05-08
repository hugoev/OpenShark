import QtQuick
import QtQuick.Controls.Basic
import OpenShark

// Full-screen overlay showing a reassembled TCP stream
Rectangle {
    id: root

    property var streamData: null   // result of followStream()
    signal closed()

    color: Qt.rgba(0, 0, 0, 0.82)
    visible: streamData !== null
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

    // Click outside to close
    MouseArea { anchors.fill: parent; onClicked: root.closed() }

    Rectangle {
        anchors.centerIn: parent
        width:  Math.min(parent.width  - 80, 860)
        height: Math.min(parent.height - 80, 600)
        radius: Theme.radius
        color:  Theme.bgCard
        border.color: Theme.borderActive
        border.width: 1

        // Eat clicks so they don't propagate to the backdrop
        MouseArea { anchors.fill: parent }

        // Header
        Rectangle {
            id: hdr
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 44
            color: Theme.bgOverlay
            radius: Theme.radius

            // Square off bottom corners
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: Theme.radius
                color: parent.color
            }

            Text {
                anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
                text: root.streamData ? "Follow Stream  ·  " + root.streamData.streamKey : ""
                color: Theme.textPrimary
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.DemiBold }
                elide: Text.ElideMiddle
                width: parent.width - 80
            }

            Text {
                anchors { right: parent.right; rightMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
                text: root.streamData
                      ? "%1 segment(s)".arg(root.streamData.segmentCount)
                      : ""
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
            }

            // Close button
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 28; height: 28; radius: 14
                color: closeMa.containsMouse ? Theme.bgCardHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 12 }
                MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.closed() }
            }
        }

        // Legend
        Row {
            id: legend
            anchors { top: hdr.bottom; left: parent.left; leftMargin: Theme.spacingLG; topMargin: 8 }
            spacing: Theme.spacingLG

            Row {
                spacing: 6
                Rectangle { width: 10; height: 10; radius: 2; color: Theme.accentCyan; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Client →"; color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                spacing: 6
                Rectangle { width: 10; height: 10; radius: 2; color: "#ff9100"; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "← Server"; color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Stream content
        ScrollView {
            anchors {
                top: legend.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 1; rightMargin: 1; bottomMargin: 1
            }
            clip: true
            contentWidth: availableWidth

            Column {
                width: parent.width
                padding: Theme.spacingLG
                spacing: 2

                Repeater {
                    model: root.streamData ? root.streamData.segments : []

                    Rectangle {
                        width: parent.width - Theme.spacingLG * 2
                        height: segText.implicitHeight + 12
                        radius: Theme.radiusSM
                        color: modelData.fromClient
                               ? Qt.rgba(0, 0.83, 1, 0.06)
                               : Qt.rgba(1, 0.57, 0, 0.06)
                        border.color: modelData.fromClient
                                      ? Qt.rgba(0, 0.83, 1, 0.2)
                                      : Qt.rgba(1, 0.57, 0, 0.2)
                        border.width: 1

                        Text {
                            id: segText
                            anchors { fill: parent; margins: 6 }
                            text: modelData.text || "(no printable data)"
                            color: modelData.fromClient ? Theme.accentCyan : "#ff9100"
                            font { family: "Menlo, Courier, monospace"; pixelSize: 11 }
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }

                // Empty state
                Item {
                    width: parent.width - Theme.spacingLG * 2
                    height: 60
                    visible: !root.streamData || root.streamData.segmentCount === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No payload data in this stream"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                    }
                }
            }
        }
    }
}
