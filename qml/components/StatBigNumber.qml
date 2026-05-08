import QtQuick
import OpenShark

Rectangle {
    property string label: ""
    property string value: "0"

    height: 80
    radius: Theme.radius
    color:  Theme.bgCard
    border.color: Theme.borderSubtle
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  value
            color: Theme.textPrimary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXL; weight: Font.DemiBold }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  label
            color: Theme.textMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
        }
    }
}
