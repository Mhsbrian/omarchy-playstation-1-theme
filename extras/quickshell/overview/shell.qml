// Workspace overview (mini-map) for Omarchy / Hyprland.
//
//   qs -n -d -c overview                          → run (starts hidden)
//   qs -c overview ipc call overview toggle       → toggle (bind to a key)
//
// Draws each workspace as a scaled layout of its windows (from hyprctl clients),
// click a workspace to switch or a window to focus. Theme-aware effects.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ── theme ─────────────────────────────────────────────────────────────
    readonly property string omarchyCurrent: Quickshell.env("HOME") + "/.config/omarchy/current"
    property var palette: ({})
    function col(k, fb) { var v = palette[k]; return (v && /^#[0-9A-Fa-f]{6}$/.test(v)) ? v : fb }
    readonly property color cBg:     col("background", "#14100A")
    readonly property color cFg:     col("foreground", "#E8E4D8")
    readonly property color cAccent: col("accent", "#D9B167")
    readonly property color cDim:    Qt.rgba(cFg.r, cFg.g, cFg.b, 0.55)
    readonly property string uiFont: "JetBrainsMono Nerd Font"

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
    property string themeName: ""
    FileView {
        path: root.omarchyCurrent + "/theme.name"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.themeName = text().trim().toLowerCase().replace(/\s+/g, "-"); colorsFile.reload() }
    }

    // ── state + IPC ───────────────────────────────────────────────────────
    property bool shown: false
    property var windows: []
    property int monW: 2160
    property int monH: 1350
    property int activeWs: 1
    property int sel: 0

    function refresh() {
        clientsProc.running = false; clientsProc.running = true
        monProc.running = false; monProc.running = true
    }
    function show() { shown = true; refresh() }
    function hide() { shown = false }
    function toggle() { shown ? hide() : show() }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsOut
            onStreamFinished: {
                try {
                    var arr = JSON.parse(clientsOut.text)
                    root.windows = arr.filter(function (w) {
                        return w && w.mapped !== false && w.workspace && w.workspace.id > 0
                    })
                } catch (e) { root.windows = [] }
            }
        }
    }
    Process {
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monOut
            onStreamFinished: {
                try {
                    var m = JSON.parse(monOut.text)[0]
                    root.monW = Math.round(m.width / m.scale)
                    root.monH = Math.round(m.height / m.scale)
                    root.activeWs = m.activeWorkspace.id
                } catch (e) {}
            }
        }
    }

    // workspaces to show: 1..max(5, highest used), sel starts on active
    readonly property var wsIds: {
        var hi = 5
        for (var i = 0; i < windows.length; i++) hi = Math.max(hi, windows[i].workspace.id)
        hi = Math.max(hi, activeWs)
        var out = []
        for (var k = 1; k <= hi; k++) out.push(k)
        return out
    }
    function windowsIn(id) { return windows.filter(function (w) { return w.workspace.id === id }) }
    function switchTo(id) { Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "" + id]); hide() }
    function focusWin(addr, id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr]); hide()
    }
    onShownChanged: if (shown) sel = Math.max(0, wsIds.indexOf(activeWs))

    readonly property int cols: Math.min(wsIds.length, 4)
    readonly property int panelW: 320
    readonly property int panelH: Math.round(panelW * monH / monW)

    // ── window ────────────────────────────────────────────────────────────
    PanelWindow {
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-overview"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.8)
            TapHandler { onTapped: root.hide() }
        }

        ThemeChrome { anchors.fill: parent; themeName: root.themeName; visible: root.shown }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.hide()
            Keys.onLeftPressed:  root.sel = (root.sel - 1 + root.wsIds.length) % root.wsIds.length
            Keys.onRightPressed: root.sel = (root.sel + 1) % root.wsIds.length
            Keys.onUpPressed:    root.sel = Math.max(0, root.sel - root.cols)
            Keys.onDownPressed:  root.sel = Math.min(root.wsIds.length - 1, root.sel + root.cols)
            Keys.onReturnPressed: root.switchTo(root.wsIds[root.sel])
            Keys.onEnterPressed:  root.switchTo(root.wsIds[root.sel])
            Keys.onPressed: (e) => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { root.switchTo(e.key - Qt.Key_0); e.accepted = true }
            }

            Column {
                anchors.centerIn: parent
                spacing: 24
                scale: root.shown ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Workspaces"
                    color: root.cFg; font.family: root.uiFont; font.pixelSize: 20; font.bold: true
                }

                Grid {
                    id: grid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: root.cols
                    columnSpacing: 20
                    rowSpacing: 20

                    Repeater {
                        model: root.wsIds
                        delegate: Rectangle {
                            id: panel
                            required property var modelData
                            required property int index
                            readonly property int wsId: modelData
                            readonly property bool isActive: wsId === root.activeWs
                            readonly property bool isSel: index === root.sel
                            width: root.panelW
                            height: root.panelH + 26
                            radius: 14
                            color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, isSel ? 0.10 : 0.05)
                            Behavior on color { ColorAnimation { duration: 130 } }
                            border.width: isSel ? 2 : 1
                            border.color: isSel ? root.cAccent
                                        : (isActive ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.5)
                                                    : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.12))
                            Behavior on border.color { ColorAnimation { duration: 130 } }
                            scale: isSel ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                            // ── workspace number + active dot ──
                            Row {
                                id: hdr
                                anchors.top: parent.top; anchors.left: parent.left
                                anchors.topMargin: 6; anchors.leftMargin: 10
                                spacing: 6
                                Text {
                                    text: panel.wsId
                                    color: panel.isSel || panel.isActive ? root.cAccent : root.cDim
                                    font.family: root.uiFont; font.pixelSize: 13; font.bold: true
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: panel.isActive
                                    width: 6; height: 6; radius: 3; color: root.cAccent
                                }
                            }

                            // ── the mini-map surface ──
                            Item {
                                id: surface
                                anchors.top: hdr.bottom; anchors.topMargin: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: root.panelW - 12
                                height: root.panelH - 12
                                readonly property real sc: width / root.monW

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.windowsIn(panel.wsId).length === 0
                                    text: "empty"
                                    color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.25)
                                    font.family: root.uiFont; font.pixelSize: 12
                                }

                                Repeater {
                                    model: root.windowsIn(panel.wsId)
                                    delegate: Rectangle {
                                        id: win
                                        required property var modelData
                                        readonly property var at: modelData.at || [0, 0]
                                        readonly property var sz: modelData.size || [100, 100]
                                        x: Math.max(0, at[0] * surface.sc)
                                        y: Math.max(0, at[1] * surface.sc)
                                        width: Math.max(18, sz[0] * surface.sc)
                                        height: Math.max(14, sz[1] * surface.sc)
                                        radius: 6
                                        color: winHover.hovered ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.28)
                                                                 : Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.85)
                                        Behavior on color { ColorAnimation { duration: 110 } }
                                        border.width: 1
                                        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, winHover.hovered ? 0.8 : 0.3)

                                        Image {
                                            id: winIcon
                                            anchors.centerIn: parent
                                            readonly property int s: Math.max(14, Math.min(parent.width, parent.height) * 0.5)
                                            width: s; height: s; sourceSize.width: s; sourceSize.height: s
                                            asynchronous: true
                                            source: Quickshell.iconPath(String(win.modelData.class || "").toLowerCase(), "application-x-executable")
                                            fillMode: Image.PreserveAspectFit
                                            visible: status === Image.Ready
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: winIcon.status !== Image.Ready
                                            text: (String(win.modelData.class || "?").charAt(0)).toUpperCase()
                                            color: root.cAccent; font.family: root.uiFont; font.bold: true
                                            font.pixelSize: Math.max(10, Math.min(parent.width, parent.height) * 0.4)
                                        }

                                        HoverHandler { id: winHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: root.focusWin(win.modelData.address, panel.wsId) }
                                    }
                                }
                            }

                            HoverHandler { onHoveredChanged: if (hovered) root.sel = panel.index }
                            TapHandler { onTapped: root.switchTo(panel.wsId) }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "←→↑↓ select · ⏎ switch · 1-9 jump · esc close · click a window to focus it"
                    color: root.cDim; font.family: root.uiFont; font.pixelSize: 12
                }
            }

            Connections {
                target: root
                function onShownChanged() { if (root.shown) keys.forceActiveFocus() }
            }
        }
    }
}
