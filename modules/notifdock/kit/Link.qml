import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A quiet way back to the source: "Original email · Google ↗". Opens only
// an http(s) link, through the dock (xdg-open), like a url action. Given
// less than its natural width (Layout.fillWidth with maximumWidth at its
// implicitWidth, beside buttons), its label elides instead of being cut.
Item {
    id: root

    required property var item
    property string text
    property string url
    property string icon: "mail"

    implicitWidth: lead.implicitWidth + label.implicitWidth + tail.implicitWidth + row.spacing * 2 + NotifDockState.px(Tokens.padding.small) * 2
    implicitHeight: row.implicitHeight + NotifDockState.px(Tokens.padding.extraSmall) * 2
    visible: url !== ""

    StateLayer {
        radius: NotifDockState.px(Tokens.rounding.small)
        color: Colours.palette.m3onSurface
        onClicked: NotifDockState.act(root.item, {
            id: "original",
            label: root.text,
            type: "url",
            url: root.url
        }, "", false)
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: NotifDockState.px(4)

        MaterialIcon {
            id: lead

            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Colours.palette.m3outline
            fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(10))
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, root.width - lead.implicitWidth - tail.implicitWidth - row.spacing * 2 - NotifDockState.px(Tokens.padding.small) * 2))
            elide: Text.ElideRight
            text: root.text
            font: NotifDockState.dfont(Tokens.font.label.builders.medium)
            color: Colours.palette.m3outline
        }

        MaterialIcon {
            id: tail

            anchors.verticalCenter: parent.verticalCenter
            text: "arrow_outward"
            color: Colours.palette.m3outline
            fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(9))
        }
    }
}
