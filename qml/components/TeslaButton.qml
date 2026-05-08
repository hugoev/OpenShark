import QtQuick
import OpenShark

Item {
    id: root

    property string label:   ""
    property string icon:    ""
    property bool   active:  false
    property bool   danger:  false

    signal clicked()

    implicitWidth:  120
    implicitHeight: Theme.navBarHeight - 16

    Rectangle {
        id: bg
        anchors.fill: parent
        radius:       Theme.radius
        color: {
            if (root.danger)  return root.pressed ? Qt.darker(Theme.accentRed, 1.3) : Qt.rgba(0.89, 0.098, 0.216, 0.18)
            if (root.active)  return Qt.rgba(0, 0.83, 1, 0.12)
            return mouseArea.containsMouse ? Theme.bgCardHover : Theme.bgCard
        }
        border.color: {
            if (root.danger)  return root.danger && mouseArea.containsMouse ? Theme.accentRed : Qt.rgba(0.89, 0.098, 0.216, 0.4)
            if (root.active)  return Theme.accentCyan
            return mouseArea.containsMouse ? Theme.borderActive : Theme.borderSubtle
        }
        border.width: 1

        Behavior on color        { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType } }
    }

    property bool pressed: mouseArea.pressed

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  root.icon
            font.pixelSize: 20
            color: root.active ? Theme.accentCyan : root.danger ? Theme.accentRed : Theme.textSecond
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  root.label
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.Medium }
            color: root.active ? Theme.accentCyan : root.danger ? Theme.accentRed : Theme.textSecond
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    transform: Scale {
        id: pressScale
        xScale: mouseArea.pressed ? 0.95 : 1.0
        yScale: mouseArea.pressed ? 0.95 : 1.0
        origin.x: root.width  / 2
        origin.y: root.height / 2
        Behavior on xScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
        Behavior on yScale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked:    root.clicked()
    }
}
