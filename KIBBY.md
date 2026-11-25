# Caelestia shell, Kibby fork

This is a fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) by the caelestia-dots contributors. [Kibby](https://github.com/JagritGumber/kibby) installs it.

- **Base:** upstream tag `v2.5.0` (d999d487). It runs with the `caelestia-shell` 2.5.0 plugin from the AUR.
- **Branch `kibby`:** that base plus Jagrit Gumber's changes, one commit per change.
- **Licence:** GPL-3.0, the same as upstream (see `LICENSE`). Upstream's copyright and history are kept; `git log v2.5.0..kibby` shows every change made here.

## Changes on top of v2.5.0

- **Touchpad and microphone:** touchpad-lock and mic-mute feedback in the bar and as toasts.
- **App icons:** the workspace strip, special workspaces and the active window show each window's own app icon.
- **Tray menus:** they stay open while the pointer travels to them, and are named by tray item rather than position.
- **Lock keys:** Caps and Num Lock are read from the laptop keyboard when keyd sits in front of it.
- **System alerts:** memory and battery alerts, shown even over fullscreen windows.
- **Notifications:** app icons, tidier groups, and an alert sound for chosen apps. A notification with no usable icon of its own shows the distro logo the bar uses, never a broken image.
- **Profile picture:** a cropper for it in the dashboard.
- **Mixer, in the OSD:** hovering the volume pill for 400 ms, or right-clicking it, slides out a pill for each app playing, with its icon on top (click to mute), its volume (drag or scroll wheel), and a device chip above to switch the output. The microphone pill does the same for apps recording, and has a live level meter inside it. It closes with the OSD, when the pointer leaves, or after 4 s if the pointer never came, and never opens on a volume change. `qs -c caelestia ipc call osd mixer` (or `osd micMixer`) opens it.
- **Launcher:** theme icons for apps, and a wallpapers shortcut that opens the wallpaper carousel. Apps that a `~/.local/share/applications` file overrides no longer drop out of the list on every rescan of the app folders.
- **Recording:** region recording hands the pointer to slurp, and runs through Kibby's `caelestia-recorder`.
- **Keep Awake:** on AC power it also stops lid close from suspending. Game mode keeps the screen awake.
- **Notification dock:** the work Junco (his mail app) finds in his mail, in a Material 3 list-detail sheet in the bottom-left corner. A thin accent line in the bottom border shows while there is work; resting the pointer on the edge under it (50 ms) opens the sheet: source tabs, search, the list, and one item's detail (a decision, a CI run, a review, a comment, an invitation, a bill, a delivery) with its actions, Later and Mark read. It reads `${XDG_STATE_HOME}/courier/dock.json` and acts through `courier-notify`; it never writes the feed. shell.json `notifs`: `dock` (false turns it off), `dockLayout` (`"deck"` for the older one-card deck), `dockRevealDelay` (ms, default 50) and `dockScale` (size; 1 is 990 × 480 px). These keys aren't in the plugin's schema, so Caelestia lists any that are set among its config issues. `qs -c caelestia ipc call drawers toggle notifDock` opens it too.
- **Upstream fix:** `onOtherMonitor` always yields a bool.

Some of these expect helpers that Kibby installs:
- `caelestia-recorder`
- `kibby-mic-toggle`
- `kibby-touchpad-state`
- keyd

The notification dock needs Junco (`courier-notify` and the feed it writes); without it the dock stays hidden.
