import QtQuick
import QtQuick.Layouts
import OpenShark

Item {
    id: root
    height: 44

    // Required so ListView injects model roles (and the row index) into this component
    required property int    index
    required property string timestamp
    required property string protocol
    required property string protocolColor
    required property string summary
    required property int    length
    required property bool   bookmarked

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
                font.family:    "Menlo, Courier, monospace"
                font.pixelSize: Theme.fontSizeXS
                Layout.preferredWidth: 90
            }

            ProtocolBadge {
                protocol:   root.protocol
                badgeColor: root.protocolColor
                Layout.preferredWidth: 56
            }

            Text {
                text:  root.summary
                color: Theme.textPrimary
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text:  root.length + " B"
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                Layout.preferredWidth: 52
                horizontalAlignment:   Text.AlignRight
            }

            // Bookmark toggle
            Text {
                text:    root.bookmarked ? "★" : "☆"
                color:   root.bookmarked ? "#ffd740" : Theme.textMuted
                font.pixelSize: 14
                Layout.preferredWidth: 20
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
