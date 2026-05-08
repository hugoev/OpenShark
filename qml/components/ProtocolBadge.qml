import QtQuick
import OpenShark

Rectangle {
    id: root

    property string protocol: "???"
    property string badgeColor: "#616161"

    implicitWidth:  label.implicitWidth + 14
    implicitHeight: 20
    radius:         Theme.radiusXS
    color:          Qt.rgba(
                        parseInt(badgeColor.slice(1,3), 16) / 255,
                        parseInt(badgeColor.slice(3,5), 16) / 255,
                        parseInt(badgeColor.slice(5,7), 16) / 255,
                        0.18)
    border.color:   badgeColor
    border.width:   1

    Text {
        id: label
        anchors.centerIn: parent
        text:  root.protocol
        color: root.badgeColor
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.DemiBold }
    }
}
