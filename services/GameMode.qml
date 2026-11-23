pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled

    function syncIdleInhibitor(): void {
        if (enabled) {
            if (!props.idleInhibitorManaged) {
                props.idleInhibitorWasEnabled = IdleInhibitor.enabled;
                props.idleInhibitorManaged = true;
            }
            IdleInhibitor.enabled = true;
        } else if (props.idleInhibitorManaged) {
            const restoreEnabled = props.idleInhibitorWasEnabled;
            props.idleInhibitorManaged = false;
            props.idleInhibitorWasEnabled = false;
            IdleInhibitor.enabled = restoreEnabled;
        }
    }

    function setDynamicConfs(): void {
        Hypr.extras.applyOptions({
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0,
            "general:allow_tearing": 1
        });
    }

    onEnabledChanged: {
        syncIdleInhibitor();

        if (enabled) {
            setDynamicConfs();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
        } else {
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Hyprland settings restored"), "gamepad");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: Hypr.options["animations:enabled"] === 0 // qmllint disable missing-property
        property bool idleInhibitorManaged
        property bool idleInhibitorWasEnabled

        reloadableId: "gameMode"
    }

    Component.onCompleted: root.syncIdleInhibitor()

    Connections {
        function onEnabledChanged(): void {
            if (root.enabled && !IdleInhibitor.enabled)
                Qt.callLater(() => root.syncIdleInhibitor());
        }

        target: IdleInhibitor
    }

    Connections {
        function onConfigReloaded(): void {
            if (props.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
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

        target: "gameMode"
    }
}
