pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.misc

Scope {
    property alias lock: lock

    WlSessionLock {
        id: lock

        signal unlock

        function screenNames(): var {
            const screens = lock.screens;
            if (!screens)
                return [];

            const names = [];
            for (let i = 0; i < screens.length; i++) {
                const n = screens[i]?.name ?? "";
                if (n.length > 0)
                    names.push(n);
            }
            return names;
        }

        function allMonitorsExcluded(): bool {
            const excluded = Config.lock.excludedScreens ?? [];
            const names = screenNames();

            if (names.length === 0)
                return false;

            for (let i = 0; i < names.length; i++) {
                if (!excluded.includes(names[i]))
                    return false;
            }
            return true;
        }

        function safeLock(): void {
            if (allMonitorsExcluded()) {
                Toaster.toast(
                    qsTr("Lockscreen is disabled on all monitors; refusing to lock to prevent lockout."),
                    "settingsalert",
                    Toast.Error
                );
                return;
            }

            lock.locked = true;
        }

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam
        lock: lock
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: lock.safeLock()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lock.safeLock();
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }
}
