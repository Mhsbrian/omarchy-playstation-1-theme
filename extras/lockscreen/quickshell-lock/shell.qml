// Themed session lockscreen (replaces hyprlock once wired into hypridle).
//
//   qs -c lock                 → locks the session immediately, quits on unlock
//   QS_LOCK_DEMO=1 qs -c lock  → same UI + real PAM auth in a normal window,
//                                 no session lock — safe to test
//
// Safety semantics (ext_session_lock_v1): if this process crashes while
// locked, the compositor keeps the screens locked (blanked) — the session is
// never exposed. locked=false is released before quitting on success.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property bool demoMode: Quickshell.env("QS_LOCK_DEMO") === "1"
    readonly property string omarchyCurrent: Quickshell.env("HOME") + "/.config/omarchy/current"
    property string themeName: ""
    property var palette: ({})

    FileView {
        path: root.omarchyCurrent + "/theme.name"
        onLoaded: root.themeName = text().trim().toLowerCase().replace(/\s+/g, "-")
    }

    FileView {
        path: root.omarchyCurrent + "/theme/colors.toml"
        onLoaded: {
            var out = {}
            var lines = text().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"/)
                if (m) out[m[1]] = m[2]
            }
            root.palette = out
        }
    }

    LockContext {
        id: lockContext
        onUnlocked: {
            lock.locked = false   // release the session lock BEFORE quitting
            Qt.quit()
        }
    }

    WlSessionLock {
        id: lock
        locked: !root.demoMode

        WlSessionLockSurface {
            LockContent {
                anchors.fill: parent
                context: lockContext
                themeName: root.themeName
                palette: root.palette
                backgroundPath: root.omarchyCurrent + "/background"
            }
        }
    }

    // demo mode: identical UI in a regular window; "unlock" simply quits
    Loader {
        active: root.demoMode
        sourceComponent: FloatingWindow {
            title: "Lockscreen demo (no session lock)"
            LockContent {
                anchors.fill: parent
                context: lockContext
                themeName: root.themeName
                palette: root.palette
                backgroundPath: root.omarchyCurrent + "/background"
            }
        }
    }
}
