import QtQuick
import QtQuick.Layouts
import OpenShark

Item {
    id: root
    height: 54

    required property int    index
    required property string timestamp
    required property string protocol
    required property string protocolColor
    required property string srcIp
    required property string dstIp
    required property int    srcPort
    required property int    dstPort
    required property int    length
    required property bool   bookmarked
    required property string info

    property bool selected:    false
    property bool searchMatch: false
    signal clicked()
    signal bookmarkToggled()

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius:       Theme.radiusSM
        color:        root.selected    ? Qt.rgba(0, 0.83, 1, 0.08)
                    : root.searchMatch ? Qt.rgba(1, 0.84, 0, 0.07)
                    : rowMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
        border.color: root.selected    ? Qt.rgba(0, 0.83, 1, 0.3)
                    : root.searchMatch ? Qt.rgba(1, 0.84, 0, 0.35)
                    : Theme.borderSubtle
        border.width: 1
        Behavior on color        { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 12

            Text {
                text:  root.timestamp
                color: Theme.textMuted
                font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeXS }
                Layout.preferredWidth: 90
                Layout.alignment: Qt.AlignVCenter
            }

            ProtocolBadge {
                protocol:   root.protocol
                badgeColor: root.protocolColor
                Layout.preferredWidth: 56
                Layout.alignment: Qt.AlignVCenter
            }

            // Two-line center: endpoint addresses + info
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: {
                        var s = root.srcIp
                        var d = root.dstIp
                        if (root.srcPort > 0) s += ":" + root.srcPort
                        if (root.dstPort > 0) d += ":" + root.dstPort
                        return s + "  →  " + d
                    }
                    color: Theme.textPrimary
                    font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeSM }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:  root.info
                    color: Theme.textSecond
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    elide: Text.ElideRight
                    visible: root.info.length > 0
                }
            }

            Text {
                text:  root.length + " B"
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                Layout.preferredWidth: 52
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text:    root.bookmarked ? "★" : "☆"
                color:   root.bookmarked ? "#ffd740" : Theme.textMuted
                font.pixelSize: 14
                Layout.preferredWidth: 20
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.bookmarkToggled()
                    }
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked:    root.clicked()
        }
    }
}
