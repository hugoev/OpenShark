import QtQuick
import OpenShark

Item {
    property string label: ""
    property string value: ""

    height: 44

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSM
        color:  Theme.bgCard
        border.color: Theme.borderSubtle; border.width: 1

        Row {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  label
                color: Theme.textSecond
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                width: parent.width / 2
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  value
                color: Theme.textPrimary
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                horizontalAlignment: Text.AlignRight
                width: parent.width / 2
            }
        }
    }
}
