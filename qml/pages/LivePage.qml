import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

Item {
    id: root

    // ── Search state ─────────────────────────────────────────────────────────
    property bool   searchVisible:    false
    property string searchQuery:      ""
    property var    searchMatches:    []
    property var    searchMatchSet:   ({})
    property int    currentMatch:     -1

    function runSearch(q) {
        searchQuery = q
        if (q.length === 0) {
            searchMatches  = []
            searchMatchSet = {}
            currentMatch   = -1
            return
        }
        var indices = appController.packets.searchAll(q)
        var set = {}
        for (var i = 0; i < indices.length; i++) set[indices[i]] = true
        searchMatches  = indices
        searchMatchSet = set
        currentMatch   = indices.length > 0 ? 0 : -1
        if (indices.length > 0)
            packetList.positionViewAtIndex(indices[0], ListView.Center)
    }

    function prevMatch() {
        if (searchMatches.length === 0) return
        currentMatch = (currentMatch - 1 + searchMatches.length) % searchMatches.length
        packetList.positionViewAtIndex(searchMatches[currentMatch], ListView.Center)
    }

    function nextMatch() {
        if (searchMatches.length === 0) return
        currentMatch = (currentMatch + 1) % searchMatches.length
        packetList.positionViewAtIndex(searchMatches[currentMatch], ListView.Center)
    }

    Timer {
        id: filterDebounce
        interval: 280
        onTriggered: appController.setDisplayFilter(filterInput.text)
    }

    // ── Top toolbar ──────────────────────────────────────────────────────────
    Rectangle {
        id: toolbar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 52
        color:  Theme.bgOverlay

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1; color: Theme.borderSubtle
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.spacingLG; rightMargin: Theme.spacingLG }
            spacing: Theme.spacingSM

            // Filter pill
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 17
                color:  Theme.bgCard
                border.color: filterInput.activeFocus ? Theme.accentCyan : Theme.borderSubtle
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                TextInput {
                    id: filterInput
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 14; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    color:          Theme.textPrimary
                    selectionColor: Qt.rgba(0, 0.83, 1, 0.3)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }

                    Text {
                        anchors.fill: parent
                        text:  "ip.src == 10.0.0.1  |  tcp.port == 443  |  protocol == TLS"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                        visible: !filterInput.text && !filterInput.activeFocus
                    }

                    onTextChanged: filterDebounce.restart()
                }
            }

            // Search toggle
            Rectangle {
                width: 34; height: 34; radius: 17
                color:  root.searchVisible
                        ? Qt.rgba(0, 0.83, 1, 0.12)
                        : (searchToggleMa.containsMouse ? Theme.bgCardHover : Theme.bgCard)
                border.color: root.searchVisible ? Theme.accentCyan : Theme.borderSubtle
                border.width: 1
                Behavior on color        { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "⌕"; color: root.searchVisible ? Theme.accentCyan : Theme.textMuted; font.pixelSize: 16 }
                MouseArea {
                    id: searchToggleMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        root.searchVisible = !root.searchVisible
                        if (!root.searchVisible) root.runSearch("")
                        else Qt.callLater(() => searchInput.forceActiveFocus())
                    }
                }
            }

            // Start / Stop button
            Rectangle {
                width: 90; height: 34
                radius: 17
                color:  appController.capturing
                        ? Qt.rgba(0.89, 0.098, 0.216, 0.18)
                        : Qt.rgba(0, 0.83, 1, 0.12)
                border.color: appController.capturing ? Theme.accentRed : Theme.accentCyan
                border.width: 1
                Behavior on color        { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:  appController.capturing ? "Stop" : "Start"
                    color: appController.capturing ? Theme.accentRed : Theme.accentCyan
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.DemiBold }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (appController.capturing)
                            appController.stopCapture()
                        else
                            ifacePicker.open()
                    }
                }
            }

            // Clear button
            Rectangle {
                width: 34; height: 34; radius: 17
                color:  clearMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 13 }
                MouseArea {
                    id: clearMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        appController.clearPackets()
                        root.runSearch("")
                    }
                }
            }
        }
    }

    // ── Search bar (collapsible) ──────────────────────────────────────────────
    Rectangle {
        id: searchBar
        anchors { top: toolbar.bottom; left: parent.left; right: parent.right }
        height: root.searchVisible ? 44 : 0
        clip:   true
        color:  Theme.bgOverlay
        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingType } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1; color: Theme.borderSubtle
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.spacingLG; rightMargin: Theme.spacingLG }
            spacing: Theme.spacingSM
            visible: root.searchVisible

            Rectangle {
                Layout.fillWidth: true
                height: 30; radius: 15
                color:  Theme.bgCard
                border.color: searchInput.activeFocus ? Theme.accentCyan : Theme.borderSubtle
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                TextInput {
                    id: searchInput
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textPrimary
                    selectionColor: Qt.rgba(0, 0.83, 1, 0.3)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Search packets…"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                    onTextChanged: root.runSearch(text)
                    Keys.onEscapePressed: {
                        root.searchVisible = false
                        root.runSearch("")
                    }
                    Keys.onReturnPressed: root.nextMatch()
                }
            }

            // Match counter
            Text {
                text: root.searchQuery.length > 0
                      ? (root.searchMatches.length > 0
                         ? "%1 / %2".arg(root.currentMatch + 1).arg(root.searchMatches.length)
                         : "No matches")
                      : ""
                color: root.searchMatches.length > 0 ? Theme.textSecond : Theme.accentRed
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                Layout.preferredWidth: 60
            }

            // Prev
            Rectangle {
                width: 28; height: 28; radius: 14
                enabled: root.searchMatches.length > 0
                opacity: enabled ? 1 : 0.4
                color: prevMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "▲"; color: Theme.textMuted; font.pixelSize: 10 }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.prevMatch() }
            }

            // Next
            Rectangle {
                width: 28; height: 28; radius: 14
                enabled: root.searchMatches.length > 0
                opacity: enabled ? 1 : 0.4
                color: nextMa.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: Theme.borderSubtle; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text { anchors.centerIn: parent; text: "▼"; color: Theme.textMuted; font.pixelSize: 10 }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.nextMatch() }
            }
        }
    }

    // ── Main split: packet list + detail panel ────────────────────────────────
    SplitView {
        anchors { top: searchBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        orientation: Qt.Vertical
        handle: Rectangle { implicitHeight: 4; color: Theme.borderSubtle }

        Item {
            SplitView.fillHeight:    true
            SplitView.minimumHeight: 200

            ListView {
                id: packetList
                anchors.fill: parent
                model:       appController.packets
                clip:        true
                spacing:     2
                cacheBuffer: 1200

                property bool stickToBottom: true
                onCountChanged:    if (stickToBottom) Qt.callLater(() => packetList.positionViewAtEnd())
                onMovementStarted: stickToBottom = false
                onAtYEndChanged:   if (atYEnd) stickToBottom = true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 3; color: Theme.textMuted }
                }

                delegate: PacketRow {
                    width:       packetList.width
                    selected:    packetList.currentIndex === index
                    searchMatch: root.searchMatchSet[index] === true
                    onClicked: {
                        packetList.currentIndex = (packetList.currentIndex === index) ? -1 : index
                    }
                    onBookmarkToggled: appController.packets.toggleBookmark(index)
                }
            }
        }

        Item {
            SplitView.preferredHeight: packetList.currentIndex >= 0 ? 320 : 0
            SplitView.minimumHeight:   0
            visible: packetList.currentIndex >= 0

            Behavior on SplitView.preferredHeight {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingType }
            }

            DetailPanel {
                anchors.fill: parent
                packetIndex:  packetList.currentIndex
                onFollowStreamRequested: (sd) => streamView.streamData = sd
            }
        }
    }

    // ── Follow-stream overlay ─────────────────────────────────────────────────
    StreamView {
        id: streamView
        anchors.fill: parent
        onClosed: streamData = null
    }

    // ── Interface picker popup ─────────────────────────────────────────────────
    Popup {
        id: ifacePicker
        anchors.centerIn: Overlay.overlay
        width:   420
        padding: 0
        modal:   true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color:        Theme.bgCard
            radius:       Theme.radius
            border.color: Theme.borderActive
            border.width: 1
        }

        contentItem: Column {
            width:   ifacePicker.width
            spacing: 0

            // ── Header ────────────────────────────────────────────────────────
            Item {
                width:  parent.width
                height: 56

                Text {
                    anchors { left: parent.left; leftMargin: Theme.spacingLG; verticalCenter: parent.verticalCenter }
                    text:  "Select Interface"
                    color: Theme.textPrimary
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeLG; weight: Font.DemiBold }
                }

                Rectangle {
                    anchors { right: parent.right; rightMargin: Theme.spacingMD; verticalCenter: parent.verticalCenter }
                    width: 28; height: 28; radius: 14
                    color: closeIfMa.containsMouse ? Theme.bgCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 12 }
                    MouseArea { id: closeIfMa; anchors.fill: parent; hoverEnabled: true; onClicked: ifacePicker.close() }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1; color: Theme.borderSubtle
                }
            }

            // ── Interface list ────────────────────────────────────────────────
            ListView {
                id: ifaceListView
                width:  parent.width
                height: Math.min(contentHeight + topMargin + bottomMargin, 300)
                model:  appController.interfaces
                clip:   true
                spacing: 4
                topMargin:    Theme.spacingMD
                bottomMargin: Theme.spacingMD
                leftMargin:   Theme.spacingMD
                rightMargin:  Theme.spacingMD

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 3; color: Theme.textMuted; opacity: 0.6 }
                }

                delegate: Rectangle {
                    required property string name
                    required property string description

                    width:  ifaceListView.width - ifaceListView.leftMargin - ifaceListView.rightMargin
                    height: 50
                    radius: Theme.radiusSM
                    color:  ifMa.containsMouse ? Theme.bgCardHover : Qt.rgba(1, 1, 1, 0.02)
                    border.color: Theme.borderSubtle; border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Column {
                        anchors {
                            left: parent.left; leftMargin: 14
                            right: parent.right; rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            width: parent.width
                            text:  name
                            color: Theme.textPrimary
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM; weight: Font.Medium }
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text:  description !== name ? description : ""
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                            visible: text !== ""
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: ifMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            appController.startCapture(name, captureFilterInput.text)
                            ifacePicker.close()
                        }
                    }
                }
            }

            // ── BPF filter ────────────────────────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Theme.borderSubtle }

            Item {
                width:  parent.width
                height: 78

                Column {
                    anchors {
                        fill: parent
                        topMargin: Theme.spacingMD; bottomMargin: Theme.spacingMD
                        leftMargin: Theme.spacingLG; rightMargin: Theme.spacingLG
                    }
                    spacing: Theme.spacingSM

                    Text {
                        text:  "Capture Filter  (BPF syntax)"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeXS }
                    }

                    Rectangle {
                        width:  parent.width
                        height: 36
                        radius: Theme.radiusSM
                        color:  Theme.bgOverlay
                        border.color: captureFilterInput.activeFocus ? Theme.accentCyan : Theme.borderSubtle
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        TextInput {
                            id: captureFilterInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.textPrimary
                            selectionColor: Qt.rgba(0, 0.83, 1, 0.3)
                            font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeSM }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text:  "tcp port 443  |  host 10.0.0.1  |  not arp"
                                color: Theme.textMuted
                                font { family: "Menlo, Courier, monospace"; pixelSize: Theme.fontSizeSM }
                                visible: !parent.text && !parent.activeFocus
                            }
                        }
                    }
                }
            }
        }
    }
}
