import QtQuick
import OpenShark

Item {
    property string pageLabel: ""
    property string icon:      ""
    property string note:      ""

    Rectangle {
        anchors.centerIn: parent
        width: 300; height: 160
        radius: Theme.radius
        color:  Theme.bgCard
        border.color: Theme.borderSubtle; border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  icon
                font.pixelSize: 42
                color: Theme.textMuted
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  pageLabel
                color: Theme.textSecond
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeLG; weight: Font.DemiBold }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  note
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
            }
        }
    }
}
