// Elegant session / power menu for Omarchy / Hyprland.
//
//   qs -n -d -c power                     → run (starts hidden)
//   qs -c power ipc call power toggle     → toggle (bind to a key)
//
// Keyboard: ←/→ select · Enter activate · Esc close. Theme-aware.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

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

    property bool shown: false
    property int sel: 0
    function show() { sel = 0; shown = true }
    function hide() { shown = false }
    function toggle() { shown ? hide() : show() }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    // action set — hover only selects; Enter/click activates (safe for destructive)
    readonly property var actions: [
        { glyph: "󰌾", label: "Lock",     cmd: ["loginctl", "lock-session"] },
        { glyph: "󰤄", label: "Suspend",  cmd: ["systemctl", "suspend"] },
        { glyph: "󰗽", label: "Log out",  cmd: ["hyprctl", "dispatch", "exit"] },
        { glyph: "󰜉", label: "Restart",  cmd: ["systemctl", "reboot"] },
        { glyph: "󰐥", label: "Shutdown", cmd: ["systemctl", "poweroff"] }
    ]
    function run(i) {
        if (i < 0 || i >= actions.length) return
        hide()
        Quickshell.execDetached(actions[i].cmd)
    }

    PanelWindow {
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-power"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, root.shown ? 0.82 : 0)
            Behavior on color { ColorAnimation { duration: 200 } }
            visible: root.shown
            TapHandler { onTapped: root.hide() }
        }

        // per-theme signature effect over the dimmed screen (behind the buttons)
        ThemeChrome {
            anchors.fill: parent
            themeName: root.themeName
            visible: root.shown
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.hide()
            Keys.onLeftPressed:  root.sel = (root.sel - 1 + root.actions.length) % root.actions.length
            Keys.onRightPressed: root.sel = (root.sel + 1) % root.actions.length
            Keys.onReturnPressed: root.run(root.sel)
            Keys.onEnterPressed:  root.run(root.sel)

            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            visible: opacity > 0.01

            Column {
                anchors.centerIn: parent
                spacing: 34
                scale: root.shown ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.actions[root.sel].label
                    color: root.cFg; font.family: root.uiFont; font.pixelSize: 22; font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 22
                    Repeater {
                        model: root.actions
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool active: index === root.sel
                            width: 132; height: 132
                            radius: 24
                            color: active ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.20)
                                          : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.05)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border.width: active ? 2 : 1
                            border.color: active ? root.cAccent : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.12)
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            scale: active ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.glyph
                                    color: btn.active ? root.cAccent : root.cFg
                                    font.family: root.uiFont; font.pixelSize: 46
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.label
                                    color: btn.active ? root.cAccent : root.cDim
                                    font.family: root.uiFont; font.pixelSize: 13
                                }
                            }
                            HoverHandler { onHoveredChanged: if (hovered) root.sel = btn.index }
                            TapHandler { onTapped: root.run(btn.index) }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "←  →  select      ⏎  activate      esc  cancel"
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
