// Themed notification daemon for Omarchy / Hyprland (replaces mako's popups).
//
//   qs -n -d -c notifications        → run (owns org.freedesktop.Notifications)
//
// Renders desktop notifications as per-theme cards:
//   • Morrowind    → an illuminated parchment scroll (Pelagiad, gold rule, wax seal)
//   • PlayStation  → a PS1 BIOS dialog (deep-blue bevel, four face-button strip)
//   • other themes → a clean accent-tinted card
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    // ── theme ─────────────────────────────────────────────────────────────
    readonly property string omarchyCurrent: Quickshell.env("HOME") + "/.config/omarchy/current"
    property var palette: ({})
    function col(k, fb) { var v = palette[k]; return (v && /^#[0-9A-Fa-f]{6}$/.test(v)) ? v : fb }
    readonly property color cBg:     col("background", "#14100A")
    readonly property color cFg:     col("foreground", "#E8E4D8")
    readonly property color cAccent: col("accent", "#D9B167")

    property string themeName: ""
    readonly property string family: themeName.indexOf("playstation") === 0 ? "ps1"
                                   : (themeName.indexOf("morrowind") === 0 ? "morrowind" : "default")
    readonly property bool parchment: themeName.indexOf("parchment") >= 0
    readonly property string uiFont: "JetBrainsMono Nerd Font"
    readonly property string cardFont: family === "morrowind" ? "Pelagiad" : uiFont

    FileView {
        id: colorsFile
        path: root.omarchyCurrent + "/theme/colors.toml"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var out = {}, lines = text().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"/)
                if (m) out[m[1]] = m[2]
            }
            root.palette = out
        }
    }
    FileView {
        path: root.omarchyCurrent + "/theme.name"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.themeName = text().trim().toLowerCase().replace(/\s+/g, "-"); colorsFile.reload() }
    }

    // ── notification server ───────────────────────────────────────────────
    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: (n) => {
            n.tracked = true
            var h = root.histArr.slice()
            h.unshift(root.shp(n))
            if (h.length > 30) h = h.slice(0, 30)
            root.histArr = h
            root.emitBus()
        }
    }

    // ── bridge to the Rise bar's notification-history panel ───────────────
    // The bar polls a JSON file in makoctl's shape {token,list,history}; we write
    // it here so the bar keeps its history/badge without mako. `token` changes per
    // server launch (so ids that reset across launches never collide in the bar).
    property string busToken: ""
    property var histArr: []
    property string lastBus: ""
    function shp(n) { return { id: n.id, app_name: n.appName, summary: n.summary, body: n.body } }
    function emitBus() {
        var vals = server.trackedNotifications.values
        var list = []
        for (var i = 0; i < vals.length; i++) list.push(shp(vals[i]))
        var payload = JSON.stringify({ token: root.busToken, list: list, history: root.histArr })
        if (payload === root.lastBus) return
        root.lastBus = payload
        busFile.setText(payload)
    }
    FileView { id: busFile; path: Quickshell.env("HOME") + "/.cache/qs-notif-bus.json" }
    Process {
        id: tokenProc
        running: true
        command: ["bash", "-lc", "printf '%s-%s' \"$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)\" \"$(date +%s%N)\""]
        stdout: StdioCollector { onStreamFinished: { root.busToken = this.text.trim(); root.emitBus() } }
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: root.emitBus() }   // backstop: catch expiries

    // dismiss requests from the bar
    IpcHandler {
        target: "notif"
        function dismiss(id: string): void {
            var vals = server.trackedNotifications.values
            for (var i = 0; i < vals.length; i++)
                if (String(vals[i].id) === String(id)) { vals[i].dismiss(); break }
        }
        function dismissAll(): void {
            var vals = server.trackedNotifications.values.slice()
            for (var i = 0; i < vals.length; i++) vals[i].dismiss()
        }
    }

    // gilt corner bracket for the Morrowind cards (an illuminated-manuscript ┐ mark)
    component Gilt: Item {
        width: 11; height: 11
        readonly property color c: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.85)
        Rectangle { anchors { top: parent.top; left: parent.left } width: parent.width; height: 1.5; color: parent.c }
        Rectangle { anchors { top: parent.top; left: parent.left } width: 1.5; height: parent.height; color: parent.c }
    }

    // ── themed card ───────────────────────────────────────────────────────
    component NotifCard: Item {
        id: card
        required property var notif
        readonly property bool critical: notif.urgency === NotificationUrgency.Critical
        readonly property bool ps1: root.family === "ps1"
        readonly property bool mw:  root.family === "morrowind"

        width: 414
        implicitHeight: frame.height

        // per-theme entrance: MW scroll-unfurl · PS1 CRT power-on flicker · else slide
        opacity: 0
        transform: [
            Scale     { id: unfurl; origin.x: 0; origin.y: 0; yScale: card.mw ? 0.0 : 1.0 },
            Translate { id: slide;  x: (card.mw || card.ps1) ? 0 : 48 }
        ]
        Component.onCompleted: (card.mw ? mwEntry : card.ps1 ? ps1Entry : defEntry).start()

        ParallelAnimation {   // Morrowind: unroll the scroll downward
            id: mwEntry
            NumberAnimation { target: card;   property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { target: unfurl; property: "yScale";  from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {   // PlayStation: snap on, then a brief CRT flicker
            id: ps1Entry
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1;    duration: 80 }
            NumberAnimation { target: card; property: "opacity"; to: 0.5;  duration: 45 }
            NumberAnimation { target: card; property: "opacity"; to: 1;    duration: 40 }
            NumberAnimation { target: card; property: "opacity"; to: 0.82; duration: 40 }
            NumberAnimation { target: card; property: "opacity"; to: 1;    duration: 70 }
        }
        ParallelAnimation {   // default: slide in from the right
            id: defEntry
            NumberAnimation { target: card;  property: "opacity"; from: 0; to: 1; duration: 240 }
            NumberAnimation { target: slide; property: "x"; from: 48; to: 0; duration: 280; easing.type: Easing.OutCubic }
        }

        // auto-dismiss (critical notifications persist until acted on)
        Timer {
            interval: card.critical ? 0 : (card.notif.urgency === NotificationUrgency.Low ? 4500 : 6500)
            running: !card.critical
            onTriggered: card.notif.dismiss()
        }

        Rectangle {
            id: frame
            width: parent.width
            height: body.implicitHeight + (card.mw ? 30 : 24)
            radius: card.ps1 ? 2 : (card.mw ? 3 : 12)

            // per-theme background
            gradient: card.ps1 ? ps1Grad : null
            color: card.ps1 ? "transparent"
                 : (card.mw ? Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, root.parchment ? 0.97 : 0.96)
                            : Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.95))
            border.width: 1
            border.color: card.critical ? "#D9556A"
                        : (card.mw ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.85)
                                   : (card.ps1 ? "#4E82C8" : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.5)))

            Gradient {
                id: ps1Grad
                GradientStop { position: 0.0; color: "#14294A" }
                GradientStop { position: 1.0; color: "#0A0F1C" }
            }

            // PS1: inner bevel line → raised BIOS-panel look
            Rectangle {
                visible: card.ps1
                anchors.fill: parent; anchors.margins: 3
                color: "transparent"
                radius: 1
                border.width: 1
                border.color: Qt.rgba(0.30, 0.46, 0.72, 0.55)
            }

            // PS1: four face-button colour strip along the top edge
            Row {
                visible: card.ps1
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 2; rightMargin: 2; topMargin: 2 }
                height: 3
                Repeater {
                    model: ["#5C8AC6", "#57B89A", "#C56FA9", "#D9556A"]
                    delegate: Rectangle { required property string modelData; width: (frame.width - 4) / 4; height: 3; color: modelData; opacity: 0.92 }
                }
            }

            // Morrowind: illuminated corner brackets
            Gilt { visible: card.mw; anchors { top: parent.top; left: parent.left; margins: 5 } }
            Gilt { visible: card.mw; rotation: 90;  anchors { top: parent.top; right: parent.right; margins: 5 } }
            Gilt { visible: card.mw; rotation: 180; anchors { bottom: parent.bottom; right: parent.right; margins: 5 } }
            Gilt { visible: card.mw; rotation: 270; anchors { bottom: parent.bottom; left: parent.left; margins: 5 } }

            // Morrowind: gilt rule down the left margin
            Rectangle {
                visible: card.mw
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 10; topMargin: 12; bottomMargin: 12 }
                width: 2
                radius: 1
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.55)
            }

            // Morrowind: wax seal (ring + wax + emblem), overlapping the top-left
            Item {
                visible: card.mw
                width: 26; height: 26
                anchors { horizontalCenter: parent.left; verticalCenter: parent.top; horizontalCenterOffset: 15; verticalCenterOffset: 15 }
                Rectangle { anchors.fill: parent; radius: width/2; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.9) }       // gilt ring
                Rectangle { anchors.centerIn: parent; width: 21; height: 21; radius: width/2; color: "#7C2E22"                                  // wax
                    Rectangle { anchors.centerIn: parent; width: 15; height: 15; radius: width/2; color: "#8A3428" }                            // raised centre
                    Text { anchors.centerIn: parent; text: "✦"; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.85); font.pixelSize: 11 }
                }
            }

            // ── content ──
            Column {
                id: body
                anchors {
                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: card.mw ? 24 : (card.ps1 ? 16 : 14)
                    rightMargin: 16
                }
                spacing: 4

                Row {
                    spacing: 10
                    width: parent.width

                    Image {
                        id: icon
                        readonly property int sz: 34
                        width: sz; height: sz
                        sourceSize.width: sz; sourceSize.height: sz
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                        source: card.notif.image !== "" ? card.notif.image
                              : (card.notif.appIcon !== "" ? Quickshell.iconPath(card.notif.appIcon, "dialog-information") : "")
                    }

                    Column {
                        spacing: 2
                        width: parent.width - (icon.visible ? icon.sz + 10 : 0)

                        Text {
                            width: parent.width
                            text: card.notif.summary
                            color: card.ps1 ? "#EAF2FF" : (card.mw ? root.cAccent : root.cFg)
                            font.family: root.cardFont
                            font.pixelSize: card.mw ? 17 : 14
                            font.bold: !card.mw
                            font.letterSpacing: card.ps1 ? 0.5 : 0
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: card.notif.body !== ""
                            text: card.notif.body
                            textFormat: Text.PlainText
                            color: card.ps1 ? "#A9C4EC" : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, card.mw ? 0.85 : 0.75)
                            font.family: root.cardFont
                            font.pixelSize: card.mw ? 14 : 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }

                // action buttons
                Row {
                    spacing: 6
                    visible: card.notif.actions.length > 0
                    Repeater {
                        model: card.notif.actions
                        delegate: Rectangle {
                            required property var modelData
                            height: 22
                            width: lbl.implicitWidth + 18
                            radius: card.ps1 ? 1 : 4
                            color: btnHover.hovered ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.28)
                                                    : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.14)
                            border.width: 1
                            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.5)
                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData.text
                                color: card.ps1 ? "#EAF2FF" : root.cFg
                                font.family: root.cardFont; font.pixelSize: 12
                            }
                            HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { modelData.invoke(); card.notif.dismiss() } }
                        }
                    }
                }
            }

            // click anywhere else to dismiss
            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: card.notif.dismiss()
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    // ── overlay (top-right, only mapped when notifications exist) ──────────
    PanelWindow {
        anchors { top: true; right: true }
        implicitWidth: 430
        implicitHeight: Math.max(1, stack.implicitHeight + 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        visible: server.trackedNotifications.values.length > 0

        Column {
            id: stack
            anchors { top: parent.top; right: parent.right; topMargin: 12; rightMargin: 12 }
            spacing: 10
            Repeater {
                model: server.trackedNotifications
                delegate: NotifCard { required property var modelData; notif: modelData }
            }
        }
    }
}
