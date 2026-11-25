import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// One key fact as a tile: its symbol in a tinted circle, a small label,
// the value big, and a detail under it (DecisionPanel's facts).
StyledRect {
    id: root

    property string icon
    property string label
    property string value
    property string detail
    property string tone

    readonly property color ink: tone ? Kit.tone(Colours.palette, tone) : Colours.palette.m3primary

    implicitHeight: content.implicitHeight + Tokens.padding.small * 2 + NotifDockState.px(4)
    radius: NotifDockState.px(Tokens.rounding.medium)
    color: Colours.palette.m3surfaceContainerHigh

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: NotifDockState.px(Tokens.padding.small + 2)
        anchors.rightMargin: NotifDockState.px(Tokens.padding.small)
        spacing: NotifDockState.px(Tokens.spacing.small + 2)

        StyledRect {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: NotifDockState.px(2)
            implicitWidth: NotifDockState.px(32)
            implicitHeight: NotifDockState.px(32)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Qt.alpha(root.ink, 0.14)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                fill: 1
                color: root.ink
                fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(13))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                wrapMode: NotifDockState.compact ? Text.Wrap : Text.NoWrap
                font: NotifDockState.dfont(Tokens.font.label.builders.small.letterSpacing(0.8))
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: root.value
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                wrapMode: NotifDockState.compact ? Text.Wrap : Text.NoWrap
                font: NotifDockState.dfont(Tokens.font.title.builders.small.weight(Font.DemiBold))
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.detail
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                wrapMode: NotifDockState.compact ? Text.Wrap : Text.NoWrap
                font: NotifDockState.dfont(Tokens.font.label.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
