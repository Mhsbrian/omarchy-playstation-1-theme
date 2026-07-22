// Spotlight-style app launcher for Omarchy / Hyprland.
//
//   qs -n -d -c launcher                        → run (starts hidden)
//   qs -c launcher ipc call launcher toggle     → toggle (bind to a key)
//
// Fuzzy app search, keyboard-driven, theme-aware (reads omarchy colors.toml).
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
    readonly property color cCard:   Qt.rgba(cBg.r, cBg.g, cBg.b, 0.98)
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
    readonly property string family: themeName.indexOf("playstation") === 0 ? "ps1"
                                   : (themeName.indexOf("morrowind") === 0 ? "morrowind" : "default")
    FileView {
        path: root.omarchyCurrent + "/theme.name"
        watchChanges: true
        onFileChanged: reload()
        // theme.name is written in-place so this watch survives the theme swap;
        // colors.toml gets a new inode (mv), so force-reload it here.
        onLoaded: { root.themeName = text().trim().toLowerCase().replace(/\s+/g, "-"); colorsFile.reload() }
    }

    // ── state + IPC ───────────────────────────────────────────────────────
    property bool shown: false
    property var apps: []
    property string query: ""
    property int sel: 0

    function refresh() { appLister.running = false; appLister.running = true }
    function show() { query = ""; sel = 0; shown = true; refresh() }
    function hide() { shown = false }
    function toggle() { shown ? hide() : show() }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function state(): string { return (root.shown ? "shown" : "hidden") + " theme=" + root.themeName + " apps=" + root.apps.length + " filtered=" + root.filtered.length }
    }

    Process {
        id: appLister
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/launcher/list-apps.py"]
        stdout: StdioCollector {
            id: appsOut
            onStreamFinished: { try { root.apps = JSON.parse(appsOut.text) } catch (e) { root.apps = [] } }
        }
    }

    // ── fuzzy filter ──────────────────────────────────────────────────────
    function subseq(s, q) { var j = 0; for (var i = 0; i < s.length && j < q.length; i++) if (s[i] === q[j]) j++; return j === q.length }
    function scoreApp(a, q) {
        var n = a.name.toLowerCase(), c = (a.comment || "").toLowerCase()
        var idx = n.indexOf(q)
        if (idx === 0) return 0
        if (idx > 0) return 2 + idx
        if (subseq(n, q)) return 40
        if (c.indexOf(q) >= 0) return 80
        if (subseq(c, q)) return 120
        return -1
    }
    readonly property var filtered: {
        var q = query.trim().toLowerCase()
        if (q === "") return apps
        var scored = []
        for (var i = 0; i < apps.length; i++) {
            var s = scoreApp(apps[i], q)
            if (s >= 0) scored.push({ a: apps[i], s: s })
        }
        scored.sort(function (x, y) { return x.s - y.s || x.a.name.localeCompare(y.a.name) })
        return scored.map(function (o) { return o.a })
    }

    function launch(app) { if (!app) return; Quickshell.execDetached(["gtk-launch", app.id]); hide() }
    function activate() { var f = filtered; if (f.length) launch(f[Math.max(0, Math.min(sel, f.length - 1))]) }
    onQueryChanged: sel = 0

    readonly property int rowH: 58
    readonly property int listH: Math.min(Math.max(filtered.length, 1), 7) * rowH

    // ── window ────────────────────────────────────────────────────────────
    PanelWindow {
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {   // dim + click-away
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, root.shown ? 0.45 : 0)
            Behavior on color { ColorAnimation { duration: 180 } }
            visible: root.shown
            TapHandler { onTapped: root.hide() }
        }

        Rectangle {
            id: card
            width: 660
            height: 24 + 54 + (root.filtered.length > 0 ? 10 + root.listH : 0) + 24
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.17 + (root.shown ? 0 : -18)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            scale: root.shown ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            visible: opacity > 0.01

            radius: 22
            color: root.cCard
            border.width: 1
            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35)
            clip: true

            // per-theme signature effect (CRT scanlines / gold ash motes)
            ThemeChrome {
                anchors.fill: parent
                themeName: root.themeName
                z: 5
            }

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 10

                // ── search box ──
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 14
                    color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"; color: root.cAccent
                            font.family: root.uiFont; font.pixelSize: 20
                        }
                        TextInput {
                            id: input
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            color: root.cFg
                            font.family: root.uiFont; font.pixelSize: 18
                            clip: true
                            selectByMouse: true
                            selectionColor: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.4)
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: root.hide()
                            Keys.onReturnPressed: root.activate()
                            Keys.onEnterPressed: root.activate()
                            Keys.onUpPressed:   root.sel = (root.sel - 1 + Math.max(1, root.filtered.length)) % Math.max(1, root.filtered.length)
                            Keys.onDownPressed: root.sel = (root.sel + 1) % Math.max(1, root.filtered.length)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text === ""
                                text: "Search apps…"
                                color: root.cDim; font: input.font
                            }
                        }
                    }
                }

                // ── per-theme flourish (PS1 face-button colors / Morrowind gold rule) ──
                Item {
                    width: parent.width; height: 3
                    visible: root.family !== "default"
                    Row {   // PlayStation: ▲●✕■ colors
                        anchors.centerIn: parent
                        width: parent.width * 0.5; height: 3
                        visible: root.family === "ps1"
                        Rectangle { width: parent.width / 4; height: 3; radius: 1; color: "#E23B2E" }
                        Rectangle { width: parent.width / 4; height: 3; color: "#F5C400" }
                        Rectangle { width: parent.width / 4; height: 3; color: "#1FBF61" }
                        Rectangle { width: parent.width / 4; height: 3; radius: 1; color: "#2E8AE6" }
                    }
                    Rectangle {   // Morrowind: fading gold rule
                        anchors.centerIn: parent
                        width: parent.width * 0.6; height: 2; radius: 1
                        visible: root.family === "morrowind"
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: root.cAccent }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }

                // ── results ──
                ListView {
                    id: list
                    width: parent.width
                    height: root.listH
                    visible: root.filtered.length > 0
                    clip: true
                    model: root.filtered
                    currentIndex: root.sel
                    highlightMoveDuration: 120
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: root.rowH
                        radius: 12
                        readonly property bool active: index === root.sel
                        color: active ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.20)
                             : (rowHover.hovered ? Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.06) : "transparent")
                        Behavior on color { ColorAnimation { duration: 110 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 14
                            spacing: 14
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36; height: 36
                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    sourceSize.width: 36; sourceSize.height: 36
                                    asynchronous: true
                                    source: row.modelData.icon !== "" ? Quickshell.iconPath(row.modelData.icon, "") : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Rectangle {   // fallback: themed first-letter chip
                                    anchors.fill: parent
                                    visible: appIcon.status !== Image.Ready
                                    radius: 9
                                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: (row.modelData.name.charAt(0) || "?").toUpperCase()
                                        color: root.cAccent; font.family: root.uiFont; font.pixelSize: 18; font.bold: true
                                    }
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 62
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: row.modelData.name
                                    color: row.active ? root.cAccent : root.cFg
                                    font.family: root.uiFont; font.pixelSize: 15; font.bold: row.active
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: (row.modelData.comment || "") !== ""
                                    text: row.modelData.comment || ""
                                    color: root.cDim; font.family: root.uiFont; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        HoverHandler { id: rowHover; onHoveredChanged: if (hovered) root.sel = row.index }
                        TapHandler { onTapped: root.launch(row.modelData) }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.filtered.length === 0
                    text: "No matches"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.cDim; font.family: root.uiFont; font.pixelSize: 14
                }
            }

            Connections {
                target: root
                // Clear the field on every open — input.text is the source of truth
                // (onTextChanged drives root.query), so resetting query alone leaves
                // the previous search visible. Wipe the TextInput itself.
                function onShownChanged() { if (root.shown) { input.text = ""; input.forceActiveFocus() } }
            }
        }
    }
}
