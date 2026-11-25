import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// A small pill: an optional symbol and a short text, tinted by its tone
// (success, error, primary, tertiary, or none for a quiet grey).
StyledRect {
    id: root

    property string text
    property string icon
    property string tone
    property bool mono
    property bool strong
    property font font: mono ? NotifDockState.dfont(Tokens.font.mono.builders.small) : NotifDockState.dfont(Tokens.font.label.builders.large)

    readonly property color ink: tone ? Kit.tone(Colours.palette, tone) : Colours.palette.m3onSurfaceVariant

    implicitWidth: row.implicitWidth + Tokens.padding.small * 2 + NotifDockState.px(2)
    implicitHeight: NotifDockState.px(24)
    radius: NotifDockState.px(Tokens.rounding.full)
    color: strong ? ink : tone ? Qt.alpha(ink, 0.14) : Colours.palette.m3surfaceContainerHighest

    Row {
        id: row

        anchors.centerIn: parent
        spacing: NotifDockState.px(4)

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            fill: 1
            color: root.strong ? Colours.palette.m3surface : root.ink
            fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(10))
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font: root.font
            color: root.strong ? Colours.palette.m3surface : root.tone ? root.ink : Colours.palette.m3onSurface
        }
    }
}
