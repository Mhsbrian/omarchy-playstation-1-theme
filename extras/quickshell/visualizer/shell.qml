// Audio spectrum visualizer — integrated desktop element for Omarchy / Hyprland.
//
//   qs -n -d -c visualizer                          → run
//   qs -c visualizer ipc call visualizer toggle     → enable/disable (bind to a key)
//
// Bottom-edge strip on WlrLayer.Top, click-through, auto-fading with audio, with
// a neon bloom over the whole spectrum. Per theme:
//   • Morrowind    → iridescent gold capsule bars, glowing caps + peak dots
//   • PlayStation  → Metal Gear Solid codec: segmented green→amber→red LEDs with
//                    peak-hold, phosphor glow, CRT scanlines, HUD brackets & 140.85
import QtQuick
import QtQuick.Effects
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
    readonly property color cAccent: col("accent", "#D9B167")
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
    // Morrowind has two variants: dark ("morrowind") → ash palette;
    // light ("morrowind-parchment") → warm parchment-gold palette.
    readonly property bool parchment: themeName.indexOf("parchment") >= 0
    FileView {
        path: root.omarchyCurrent + "/theme.name"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.themeName = text().trim().toLowerCase().replace(/\s+/g, "-"); colorsFile.reload() }
    }

    // Morrowind = Telvanni bioluminescence: emerald spore-stalks with a breathing
    // chartreuse cap glow, amber spore-flecks, and slow drifting glowing spores.
    readonly property color telDeep:  "#123329"   // deep teal-forest (stalk base)
    readonly property color telEmer:  "#2DA86C"   // emerald body
    readonly property color telGlow:  "#9CF07A"   // bioluminescent cap glow
    readonly property color telSpore: "#E8C25E"   // amber spore (peaks + drifting motes)

    // ── state + IPC ───────────────────────────────────────────────────────
    property bool enabled: true
    readonly property int barCount: 44
    property var bars: []
    property var peaks: []
    property real energy: 0
    property real t: 0

    Timer { interval: 40; running: root.enabled; repeat: true; onTriggered: root.t += 0.04 }

    function show() { enabled = true }
    function hide() { enabled = false }
    function toggle() { enabled = !enabled }

    IpcHandler {
        target: "visualizer"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }

    Process {
        id: cava
        running: root.enabled
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/visualizer/cava.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var s = String(line || "").trim()
                if (s === "") return
                var parts = s.split(";"), out = [], sum = 0
                for (var i = 0; i < parts.length; i++) {
                    var v = parseInt(parts[i])
                    if (!isNaN(v)) { v = Math.max(0, Math.min(100, v)); out.push(v); sum += v }
                }
                if (out.length === 0) return
                root.bars = out
                root.energy = sum / out.length
                var pk = root.peaks
                if (!pk || pk.length !== out.length) pk = out.slice()
                else { pk = pk.slice(); for (var j = 0; j < out.length; j++) pk[j] = Math.max(out[j], pk[j] - 2.0) }
                root.peaks = pk
            }
        }
    }
    onEnabledChanged: if (!enabled) energy = 0

    // ── desktop element (top layer, thin strip, click-through) ────────────
    PanelWindow {
        visible: root.enabled
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 180
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-visualizer"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Item {
            id: field
            anchors.fill: parent
            readonly property bool active: root.energy > 1.2
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }

            readonly property real vizW: width * 0.94
            readonly property real slotW: vizW / root.barCount
            readonly property real maxBarH: height * (root.family === "ps1" ? 0.5 : 0.72)

            // grounding shadow
            Rectangle {
                z: -2
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, root.family === "ps1" ? 0.14 : 0.28) }
                }
            }

            // ── soft bloom behind the spectrum (NOT for PlayStation — the bars there
            //     carry their own gloss; a blurred backlight just gunks the screen) ──
            MultiEffect {
                source: spectrum
                anchors.fill: spectrum
                z: -1
                visible: root.family !== "ps1"
                blurEnabled: true
                blur: 1.0
                blurMax: 38
                brightness: root.family === "morrowind" ? 0.1 : 0.14
                saturation: root.family === "morrowind" ? 0.2 : 0.42
                opacity: root.family === "morrowind" ? 0.55 : 0.6
            }

            // ── the crisp spectrum ──
            Item {
                id: spectrum
                anchors.fill: parent

                Row {
                    visible: root.family === "default"   // ps1 → glyph-flow, morrowind → membrane
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: field.height * 0.06
                    spacing: field.slotW * 0.26

                    Repeater {
                        model: root.barCount
                        delegate: Item {
                            id: slot
                            required property int index
                            width: field.slotW * 0.74
                            height: field.maxBarH
                            readonly property real v: (root.bars[index] || 0) / 100
                            readonly property real pk: (root.peaks[index] || 0) / 100

                            Loader { anchors.fill: parent; sourceComponent: root.family === "ps1" ? ledCol : gradBar }

                            // ── Morrowind / default: iridescent capsule bar ──
                            Component {
                                id: gradBar
                                Item {
                                    id: gb
                                    readonly property bool tel: root.family === "morrowind"
                                    readonly property color cLow: tel ? root.telDeep : Qt.darker(root.cAccent, 1.7)
                                    readonly property color cMid: tel ? root.telEmer : root.cAccent
                                    readonly property color cTip: tel ? root.telGlow : Qt.lighter(root.cAccent, 1.6)
                                    // bioluminescent breathing — each stalk pulses out of phase → living field
                                    readonly property real breathe: 0.55 + 0.45 * Math.sin(root.t * 1.6 + slot.index * 0.5)

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * (gb.tel ? 0.8 : 1.0)   // slimmer organic stalk
                                        height: Math.max(3, slot.v * field.maxBarH)
                                        radius: width / 2
                                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(gb.cLow.r, gb.cLow.g, gb.cLow.b, gb.tel ? 0.85 : 0.15) }
                                            GradientStop { position: 0.5; color: gb.cMid }
                                            GradientStop { position: 1.0; color: gb.cTip }
                                        }
                                        // spore cap — breathing bioluminescent bulb (louder = larger + brighter)
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            anchors.topMargin: -width * 0.45
                                            width: parent.width * (gb.tel ? (1.35 + 0.5 * slot.v) : 1.15)
                                            height: width
                                            radius: height / 2
                                            color: gb.cTip
                                            opacity: gb.tel ? gb.breathe : (0.45 + 0.55 * slot.v)
                                        }
                                    }
                                    // floating peak fleck — amber spore
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.9
                                        height: width
                                        radius: height / 2
                                        y: gb.height - slot.pk * field.maxBarH - height / 2
                                        visible: slot.pk > 0.05
                                        color: gb.tel ? root.telSpore : Qt.lighter(root.cAccent, 2.0)
                                        Behavior on y { NumberAnimation { duration: 70 } }
                                    }
                                }
                            }

                            // ── PlayStation: glossy enamel cells + floating button-glyph peak ──
                            Component {
                                id: ledCol
                                Item {
                                    id: led
                                    readonly property int segs: 12
                                    readonly property real gap: Math.max(1, field.maxBarH * 0.02)
                                    readonly property real segH: (field.maxBarH - (segs - 1) * gap) / segs
                                    readonly property int lit: Math.round(slot.v * segs)
                                    readonly property int peakSeg: Math.round(slot.pk * segs)
                                    // the four PlayStation face-button colors + glyphs, banded across the spectrum
                                    readonly property int band: Math.floor(slot.index / (root.barCount / 4))
                                    readonly property color pc: band === 0 ? "#5C8AC6"   // ✕ blue
                                                              : band === 1 ? "#57B89A"   // △ green
                                                              : band === 2 ? "#C56FA9"   // □ pink
                                                              :              "#D9556A"   // ○ red
                                    readonly property string glyph: band === 0 ? "✕" : band === 1 ? "△" : band === 2 ? "□" : "○"

                                    Column {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.82
                                        spacing: led.gap
                                        Repeater {
                                            model: led.segs
                                            delegate: Item {
                                                id: seg
                                                required property int index
                                                readonly property int fromBottom: led.segs - 1 - index
                                                readonly property bool on: fromBottom < led.lit
                                                readonly property real f: fromBottom / led.segs
                                                width: parent.width
                                                height: led.segH
                                                // glossy enamel cell: top highlight → colour → darker base
                                                Rectangle {
                                                    id: cell
                                                    anchors.fill: parent
                                                    radius: Math.min(width, height) * 0.34
                                                    visible: seg.on
                                                    readonly property color base: Qt.rgba(led.pc.r, led.pc.g, led.pc.b, 0.55 + 0.4 * seg.f)
                                                    gradient: Gradient {
                                                        GradientStop { position: 0.0; color: Qt.lighter(cell.base, 1.75) }
                                                        GradientStop { position: 0.5; color: cell.base }
                                                        GradientStop { position: 1.0; color: Qt.darker(cell.base, 1.4) }
                                                    }
                                                    // specular glint
                                                    Rectangle {
                                                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: parent.width * 0.2 }
                                                        height: Math.max(1, parent.height * 0.18)
                                                        radius: height / 2
                                                        color: Qt.rgba(1, 1, 1, 0.30)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // floating button-glyph peak marker, in the band's colour
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: led.height - led.peakSeg * (led.segH + led.gap) - height * 0.9
                                        text: led.glyph
                                        color: led.pc
                                        font.family: root.uiFont
                                        font.pixelSize: Math.max(9, led.width * 0.62)
                                        visible: led.peakSeg > 1
                                        opacity: 0.5 + 0.45 * slot.v
                                        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Telvanni living membrane (Morrowind) ──
                // A single luminous organic ridge that ripples with the audio and
                // an idle undulation — no discrete bars. Rendered as a filled,
                // smoothed curve on a Canvas so the surface flows like living tissue.
                Canvas {
                    id: membrane
                    anchors.fill: parent
                    visible: root.family === "morrowind"
                    antialiasing: true
                    renderStrategy: Canvas.Cooperative
                    opacity: 0.72                              // softer, less obstructive
                    // Palette per Morrowind variant. Parchment (light theme) → warm
                    // aged-gold ink wash; dark theme → smoky volcanic ash.
                    readonly property var pal: root.parchment
                        ? { crest: "rgba(154,110,26,A)", body: "rgba(190,150,66,A)",
                            deep:  "rgba(150,116,48,A)", line: "rgba(120,84,20,0.75)" }
                        : { crest: "rgba(214,201,178,A)", body: "rgba(150,134,112,A)",
                            deep:  "rgba(58,50,42,A)",   line: "rgba(224,210,186,0.7)" }
                    function rgba(s, a) { return s.replace("A", a) }
                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        if (!root.enabled)
                            return
                        var n = root.barCount
                        var bb = root.bars
                        if (!bb || bb.length < 2)
                            return
                        // top-surface points: low resting baseline + audio lift + idle waves
                        var pts = []
                        for (var i = 0; i < n; i++) {
                            var x = w * (i / (n - 1))
                            var val = (bb[i] || 0) / 100
                            var wave = 0.024 * Math.sin(root.t * 1.10 + i * 0.55)
                                     + 0.014 * Math.sin(root.t * 0.70 + i * 0.23)
                            var top = h - (0.09 + val * 0.44 + wave) * h
                            pts.push([x, top])
                        }
                        // filled membrane body (smoothed via quadratic midpoints)
                        ctx.beginPath()
                        ctx.moveTo(0, h)
                        ctx.lineTo(pts[0][0], pts[0][1])
                        var minTop = h
                        for (var j = 1; j < n; j++) {
                            var xc = (pts[j - 1][0] + pts[j][0]) / 2
                            var yc = (pts[j - 1][1] + pts[j][1]) / 2
                            ctx.quadraticCurveTo(pts[j - 1][0], pts[j - 1][1], xc, yc)
                            if (pts[j][1] < minTop) minTop = pts[j][1]
                        }
                        ctx.lineTo(pts[n - 1][0], pts[n - 1][1])
                        ctx.lineTo(w, h)
                        ctx.closePath()
                        var g = ctx.createLinearGradient(0, minTop, 0, h)
                        g.addColorStop(0.00, membrane.rgba(membrane.pal.crest, 0.80))
                        g.addColorStop(0.30, membrane.rgba(membrane.pal.body, 0.42))
                        g.addColorStop(0.75, membrane.rgba(membrane.pal.deep, 0.28))
                        g.addColorStop(1.00, membrane.rgba(membrane.pal.deep, 0.04))
                        ctx.fillStyle = g
                        ctx.fill()
                        // luminous crest line riding the surface
                        ctx.beginPath()
                        ctx.moveTo(pts[0][0], pts[0][1])
                        for (var m = 1; m < n; m++) {
                            var xc2 = (pts[m - 1][0] + pts[m][0]) / 2
                            var yc2 = (pts[m - 1][1] + pts[m][1]) / 2
                            ctx.quadraticCurveTo(pts[m - 1][0], pts[m - 1][1], xc2, yc2)
                        }
                        ctx.lineTo(pts[n - 1][0], pts[n - 1][1])
                        ctx.lineWidth = 2.0
                        ctx.lineJoin = "round"
                        ctx.strokeStyle = membrane.pal.line
                        ctx.stroke()
                    }
                    onPalChanged: requestPaint()
                    Connections {
                        target: root
                        function onBarsChanged() { membrane.requestPaint() }
                    }
                }

                // ── PlayStation flowing glyph-current ──
                // The Morrowind membrane's fluidity, but the "water" is made of the four
                // face-button glyphs (✕ △ □ ○) drifting sideways and riding the audio
                // wave-surface like symbols carried on a current.
                Canvas {
                    id: psFlow
                    anchors.fill: parent
                    visible: root.family === "ps1"
                    antialiasing: true
                    renderStrategy: Canvas.Cooperative
                    readonly property int count: 104
                    readonly property var glyphs: ["✕", "△", "□", "○"]
                    // ✕ blue · △ green · □ pink · ○ red
                    readonly property var cols: [[92, 138, 198], [87, 184, 154], [197, 111, 169], [217, 85, 106]]
                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        if (!root.enabled)
                            return
                        var n = root.barCount
                        var bb = root.bars
                        if (!bb || bb.length < 2)
                            return
                        var t = root.t
                        var span = w + 120
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        for (var i = 0; i < psFlow.count; i++) {
                            var ty = i % 4
                            // horizontal current — varied speed per glyph, wraps around
                            var sp = 120 + (i % 7) * 20
                            var x = ((i / psFlow.count) * span + t * sp) % span - 60
                            // sample the audio at this x
                            var bi = Math.floor((x / w) * n)
                            if (bi < 0) bi = 0
                            else if (bi >= n) bi = n - 1
                            var val = (bb[bi] || 0) / 100
                            // fluid surface: resting baseline + audio lift + two idle waves
                            var wave = 0.028 * Math.sin(t * 1.10 + x * 0.010)
                                     + 0.018 * Math.sin(t * 0.70 + x * 0.006 + i)
                            var surf = h - (0.13 + val * 0.50 + wave) * h
                            // spread downward into a flowing band, denser near the surface
                            var r = ((i * 47) % 100) / 100
                            var y = surf + Math.pow(r, 1.6) * h * 0.30
                            // size swells a touch with loudness
                            var sz = (13 + (i % 4) * 3) * (0.8 + val * 0.7)
                            // translucent; fade at the horizontal edges and when quiet; gentle shimmer
                            var edge = Math.min(1, Math.min(x + 40, (w - x) + 40) / 120)
                            if (edge < 0) edge = 0
                            var a = (0.22 + 0.5 * val) * edge * (0.68 + 0.32 * Math.sin(t * 1.3 + i))
                            var c = psFlow.cols[ty]
                            ctx.font = sz.toFixed(1) + "px '" + root.uiFont + "'"
                            ctx.fillStyle = "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")"
                            ctx.fillText(psFlow.glyphs[ty], x, y)
                        }
                    }
                    Connections {
                        target: root
                        function onBarsChanged() { psFlow.requestPaint() }
                    }
                }

                // ── drifting Telvanni spores (Morrowind) — inside the bloom source ──
                Item {
                    anchors.fill: parent
                    visible: root.family === "morrowind"
                    Repeater {
                        model: 28
                        delegate: Rectangle {
                            required property int index
                            readonly property real ph: (root.t * (0.05 + (index % 5) * 0.012) + index * 0.16) % 1.0
                            width: 3 + (index % 3)
                            height: width
                            radius: width / 2
                            x: (index * 71 + 25) % Math.max(1, parent.width - 24)
                            y: parent.height * (0.96 - ph * 0.9)
                            opacity: Math.sin(ph * Math.PI) * (0.18 + 0.22 * ((index % 3) / 2))
                            color: root.parchment
                                   ? (index % 4 === 0 ? "#B8923C" : "#D9B968")   // gold dust
                                   : (index % 4 === 0 ? "#C98A5A" : "#CBBBA2")   // ash / ember motes
                        }
                    }
                }
            }

        }
    }
}
