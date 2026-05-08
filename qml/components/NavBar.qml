import QtQuick
import QtQuick.Controls.Basic
import OpenShark

Rectangle {
    id: root
    height: Theme.navBarHeight
    color:  Theme.bgOverlay

    property int currentPage: 0
    signal pageSelected(int index)

    readonly property real tabW: width / 5

    // Top separator
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color:  Theme.borderSubtle
    }

    // Sliding indicator bar
    Rectangle {
        y:      1
        height: 2
        width:  32
        x:      root.currentPage * root.tabW + (root.tabW - 32) / 2
        radius: 1
        color:  Theme.accentCyan

        Behavior on x {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingType }
        }
    }

    // Tab strip
    Row {
        anchors.fill: parent

        Repeater {
            model: [
                { label: "Live",     icon: "⬤" },
                { label: "Map",      icon: "◎" },
                { label: "Stats",    icon: "▦" },
                { label: "Captures", icon: "⬡" },
                { label: "Settings", icon: "⚙" },
            ]

            Item {
                id: tabItem
                width:  root.tabW
                height: root.height

                readonly property bool isActive: root.currentPage === index

                // Hover fill
                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: Theme.radiusSM
                    color:  tabMa.containsMouse && !tabItem.isActive
                            ? Theme.bgCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    anchors.centerIn: parent
                    text:           modelData.icon
                    font.pixelSize: 22
                    color:          tabItem.isActive   ? Theme.accentCyan
                                  : tabMa.containsMouse ? Theme.textSecond
                                  :                       Theme.textMuted
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                // Tooltip with page name
                ToolTip {
                    visible:  tabMa.containsMouse
                    text:     modelData.label
                    delay:    500
                    timeout:  3000
                }

                transform: Scale {
                    xScale: tabMa.pressed ? 0.88 : 1.0
                    yScale: tabMa.pressed ? 0.88 : 1.0
                    origin.x: tabItem.width  / 2
                    origin.y: tabItem.height / 2
                    Behavior on xScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                    Behavior on yScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: tabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked:    root.pageSelected(index)
                }
            }
        }
    }
}
