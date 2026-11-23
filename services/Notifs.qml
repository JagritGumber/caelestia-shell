pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    property alias dnd: props.dnd

    property bool loaded
    property bool bulkClearing
    property var bulkCleanupQueue: []

    function hasFullscreen(): bool {
        for (const monitor of Hypr.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1))
                return true;
        }
        return false;
    }

    function shouldShowPopup(): bool {
        if (props.dnd || ShellState.anySidebarOpen())
            return false;
        if (GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off && hasFullscreen())
            return false;
        return true;
    }

    function playAttentionSound(notif: Notification): void {
        if (props.dnd)
            return;

        if (notif.appName === "Orca" && notif.summary.startsWith("Bell in ")) {
            attentionSound.running = true;
            return;
        }

        const app = (notif.appName || "").toLowerCase();
        const icon = (notif.appIcon || "").toLowerCase();
        if (app === "grok bot" || app === "grok-bot" || icon === "grok-bot")
            grokSound.running = true;
    }

    function resolveAppIcon(appName: string, suppliedIcon: string): string {
        const iconOverrides = {
            "slack": "file:///usr/share/pixmaps/slack.png",
            "grok-bot": `file://${Paths.home}/.local/share/icons/hicolor/512x512/apps/grok-bot.png`,
            "orca-ide": `file://${Paths.home}/.local/share/icons/hicolor/512x512/apps/orca-ide.png`,
            "fish": `file://${Paths.home}/.local/share/icons/Colloid-Pink-Catppuccin-Light/apps/scalable/fish.svg`
        };
        if (suppliedIcon)
            return iconOverrides[suppliedIcon] ?? suppliedIcon;

        const needle = appName.trim().toLowerCase();
        if (!needle)
            return "";

        const entry = DesktopEntries.applications.values.find(app => {
            const id = String(app.id ?? "").toLowerCase().replace(/\.desktop$/, "");
            const name = String(app.name ?? "").trim().toLowerCase();
            const startupClass = String(app.startupClass ?? "").trim().toLowerCase();
            return needle === id || needle === name || needle === startupClass;
        });
        if (entry?.icon)
            return iconOverrides[entry.icon] ?? entry.icon;

        const themedIcon = needle.replace(/\s+/g, "-");
        if (iconOverrides[themedIcon])
            return iconOverrides[themedIcon];
        return Quickshell.iconPath(themedIcon, "") ? themedIcon : "";
    }

    onDndChanged: {
        if (!GlobalConfig.utilities.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(Tr.tr("Do not disturb enabled"), Tr.tr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(Tr.tr("Do not disturb disabled"), Tr.tr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    Timer {
        id: bulkCleanupTimer

        interval: 16
        repeat: true
        onTriggered: {
            const batch = root.bulkCleanupQueue.splice(0, 4);
            for (const notif of batch)
                notif.finishClose();

            if (root.bulkCleanupQueue.length === 0) {
                stop();
                root.bulkClearing = false;
            }
        }
    }

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    Process {
        id: attentionSound

        command: ["/usr/bin/canberra-gtk-play", "--id=bell", "--volume=3.0", "--description=Orca attention requested"]
    }

    Process {
        id: grokSound

        command: ["/usr/bin/canberra-gtk-play", "--id=message", "--volume=-18.0", "--description=Grok Bot notification"]
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.playAttentionSound(notif);

            const comp = notifComp.createObject(root, {
                popup: root.shouldShowPopup(),
                notification: notif
            });
            root.list = [comp, ...root.list];
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            const data = JSON.parse(text());
            for (const notif of data) {
                const properties = Object.assign({}, notif);

                // Backwards compatibility for old notifications
                if (properties.notificationId === undefined && properties.id !== undefined)
                    properties.notificationId = properties.id;

                delete properties.id;
                root.list.push(notifComp.createObject(root, properties));
            }
            root.list.sort((a, b) => b.time - a.time);
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    function clearMatching(predicate): void {
        const targets = root.notClosed.filter(predicate);
        if (targets.length === 0)
            return;

        root.bulkClearing = true;
        const targetSet = new Set(targets);
        root.list = root.list.filter(notif => !targetSet.has(notif));

        // Detach the model first so the UI recomputes once. Marking each
        // notification closed while it is still in the model makes every
        // counter, group and delegate react once per notification.
        for (const notif of targets)
            notif.prepareBulkClose();

        root.bulkCleanupQueue = [...root.bulkCleanupQueue, ...targets];
        if (!bulkCleanupTimer.running)
            bulkCleanupTimer.start();
    }

    function clear(): void {
        clearMatching(() => true);
    }

    function clearApp(appName: string): void {
        clearMatching(notif => notif.appName === appName);
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: root.clear()
    }

    IpcHandler {
        function clear(): void {
            root.clear();
        }

        function clearApp(appName: string): void {
            root.clearApp(appName);
        }

        function isDndEnabled(): bool {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
