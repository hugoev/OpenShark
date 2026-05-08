import QtQuick
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
                property bool showTooltip: false

                // Custom tooltip pill — floats above the nav bar
                Rectangle {
                    visible: tabItem.showTooltip
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                    x: (parent.width - width) / 2
                    y: -height - 10
                    width:  tipLabel.implicitWidth + 20
                    height: 26
                    radius: 13
                    z:      100
                    color:  Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    Text {
                        id: tipLabel
                        anchors.centerIn: parent
                        text:  modelData.label
                        color: Theme.accentCyan
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.Medium }
                    }
                }

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

                // Delay timer — shows tooltip 450 ms after mouse enters
                Timer {
                    id: hoverTimer
                    interval: 450
                    onTriggered: tabItem.showTooltip = true
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
                    onEntered:    hoverTimer.start()
                    onExited:     { hoverTimer.stop(); tabItem.showTooltip = false }
                }
            }
        }
    }
}
