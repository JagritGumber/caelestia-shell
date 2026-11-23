pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components.effects
import qs.utils

// A notification's app icon. `icon` comes from Notifs.resolveAppIcon: a theme
// icon name or a file URL that exists, or "" for none. With none, or when a
// file fails to load, it shows the distro logo the bar uses (SysInfo.osLogo,
// from os-release's LOGO), tinted with `colour`. Never a broken image.
Item {
    id: root

    property string icon
    required property color colour
    property real implicitSize

    readonly property bool showsIcon: icon.length > 0 && appIcon.status !== Image.Error

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    IconImage {
        id: appIcon

        anchors.fill: parent
        asynchronous: true
        source: !root.icon ? "" : root.icon.startsWith("file:") ? root.icon : Quickshell.iconPath(root.icon)
        visible: root.showsIcon
    }

    Loader {
        anchors.fill: parent
        active: !root.showsIcon

        sourceComponent: ColouredIcon {
            source: SysInfo.osLogo
            colour: root.colour
        }
    }
}
