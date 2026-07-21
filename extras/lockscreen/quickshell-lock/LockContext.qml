// Shared lock state: one password buffer + PAM conversation, referenced by
// every per-screen lock surface (official quickshell-examples pattern).
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string failureMessage: ""

    function submit() {
        if (unlockInProgress || currentText === "")
            return
        showFailure = false
        failureMessage = ""
        unlockInProgress = true
        pam.start()
    }

    function clear() {
        currentText = ""
        showFailure = false
    }

    PamContext {
        id: pam
        config: "login"   // standard system auth stack, same as tty login

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.currentText)
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root.showFailure = true
                root.failureMessage = result === PamResult.MaxTries
                    ? "too many attempts" : ""
                root.unlockInProgress = false
            }
            root.currentText = ""
        }

        onError: e => {
            root.showFailure = true
            root.failureMessage = "auth error: " + PamError.toString(e)
            root.unlockInProgress = false
            root.currentText = ""
        }
    }
}
