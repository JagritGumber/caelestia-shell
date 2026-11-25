import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Where an item came from, as a small rounded tile: the app's theme icon
// (github, google, google-agenda...) or a local logo file (file://, as
// Junco sends for services), else a Material symbol. Nothing is fetched.
StyledRect {
    id: root

    property string icon
    property string symbol: "inbox"
    property real size: 28

    readonly property string path: !icon ? "" : icon.startsWith("file:") ? icon : icon.startsWith("/") ? `file://${icon}` : Quickshell.iconPath(icon, true)

    implicitWidth: size
    implicitHeight: size
    radius: NotifDockState.px(Tokens.rounding.small)
    color: Colours.palette.m3surfaceContainerHighest

    IconImage {
        anchors.centerIn: parent
        implicitSize: Math.round(root.size * 0.64)
        source: root.path
        visible: root.path !== ""
        asynchronous: true
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: root.path === ""
        text: root.symbol
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(Math.round(root.size * 0.42)))
    }
}
