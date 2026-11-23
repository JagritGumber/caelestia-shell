pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince
    readonly property bool inhibitLidClose: props.enabled && !UPower.onBattery

    onEnabledChanged: {
        if (enabled)
            props.enabledSince = new Date();
    }

    PersistentProperties {
        id: props

        property bool enabled
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    IdleInhibitor {
        enabled: props.enabled
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    Process {
        id: lidSwitchInhibitor

        running: root.inhibitLidClose
        command: ["/usr/bin/systemd-inhibit", "--what=handle-lid-switch", "--who=Caelestia", "--why=Keep Awake is enabled while connected to AC power", "--mode=block", "/usr/bin/sleep", "infinity"]
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        function isLidCloseInhibited(): bool {
            return lidSwitchInhibitor.running;
        }

        target: "idleInhibitor"
    }
}
