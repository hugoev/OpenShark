import QtQuick
import QtQuick.Effects
import OpenShark

Item {
    id: root

    property alias content: contentLoader.sourceComponent
    property bool  interactive: false
    property bool  hovered:     false
    property bool  selected:    false

    signal clicked()

    Rectangle {
        id: bg
        anchors.fill: parent
        radius:       Theme.radius
        color:        root.selected ? Qt.rgba(0, 0.83, 1, 0.08)
                    : root.hovered  ? Theme.bgCardHover
                    :                 Theme.bgCard

        border.color: root.selected ? Qt.rgba(0, 0.83, 1, 0.35)
                    : root.hovered  ? Theme.borderActive
                    :                 Theme.borderSubtle
        border.width: 1

        Behavior on color       { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType } }
        Behavior on border.color{ ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingType } }

        // Subtle inner glow when selected
        layer.enabled: root.selected
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:   Qt.rgba(0, 0.83, 1, 0.15)
            shadowBlur:    0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled:      root.interactive
        hoverEnabled: true
        onEntered:    root.hovered = true
        onExited:     root.hovered = false
        onClicked:    root.clicked()
    }

    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
}
