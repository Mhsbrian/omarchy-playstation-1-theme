// Per-theme signature effect overlay: CRT scanlines for PlayStation, drifting
// gold ash-motes for Morrowind, nothing for other themes. Non-interactive.
import QtQuick
import Quickshell

Item {
    id: chrome
    property string themeName: ""
    readonly property string family:
        themeName.indexOf("playstation") === 0 ? "ps1"
        : (themeName.indexOf("morrowind") === 0 ? "morrowind" : "default")
    readonly property string fxDir: Quickshell.env("HOME") + "/.config/quickshell/theme-fx/"

    property real t: 0
    Timer {
        interval: 40; repeat: true
        running: chrome.visible && chrome.family !== "default"
        onTriggered: chrome.t += 0.04
    }

    // PlayStation — CRT scanlines + faint blue glow
    ShaderEffect {
        anchors.fill: parent
        visible: chrome.family === "ps1"
        fragmentShader: "file://" + chrome.fxDir + "scanlines.frag.qsb"
        property real time: chrome.t
        property color tint: "#2E8AE6"
    }

    // Morrowind — drifting gold ash motes + warm vignette
    ShaderEffect {
        anchors.fill: parent
        visible: chrome.family === "morrowind"
        fragmentShader: "file://" + chrome.fxDir + "ashmotes.frag.qsb"
        property real time: chrome.t
        property real aspect: width / Math.max(1, height)
        property color gold: "#D9B167"
    }
}
