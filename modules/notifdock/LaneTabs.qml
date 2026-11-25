pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// All / Actions / Updates as one segmented pill, each with its count; the
// shown one filled.
StyledRect {
    id: root

    readonly property var lanes: [
        {
            key: "all",
            label: qsTr("All"),
            count: NotifDockState.laneCounts.all
        },
        {
            key: "actions",
            label: qsTr("Actions"),
            count: NotifDockState.laneCounts.actions
        },
        {
            key: "updates",
            label: qsTr("Updates"),
            count: NotifDockState.laneCounts.updates
        }
    ]

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 40
    radius: Tokens.rounding.full
    color: "transparent"
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.lanes

            StyledRect {
                id: lane

                required property var modelData

                readonly property bool active: NotifDockState.view === modelData.key

                implicitWidth: content.implicitWidth + Tokens.padding.large * 2 + 8
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: active ? Colours.palette.m3primary : "transparent"

                StateLayer {
                    color: lane.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    onClicked: NotifDockState.view = lane.modelData.key
                }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 6

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.label
                        font: Tokens.font.label.builders.large.weight(lane.active ? Font.DemiBold : Font.Medium).build()
                        color: lane.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.count
                        font: Tokens.font.label.large
                        color: lane.active ? Qt.alpha(Colours.palette.m3onPrimary, 0.7) : Colours.palette.m3outline
                    }
                }
            }
        }
    }
}
