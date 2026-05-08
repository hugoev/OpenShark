import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import OpenShark

Item {
    id: root

    // ── Toolbar ───────────────────────────────────────────────────────────────
    Rectangle {
        id: toolbar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 52
        color:  Theme.bgOverlay
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.borderSubtle
        }

        Row {
            anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            spacing: Theme.spacingSM

            // Open
            Rectangle {
                width: 90; height: 34; radius: 17
                color:  openMa.containsMouse ? Qt.rgba(0, 0.83, 1, 0.18) : Qt.rgba(0, 0.83, 1, 0.10)
                border.color: Theme.accentCyan; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "Open…"; color: Theme.accentCyan; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.Medium } }
                MouseArea { id: openMa; anchors.fill: parent; hoverEnabled: true; onClicked: openDialog.open() }
            }

            // Save current capture
            Rectangle {
                width: 110; height: 34; radius: 17
                opacity: appController.packetCount > 0 ? 1.0 : 0.4
                color:  saveMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "Save Capture"; color: Theme.textSecond; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM } }
                MouseArea {
                    id: saveMa; anchors.fill: parent; hoverEnabled: true; enabled: appController.packetCount > 0
                    onClicked: saveDialog.open()
                }
            }
        }

        Text {
            anchors { right: parent.right; rightMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
            text:  appController.packetCount > 0
                   ? "%1 packets loaded".arg(appController.packetCount.toLocaleString()) : ""
            color: Theme.textMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
        }
    }

    // ── Drop zone / empty state ───────────────────────────────────────────────
    Rectangle {
        anchors { top: toolbar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        color: "transparent"

        // Drop target
        Rectangle {
            anchors.centerIn: parent
            width: 360; height: 200
            radius: Theme.radius
            color:   dropArea.containsDrag ? Qt.rgba(0, 0.83, 1, 0.08) : Theme.bgCard
            border.color: dropArea.containsDrag ? Theme.accentCyan : Theme.borderSubtle
            border.width: dropArea.containsDrag ? 2 : 1
            Behavior on color        { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingSM

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "⬡"
                    font.pixelSize: 48
                    color: dropArea.containsDrag ? Theme.accentCyan : Theme.textMuted
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "Drop a .pcap file here"
                    color: Theme.textSecond
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMD }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  "or click Open above"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                onDropped: (drop) => {
                    if (drop.hasUrls) {
                        var p = drop.urls[0].toString().replace("file://", "")
                        appController.loadFile(p)
                    }
                }
            }
        }
    }

    // ── File dialogs ──────────────────────────────────────────────────────────
    FileDialog {
        id: openDialog
        title:        "Open Capture File"
        nameFilters:  ["Capture files (*.pcap *.pcapng)", "All files (*)"]
        onAccepted:   appController.loadFile(selectedFile.toString().replace("file://",""))
    }

    FileDialog {
        id: saveDialog
        title:       "Save Capture"
        fileMode:    FileDialog.SaveFile
        nameFilters: ["Capture files (*.pcap)"]
        onAccepted:  appController.saveCapture(selectedFile.toString().replace("file://",""))
    }
}
