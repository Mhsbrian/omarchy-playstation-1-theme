// Themed lock UI, instantiated once per screen (and once in demo mode).
// Style resolves from the live Omarchy theme: PS1 gets the memory-card look,
// the Morrowind themes get a parchment seal, anything else a neutral card.
import QtQuick

Rectangle {
    id: content

    required property var context
    required property string themeName
    required property var palette
    required property string backgroundPath

    implicitWidth: 1280
    implicitHeight: 800
    color: "#000000"
    focus: true

    function col(key, fallback) {
        var v = palette[key]
        return (v && /^#[0-9A-Fa-f]{6}$/.test(v)) ? v : fallback
    }

    readonly property bool isPs1: themeName === "playstation-1"
    readonly property bool isMorrowind: themeName.indexOf("morrowind") === 0
    readonly property bool lightPaper: themeName === "morrowind-parchment"

    readonly property color cardBg: col("background", "#101014")
    readonly property color fg: col("foreground", "#c9cdc4")
    readonly property color accent: col("accent", "#8899aa")
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color errCol: col("color1", "#e23b2e")

    readonly property string promptText:
        isPs1 ? "ENTER PASSCODE" :
        isMorrowind ? "Speak the words" : "Enter password"
    readonly property string failText:
        context.failureMessage !== "" ? context.failureMessage :
        isPs1 ? "ACCESS DENIED" :
        isMorrowind ? "The words are wrong" : "Authentication failed"
    readonly property string busyText:
        isPs1 ? "CHECKING MEMORY CARD..." :
        isMorrowind ? "Consulting the scrolls..." : "Authenticating..."

    // ── wallpaper backdrop, dimmed ──
    Image {
        anchors.fill: parent
        source: content.backgroundPath !== "" ? "file://" + content.backgroundPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: content.lightPaper ? 0.35 : 0.55
    }

    // ── clock ──
    property string clockText: ""
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: content.clockText = Qt.formatDateTime(new Date(), "HH:mm")
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: 48
        text: content.clockText
        color: "#FFFFFF"
        opacity: 0.92
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 96
        font.bold: true
    }

    // ── center card ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 60
        width: 420
        height: column.implicitHeight + 56
        radius: content.isPs1 ? 4 : 14
        color: Qt.rgba(content.cardBg.r, content.cardBg.g, content.cardBg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(content.accent.r, content.accent.g, content.accent.b, 0.65)

        // failure shake
        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -12; duration: 45 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 45 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -6; duration: 40 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
        }
        Connections {
            target: content.context
            function onShowFailureChanged() {
                if (content.context.showFailure) shake.restart()
            }
        }

        Column {
            id: column
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 18

            // PS1: the four button glyphs; Morrowind: a small seal line
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                visible: content.isPs1
                Text { text: "▲"; color: content.col("color2", "#1FBF61"); font.pixelSize: 20 }
                Text { text: "●"; color: content.col("color1", "#E23B2E"); font.pixelSize: 20 }
                Text { text: "✕"; color: content.col("color4", "#2E8AE6"); font.pixelSize: 20 }
                Text { text: "■"; color: content.col("color3", "#F5C400"); font.pixelSize: 20 }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: content.isMorrowind
                width: 120; height: 2
                color: content.accent
                opacity: 0.8
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: content.context.unlockInProgress ? content.busyText : content.promptText
                color: content.dim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.letterSpacing: content.isPs1 ? 3 : 1
            }

            // password dots + hidden input
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 44
                radius: content.isPs1 ? 2 : 10
                color: Qt.rgba(0, 0, 0, content.lightPaper ? 0.10 : 0.30)
                border.width: 1
                border.color: input.activeFocus
                    ? content.accent
                    : Qt.rgba(content.fg.r, content.fg.g, content.fg.b, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: {
                        var n = content.context.currentText.length
                        var s = ""
                        for (var i = 0; i < n; i++) s += content.isPs1 ? "■ " : "● "
                        return s.trim()
                    }
                    color: content.accent
                    font.pixelSize: content.isPs1 ? 12 : 14
                    font.letterSpacing: 2
                }

                TextInput {
                    id: input
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    enabled: !content.context.unlockInProgress
                    onTextChanged: content.context.currentText = text
                    onAccepted: content.context.submit()
                    Keys.onEscapePressed: { text = ""; content.context.clear() }

                    Connections {
                        target: content.context
                        function onCurrentTextChanged() {
                            if (content.context.currentText === "" && input.text !== "")
                                input.text = ""
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: content.context.showFailure
                text: content.failText
                color: content.errCol
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.bold: content.isPs1
                font.letterSpacing: content.isPs1 ? 2 : 0
            }
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
