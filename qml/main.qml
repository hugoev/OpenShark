import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import OpenShark

ApplicationWindow {
    id: window
    visible:       true
    width:         1280
    height:        800
    minimumWidth:  900
    minimumHeight: 600
    title:         "OpenShark"
    color:         Theme.bgBase

    property int currentPage: 0

    // ── Status strip (top) ────────────────────────────────────────────────────
    StatusStrip {
        id: statusStrip
        anchors { top: parent.top; left: parent.left; right: parent.right }
    }

    // ── Page stack ────────────────────────────────────────────────────────────
    StackLayout {
        anchors {
            top:    statusStrip.bottom
            left:   parent.left
            right:  parent.right
            bottom: navBar.top
        }
        currentIndex: window.currentPage

        LivePage     {}
        MapPage      {}
        StatsPage    {}
        CapturesPage {}
        SettingsPage {}
    }

    // ── Nav bar (bottom) ──────────────────────────────────────────────────────
    NavBar {
        id: navBar
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        currentPage: window.currentPage
        onPageSelected: (idx) => window.currentPage = idx
    }

    // ── Error toast ───────────────────────────────────────────────────────────
    Connections {
        target: appController
        function onError(msg) { errorToast.show(msg) }
    }

    Rectangle {
        id: errorToast
        anchors {
            bottom:           navBar.top
            horizontalCenter: parent.horizontalCenter
            bottomMargin:     16
        }
        width:   Math.min(errorText.implicitWidth + 32, 500)
        height:  44
        radius:  22
        color:   Qt.rgba(0.89, 0.098, 0.216, 0.9)
        visible: opacity > 0
        opacity: 0

        property string message: ""
        function show(msg) {
            message = msg
            opacity = 1
            hideTimer.restart()
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        Text {
            id: errorText
            anchors.centerIn: parent
            text:  errorToast.message
            color: "white"
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSM }
        }

        Timer { id: hideTimer; interval: 4000; onTriggered: errorToast.opacity = 0 }
    }
}
