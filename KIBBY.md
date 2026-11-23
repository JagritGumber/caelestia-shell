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
- **Launcher:** theme icons for apps, and a wallpapers shortcut that opens the wallpaper carousel.
- **Recording:** region recording hands the pointer to slurp, and runs through Kibby's `caelestia-recorder`.
- **Keep Awake:** on AC power it also stops lid close from suspending. Game mode keeps the screen awake.
- **Upstream fix:** `onOtherMonitor` always yields a bool.

Some of these expect helpers that Kibby installs:
- `caelestia-recorder`
- `kibby-mic-toggle`
- `kibby-touchpad-state`
- keyd
