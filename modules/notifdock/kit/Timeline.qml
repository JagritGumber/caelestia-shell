pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Something moving through steps (a deploy, a delivery, a transfer): the
// steps as dots on a line, done ones filled, the current one ringed, a
// failed one red, with each step's time under it.
// Sections: steps {items: [{label, state: done|current|pending|failed,
// at}]}.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})

    readonly property var steps: Kit.section(item, "steps")?.items ?? []
    property Component actionsContent: actionsRow

    spacing: NotifDockState.px(Tokens.spacing.medium)

    CardHead {
        Layout.fillWidth: true
        item: root.item
        unit: root.unit
        kind: root.item?.kind ?? ""
        status: root.head.text ?? ""
        statusIcon: root.head.icon ?? "schedule"
        tone: root.head.tone ?? ""
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: NotifDockState.px(2)
        text: root.item?.title ?? ""
        elide: Text.ElideRight
        font: NotifDockState.dfont(Tokens.font.title.builders.large.weight(Font.DemiBold))
    }

    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.item?.subtitle ?? ""
        elide: Text.ElideRight
        font: NotifDockState.dfont(Tokens.font.body.builders.small)
        color: Colours.palette.m3onSurfaceVariant
    }

    Item {
        id: track

        Layout.fillWidth: true
        Layout.topMargin: NotifDockState.px(Tokens.spacing.large)
        implicitHeight: NotifDockState.px(78)

        readonly property real stepW: width / Math.max(1, root.steps.length)

        // The line behind the dots: done part in the success colour.
        StyledRect {
            x: track.stepW / 2
            y: NotifDockState.px(13)
            width: track.width - track.stepW
            height: NotifDockState.px(3)
            color: Colours.palette.m3outlineVariant
        }

        StyledRect {
            x: track.stepW / 2
            y: NotifDockState.px(13)
            width: track.stepW * Math.max(0, root.steps.filter(s => s.state === "done").length - (root.steps.every(s => s.state === "done") ? 1 : 0))
            height: NotifDockState.px(3)
            color: Colours.palette.m3success
        }

        Repeater {
            model: root.steps

            Item {
                id: step

                required property var modelData
                required property int index

                readonly property color ink: modelData.state === "done" ? Colours.palette.m3success : modelData.state === "failed" ? Colours.palette.m3error : modelData.state === "current" ? Colours.palette.m3primary : Colours.palette.m3outline

                x: index * track.stepW
                width: track.stepW
                height: track.height

                StyledRect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: NotifDockState.px(28)
                    implicitHeight: NotifDockState.px(28)
                    radius: NotifDockState.px(14)
                    color: step.modelData.state === "done" || step.modelData.state === "failed" ? step.ink : Colours.palette.m3surfaceContainer
                    border.width: 2
                    border.color: step.ink

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: step.modelData.state === "done" || step.modelData.state === "failed"
                        text: step.modelData.state === "failed" ? "close" : "check"
                        color: Colours.palette.m3surface
                        fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(13).weight(Font.Bold))
                    }

                    StyledRect {
                        anchors.centerIn: parent
                        visible: step.modelData.state === "current"
                        implicitWidth: NotifDockState.px(8)
                        implicitHeight: NotifDockState.px(8)
                        radius: NotifDockState.px(4)
                        color: step.ink
                    }
                }

                StyledText {
                    id: label

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: NotifDockState.px(36)
                    width: parent.width - NotifDockState.px(4)
                    horizontalAlignment: Text.AlignHCenter
                    text: step.modelData.label ?? ""
                    elide: Text.ElideRight
                    font: NotifDockState.dfont(Tokens.font.label.builders.large.weight(step.modelData.state === "current" ? Font.DemiBold : Font.Normal))
                    color: step.modelData.state === "pending" ? Colours.palette.m3outline : Colours.palette.m3onSurface
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: label.bottom
                    text: step.modelData.at ? Kit.stamp(step.modelData.at, NotifDockState.now) : ""
                    font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                    color: Colours.palette.m3outline
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    // The action row: here in the deck; in the sheet, pinned under the
    // scrolling detail (ItemCard loads actionsContent there).
    Loader {
        Layout.fillWidth: true
        active: !NotifDockState.compact
        visible: active
        sourceComponent: actionsRow
    }

    Component {
        id: actionsRow

        ColumnLayout {
            spacing: root.spacing

            RowLayout {
                Layout.fillWidth: true

                ActionGroup {
                    Layout.fillWidth: true
                    visible: (root.item?.actions ?? []).length > 0
                    item: root.item
                    unit: root.unit
                    actions: root.item?.actions ?? []
                }

                Item {
                    Layout.fillWidth: true
                }

                Link {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    item: root.item
                    text: root.item?.original?.label ?? ""
                    url: root.item?.original?.url ?? ""
                    icon: "open_in_new"
                }
            }
        }
    }
}
