pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// One day as a strip: your calendar on the top lane, the invitation on the
// lane under it, and where they overlap a band in the tertiary accent. A
// free slot the source suggests shows as a soft green band on the
// invitation's lane. Filled shapes only, no outlines.
// Hours from `from` to `to` (0-24), ticks every two hours.
Item {
    id: root

    property real from: 9
    property real to: 19
    // [{title, start, end}] (ISO times), your existing events.
    property var events: []
    // {title, start, end}: the invitation.
    property var slot: ({})
    // {start, end, label}: a free slot, optional.
    property var suggest: null

    readonly property real laneHeight: 30
    readonly property real span: to - from

    function hours(iso: string): real {
        const t = Kit.timeOf(iso);
        if (!t)
            return from;
        const d = new Date(t);
        return d.getHours() + d.getMinutes() / 60;
    }

    function xOf(iso: string): real {
        return Math.max(0, Math.min(width, (hours(iso) - from) / span * width));
    }

    function overlaps(a: var, b: var): bool {
        return Kit.timeOf(a.start) < Kit.timeOf(b.end) && Kit.timeOf(b.start) < Kit.timeOf(a.end);
    }

    readonly property var conflicts: events.filter(e => overlaps(e, slot))

    implicitHeight: laneHeight * 2 + NotifDockState.px(6) + NotifDockState.px(20)

    // Hour ticks.
    Repeater {
        model: Math.floor(root.span / 2) + 1

        Item {
            id: tick

            required property int index

            readonly property real hour: Math.ceil(root.from / 2) * 2 + index * 2

            x: (hour - root.from) / root.span * root.width
            width: 1
            height: root.height
            visible: hour <= root.to

            StyledRect {
                width: 1
                height: root.laneHeight * 2 + NotifDockState.px(6)
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: tick.hour < 10 ? `0${tick.hour}` : `${tick.hour}`
                font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                color: Colours.palette.m3outline
            }
        }
    }

    // The lanes' ground.
    StyledRect {
        y: 0
        width: root.width
        height: root.laneHeight
        radius: NotifDockState.px(Tokens.rounding.small)
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
    }

    StyledRect {
        y: root.laneHeight + NotifDockState.px(6)
        width: root.width
        height: root.laneHeight
        radius: NotifDockState.px(Tokens.rounding.small)
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
    }

    // Your events.
    Repeater {
        model: root.events

        StyledRect {
            id: event

            required property var modelData

            readonly property bool clash: root.overlaps(modelData, root.slot)

            x: root.xOf(modelData.start) + 1
            width: Math.max(4, root.xOf(modelData.end) - root.xOf(modelData.start) - NotifDockState.px(2))
            height: root.laneHeight
            radius: NotifDockState.px(Tokens.rounding.small)
            color: clash ? Qt.alpha(Colours.palette.m3tertiary, 0.3) : Colours.palette.m3surfaceContainerHighest
            clip: true

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: NotifDockState.px(6)
                anchors.rightMargin: NotifDockState.px(4)
                text: event.modelData.title ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.label.builders.medium)
                color: event.clash ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // A free slot to propose instead.
    StyledRect {
        visible: !!root.suggest
        x: root.xOf(root.suggest?.start ?? "") + 1
        y: root.laneHeight + NotifDockState.px(6)
        width: Math.max(4, root.xOf(root.suggest?.end ?? "") - root.xOf(root.suggest?.start ?? "") - NotifDockState.px(2))
        height: root.laneHeight
        radius: NotifDockState.px(Tokens.rounding.small)
        color: Qt.alpha(Colours.palette.m3success, 0.2)

        StyledText {
            anchors.centerIn: parent
            text: root.suggest?.label ?? "free"
            font: NotifDockState.dfont(Tokens.font.label.builders.medium)
            color: Colours.palette.m3success
        }
    }

    // The invitation. Its name goes inside when it fits, else just after it.
    StyledRect {
        id: invite

        x: root.xOf(root.slot.start ?? "") + 1
        y: root.laneHeight + NotifDockState.px(6)
        width: Math.max(4, root.xOf(root.slot.end ?? "") - root.xOf(root.slot.start ?? "") - NotifDockState.px(2))
        height: root.laneHeight
        radius: NotifDockState.px(Tokens.rounding.small)
        color: Colours.palette.m3primary
    }

    StyledText {
        readonly property bool inside: implicitWidth + 12 <= invite.width

        x: inside ? invite.x + NotifDockState.px(6) : invite.x + invite.width + NotifDockState.px(6)
        anchors.verticalCenter: invite.verticalCenter
        width: inside ? invite.width - NotifDockState.px(10) : Math.max(0, root.width - x - NotifDockState.px(2))
        text: root.slot.title ?? ""
        elide: Text.ElideRight
        font: NotifDockState.dfont(Tokens.font.label.builders.medium.weight(Font.DemiBold))
        color: inside ? Colours.palette.m3onPrimary : Colours.palette.m3primary
    }

    // Where they clash: a band across both lanes.
    Repeater {
        model: root.conflicts

        StyledRect {
            required property var modelData

            readonly property real a: Math.max(Kit.timeOf(modelData.start), Kit.timeOf(root.slot.start))
            readonly property real b: Math.min(Kit.timeOf(modelData.end), Kit.timeOf(root.slot.end))

            x: root.xOf(new Date(a).toISOString())
            width: Math.max(3, root.xOf(new Date(b).toISOString()) - x)
            y: NotifDockState.px(-3)
            height: root.laneHeight * 2 + NotifDockState.px(12)
            radius: NotifDockState.px(3)
            color: Qt.alpha(Colours.palette.m3tertiary, 0.45)
        }
    }
}
