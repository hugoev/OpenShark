import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

Item {
    ScrollView {
        anchors { fill: parent; margins: Theme.spacingLG }
        contentWidth: availableWidth

        Column {
            width: parent.width
            spacing: Theme.spacingLG

            Text {
                text:  "Settings"
                color: Theme.textPrimary
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXL; weight: Font.DemiBold }
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    text:  "CAPTURE"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.DemiBold; letterSpacing: 1.2 }
                    bottomPadding: 6
                }

                SettingsRow { width: parent.width; label: "Snapshot length"; value: "65535 bytes" }
                SettingsRow { width: parent.width; label: "Buffer size";     value: "65536 slots" }
                SettingsRow { width: parent.width; label: "UI drain rate";   value: "30 Hz" }
                SettingsRow { width: parent.width; label: "Promiscuous mode"; value: "Enabled" }
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    text:  "ABOUT"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS; weight: Font.DemiBold; letterSpacing: 1.2 }
                    bottomPadding: 6
                }

                SettingsRow { width: parent.width; label: "Version";  value: "0.1.0" }
                SettingsRow { width: parent.width; label: "Qt";       value: "6.x"   }
                SettingsRow { width: parent.width; label: "libpcap";  value: "System" }
            }
        }
    }
}
