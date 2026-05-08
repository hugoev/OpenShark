import QtQuick
import OpenShark

Rectangle {
    id: root
    height: Theme.navBarHeight
    color:  Theme.bgOverlay

    property int  currentPage: 0
    signal pageSelected(int index)

    // Top separator
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color:  Theme.borderSubtle
    }

    Row {
        anchors.centerIn: parent
        spacing:          Theme.spacingSM

        Repeater {
            model: [
                { label: "Live",      icon: "⬤" },
                { label: "Map",       icon: "◎" },
                { label: "Stats",     icon: "▦"  },
                { label: "Captures",  icon: "⬡" },
                { label: "Settings",  icon: "⚙" },
            ]

            TeslaButton {
                label:  modelData.label
                icon:   modelData.icon
                active: root.currentPage === index
                onClicked: root.pageSelected(index)
            }
        }
    }
}
