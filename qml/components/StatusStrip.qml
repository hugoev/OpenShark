import QtQuick
import OpenShark

Rectangle {
    id: root
    height: Theme.statusHeight
    color:  Theme.bgOverlay

    // Bottom separator
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color:  Theme.borderSubtle
    }

    Row {
        anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacingLG

        // Live indicator dot
        Row {
            spacing: 8
            visible: appController.capturing

            Rectangle {
                id: liveDot
                width: 8; height: 8
                radius: 4
                color:  Theme.accentRed
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running:  appController.capturing
                    loops:    Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text:  "LIVE"
                color: Theme.accentRed
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.DemiBold; letterSpacing: 1.5 }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text:  appController.capturing
                   ? appController.activeInterface
                   : "No capture"
            color: Theme.textSecond
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors { right: parent.right; rightMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacingSM

        Text {
            text:  appController.packetCount.toLocaleString()
            color: Theme.textPrimary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMD; weight: Font.Medium }
            anchors.verticalCenter: parent.verticalCenter

            Behavior on text { }
        }

        Text {
            text:  "packets"
            color: Theme.textMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
