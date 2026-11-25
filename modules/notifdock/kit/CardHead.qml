import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "kit.js" as Kit

// The one line every card starts with: where it came from (icon, source,
// kind), then a coloured status with its symbol ("1 day overdue", "Needs
// an answer"), and "Details" when the card keeps more. A new item (under
// freshMinutes) has a small dot on its source icon, the same on every kind.
// In the deck, Later and Mark read do what × did; `closable` brings it
// back where a card stands alone.
Item {
    id: root

    required property var item
    property var unit
    property string kind
    property string status
    property string statusIcon: "schedule"
    property string tone
    // A "Details" toggle, for a component that keeps more behind it.
    property bool hasDetails
    property bool detailsOpen
    property bool closable

    signal toggleDetails

    readonly property color ink: Kit.tone(Colours.palette, tone)

    implicitHeight: NotifDockState.px(28)
    // The sheet's detail pane draws its own header.
    visible: NotifDockState.layoutMode !== "sheet"

    SourceBadge {
        id: badge

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        icon: root.item?.icon ?? ""
        symbol: root.item?.symbol ?? "inbox"
    }

    // New: a dot on the source icon's corner.
    StyledRect {
        x: badge.x + badge.width - NotifDockState.px(5)
        y: badge.y - NotifDockState.px(3)
        implicitWidth: NotifDockState.px(8)
        implicitHeight: NotifDockState.px(8)
        radius: NotifDockState.px(4)
        visible: NotifDockState.isFresh(root.item ?? {})
        color: Colours.palette.m3primary
    }

    StyledText {
        id: sourceName

        anchors.left: badge.right
        anchors.leftMargin: NotifDockState.px(Tokens.spacing.small)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, statusRow.x - x - NotifDockState.px(Tokens.spacing.small))
        text: root.item?.source ?? ""
        elide: Text.ElideRight
        font: NotifDockState.dfont(Tokens.font.label.builders.large.weight(Font.DemiBold))
        color: Colours.palette.m3onSurface
    }

    StyledText {
        anchors.left: sourceName.right
        anchors.right: statusRow.left
        anchors.leftMargin: NotifDockState.px(6)
        anchors.rightMargin: NotifDockState.px(Tokens.spacing.small)
        anchors.verticalCenter: parent.verticalCenter
        text: root.kind
        visible: implicitWidth <= width + 1
        font: NotifDockState.dfont(Tokens.font.label.builders.large)
        color: Colours.palette.m3onSurfaceVariant
    }

    Row {
        id: statusRow

        anchors.right: details.visible ? details.left : close.visible ? close.left : parent.right
        anchors.rightMargin: NotifDockState.px(Tokens.spacing.extraSmall)
        anchors.verticalCenter: parent.verticalCenter
        spacing: NotifDockState.px(4)
        visible: root.status !== ""

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusIcon
            fill: 1
            color: root.ink
            fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(11))
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.status
            font: NotifDockState.dfont(Tokens.font.label.builders.large)
            color: root.ink
        }
    }

    TextButton {
        id: details

        anchors.right: close.visible ? close.left : parent.right
        anchors.rightMargin: close.visible ? 2 : -NotifDockState.px(Tokens.padding.small)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasDetails
        type: TextButton.Text
        text: root.detailsOpen ? "Less" : "Details"
        font: NotifDockState.dfont(Tokens.font.label.builders.large)
        horizontalPadding: NotifDockState.px(Tokens.padding.small + 2)
        verticalPadding: NotifDockState.px(4)
        onClicked: root.toggleDetails()
        Component.onCompleted: NotifDockState.registerButton(`${root.item?.id}|details`, details)
        Component.onDestruction: NotifDockState.forget(details)
    }

    IconButton {
        id: close

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.closable
        type: IconButton.Text
        icon: "close"
        font: NotifDockState.dfont(Tokens.font.icon.builders.small)
        onClicked: NotifDockState.dismissUnit(root.unit)
    }
}
